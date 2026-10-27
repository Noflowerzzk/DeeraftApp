"""Authenticated launcher activity adapter; independent from Minecraft chat."""
import asyncio
from pathlib import Path
from uuid import UUID
from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from app.config.database import get_db
from app.models.user import User
from app.services.user_service import UserService
from app.services.activity_store import ActivityStore
from app.utils.auth import get_current_user
from app.utils.jwt import verify_token

router = APIRouter(tags=['启动器动态'])
store = ActivityStore(Path(__file__).resolve().parents[2] / 'data' / 'launcher_activity.sqlite3')

class Started(BaseModel):
    event_id: UUID
    instance: str = Field(min_length=1,max_length=120)
    version: str = Field(default='',max_length=128)

def public(row):
    return {key:row[key] for key in ('id','event_id','player','instance','version','time')}

@router.post('/api/v1/mobile/activity')
async def record_started(event: Started, user: User = Depends(get_current_user)):
    row = await asyncio.to_thread(store.record,user.id,user.username,str(event.event_id),event.instance,event.version)
    return public(row)

@router.get('/api/v1/mobile/activity')
async def recent_activity(after: int = Query(0,ge=0),limit: int = Query(50,ge=1,le=200), user: User = Depends(get_current_user)):
    return await asyncio.to_thread(store.history,after,limit)

@router.websocket('/api/v1/mobile/activity/ws')
async def activity_socket(websocket: WebSocket,token: str | None = None, db: Session = Depends(get_db)):
    if not token:
        header=websocket.headers.get('authorization','')
        if header.lower().startswith('bearer '):
            token=header[7:].strip()
    username = verify_token(token) if token else None
    if not username or not UserService.get_user_by_username(db,username):
        await websocket.accept()
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION,reason='登录已过期')
        return
    await websocket.accept()
    first = await asyncio.to_thread(store.history)
    await websocket.send_json({'type':'initial_activity',**first})
    cursor=first['cursor']
    try:
        while True:
            if not verify_token(token):
                await websocket.close(code=status.WS_1008_POLICY_VIOLATION,reason='登录已过期')
                return
            try:
                message = await asyncio.wait_for(websocket.receive_text(),timeout=2)
                if message=='ping':
                    await websocket.send_text('pong')
            except asyncio.TimeoutError:
                pass
            value = await asyncio.to_thread(store.history,cursor)
            if value['items']:
                await websocket.send_json({'type':'activity',**value})
                cursor=value['cursor']
    except WebSocketDisconnect:
        return
