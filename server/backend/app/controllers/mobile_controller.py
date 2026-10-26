"""JWT mobile adapters. Existing web routes and permission checks are unchanged."""
import asyncio
import os
import json
import urllib.request
from datetime import datetime, timezone
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, Query, WebSocket, status
from sqlalchemy.orm import Session
from app.config.database import get_db
from app.controllers import log_controller as logs
from app.models.user import User
from app.services.user_service import UserService
from app.utils.auth import get_current_user
from app.utils.jwt import verify_token
from app.services.mobile_environment import load_environment

load_environment()

router = APIRouter(tags=['移动端'])
_cache, _expires, _lock = None, 0.0, asyncio.Lock()


@router.get('/api/v1/community/status')
async def community_status(current_user: User = Depends(get_current_user)):
    import time
    global _cache, _expires
    if _cache is not None and time.monotonic() < _expires:
        return _cache
    async with _lock:
        if _cache is not None and time.monotonic() < _expires:
            return _cache
        origin = os.environ.get('DEERAFT_BOT_ORIGIN', 'http://127.0.0.1:8080')
        parsed = urlparse(origin)
        if parsed.hostname not in {'127.0.0.1', '::1'} or parsed.scheme != 'http' or parsed.username:
            raise RuntimeError('DEERAFT_BOT_ORIGIN must be a loopback HTTP origin')
        secret = os.environ.get('DEERAFT_INTERNAL_TOKEN', '')
        try:
            if not secret:
                raise RuntimeError('Missing internal token')
            def fetch():
                opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                request = urllib.request.Request(f'{origin.rstrip("/")}/internal/deeraft/status',
                                                  headers={'X-Deeraft-Internal': secret})
                with opener.open(request, timeout=12) as response:
                    return json.load(response)
            value = await asyncio.to_thread(fetch)
            if not isinstance(value, dict) or not isinstance(value.get('sources'), dict):
                raise ValueError('Invalid bot response')
        except Exception:
            value = {'mc': None, 'kook': None, 'fetched_at': datetime.now(timezone.utc).isoformat(),
                     'sources': {name: {'available': False, 'updated_at': None, 'error': '社区查询服务暂不可用'}
                                 for name in ('mc', 'kook')}}
        _cache, _expires = value, time.monotonic() + 15
        return value


@router.get('/api/v1/mobile/chat')
async def chat(num: int = Query(100, ge=1, le=300), current_user: User = Depends(get_current_user)):
    return await logs.get_chat_message(permission_code=logs.PERMISSION_CODE, num=num)


@router.get('/api/v1/mobile/daily-playtime')
async def daily_playtime(date: str | None = Query(None),
                         current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return await logs.get_daily_playtime(permission_code=logs.PERMISSION_CODE, date=date, db=db)


@router.websocket('/api/v1/mobile/chat/ws')
async def chat_socket(websocket: WebSocket, token: str | None = None, db: Session = Depends(get_db)):
    username = verify_token(token) if token else None
    if not username or not UserService.get_user_by_username(db, username):
        # Accept + close ensures mobile clients receive the policy close code.
        await websocket.accept()
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason='登录已过期')
        return
    # Reuse the same history and broadcaster as the website, no second log reader.
    await logs.websocket_chat_messages(websocket, permission_code=logs.PERMISSION_CODE)
