from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from app.config.database import get_db
from app.controllers.auth_controller import login as website_login
from app.models.user import User
from app.schemas.user import UserLogin
from app.services.user_service import UserService
from app.services.mobile_session_store import SessionStore
from app.utils.auth import get_current_user
from app.utils.jwt import create_access_token

router=APIRouter(prefix='/api/v1/mobile/auth',tags=['移动端认证'])
sessions=SessionStore()

class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=40,max_length=256)

def access_for(user):
    return create_access_token(data={'sub':user.username,'role':user.role},expires_delta=timedelta(days=1))

def session_for(user):
    return {'access_token':access_for(user),'refresh_token':sessions.issue(user.id),'token_type':'bearer'}

@router.post('/login')
async def login(payload:UserLogin,db:Session=Depends(get_db)):
    await website_login(payload,db=db)
    user=UserService.get_user_by_username(db,payload.username)
    return session_for(user)

@router.post('/session')
def upgrade_session(user:User=Depends(get_current_user)):
    """Upgrade a still-valid login from older App versions without reauthentication."""
    return session_for(user)

@router.post('/refresh')
def refresh(payload:RefreshRequest,db:Session=Depends(get_db)):
    user_id=sessions.resolve(payload.refresh_token)
    user=db.query(User).filter(User.id==user_id).first() if user_id is not None else None
    if user is None:
        sessions.revoke(payload.refresh_token)
        raise HTTPException(401,'登录已失效，请重新登录')
    return {'access_token':access_for(user),'token_type':'bearer'}

@router.post('/logout')
def logout(payload:RefreshRequest):
    sessions.revoke(payload.refresh_token)
    return {'ok':True}
