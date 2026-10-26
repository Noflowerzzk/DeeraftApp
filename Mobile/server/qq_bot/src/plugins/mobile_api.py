"""Internal bot API: local callers only, authenticated even on loopback."""
import hmac
import os

from fastapi import HTTPException, Request
from nonebot import get_driver
from src.services.community_query import StatusCache

cache = StatusCache()
app = get_driver().server_app


@app.get('/internal/deeraft/status', include_in_schema=False)
async def community_status(request: Request):
    expected = os.environ.get('DEERAFT_INTERNAL_TOKEN', '')
    supplied = request.headers.get('X-Deeraft-Internal', '')
    # Deliberately ignore forwarded headers: only actual local peer is trusted.
    peer = request.client.host if request.client else ''
    if peer not in {'127.0.0.1', '::1'} or not expected or not hmac.compare_digest(expected, supplied):
        raise HTTPException(status_code=403, detail='Forbidden')
    return await cache.get()
