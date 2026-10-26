"""Uses the existing registered Microsoft callback URI; no Azure change required."""
from datetime import timedelta
from urllib.parse import urlencode
from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, Field
from app.services import microsoft_auth_service
from app.services.mobile_oauth_store import OAuthStore
from app.services.user_service import UserService
from app.utils.jwt import create_access_token

router = APIRouter(prefix='/api/v1/mobile/auth/microsoft', tags=['移动端认证'])
store = OAuthStore()


class StartRequest(BaseModel):
    code_challenge: str = Field(pattern=r'^[A-Za-z0-9_-]{43}$')
    client_state: str = Field(pattern=r'^[A-Za-z0-9_-]{32,128}$')


class ExchangeRequest(BaseModel):
    code: str = Field(pattern=r'^[A-Za-z0-9_-]{32,128}$')
    code_verifier: str = Field(pattern=r'^[A-Za-z0-9._~-]{43,128}$')


@router.post('/start')
def start(payload: StartRequest):
    if not microsoft_auth_service.is_configured():
        raise HTTPException(503, '尚未配置 Microsoft 登录')
    state = store.start(payload.code_challenge, payload.client_state)
    return {'authorize_url': microsoft_auth_service.build_authorize_url(state)}


@router.post('/exchange')
def exchange(payload: ExchangeRequest):
    token = store.exchange(payload.code, payload.code_verifier)
    if not token:
        raise HTTPException(400, '交换码无效或已过期')
    return {'access_token': token, 'token_type': 'bearer'}


def complete_callback(*, code, state, error, db):
    client_state = store.begin_callback(state)
    if client_state is None:
        raise HTTPException(400, '登录事务无效或已过期，请重新发起')
    params = {'state': client_state}
    try:
        if error or not code:
            raise ValueError('Authorization cancelled')
        profile = microsoft_auth_service.authenticate_with_code(code)
        user = UserService.get_or_create_by_minecraft(db, profile.uuid, profile.name)
        token = create_access_token(data={'sub': user.username, 'role': user.role},
                                    expires_delta=timedelta(days=1))
        params['code'] = store.complete(state, token)
    except Exception:
        params['error'] = 'login_failed'
    return RedirectResponse('deeraft://oauth/callback?' + urlencode(params), status_code=302,
                            headers={'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer'})
