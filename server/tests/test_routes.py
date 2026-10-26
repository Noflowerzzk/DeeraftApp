"""Exercise real extension routes with isolated host-service dependencies."""
import asyncio
import importlib.util
import os
from pathlib import Path
import sys
from types import ModuleType, SimpleNamespace
from unittest.mock import patch, AsyncMock
import unittest

from fastapi import FastAPI, Header, HTTPException
from fastapi.testclient import TestClient

ROOT=Path(__file__).resolve().parents[1]
def module(name,**members):
    obj=ModuleType(name)
    obj.__dict__.update(members)
    return obj

class RouteTests(unittest.TestCase):
    def setUp(self):
        async def current_user(authorization: str|None=Header(None)):
            if authorization!='Bearer valid':raise HTTPException(401,'Invalid credentials')
            return SimpleNamespace(username='test-user')
        def db():yield None
        self.logs=module('app.controllers.log_controller',PERMISSION_CODE='server-side-only',
            get_chat_message=AsyncMock(return_value={'messages':[]}),
            get_daily_playtime=AsyncMock(return_value={'players':[]}),
            websocket_chat_messages=AsyncMock())
        stubs={
          'app':module('app'),'app.config':module('app.config'),'app.config.database':module('app.config.database',get_db=db),
          'app.controllers':module('app.controllers',log_controller=self.logs),'app.controllers.log_controller':self.logs,
          'app.models':module('app.models'),'app.models.user':module('app.models.user',User=SimpleNamespace),
          'app.services':module('app.services'),'app.services.user_service':module('app.services.user_service',
            UserService=SimpleNamespace(get_user_by_username=lambda db,name:SimpleNamespace() if name=='test-user' else None)),
          'app.utils':module('app.utils'),'app.utils.auth':module('app.utils.auth',get_current_user=current_user),
          'app.utils.jwt':module('app.utils.jwt',verify_token=lambda token:'test-user' if token=='valid' else None),
        }
        self.modules=patch.dict(sys.modules,stubs);self.modules.start();self.addCleanup(self.modules.stop)
        spec=importlib.util.spec_from_file_location('mobile_test',ROOT/'backend/app/controllers/mobile_controller.py')
        self.mobile=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.mobile)
        self.app=FastAPI();self.app.include_router(self.mobile.router)
        self.client=TestClient(self.app)
    def test_all_read_routes_require_account(self):
        for path in ['/api/v1/community/status','/api/v1/mobile/chat','/api/v1/mobile/daily-playtime']:
            self.assertEqual(self.client.get(path).status_code,401)
        self.logs.get_chat_message.assert_not_called()
    def test_adapters_keep_permission_code_server_side(self):
        response=self.client.get('/api/v1/mobile/chat?num=20',headers={'Authorization':'Bearer valid'})
        self.assertEqual(response.status_code,200)
        self.assertNotIn('server-side-only',response.text)
        self.logs.get_chat_message.assert_awaited_once_with(permission_code='server-side-only',num=20)
        self.assertEqual(self.client.get('/api/v1/mobile/chat?num=999',headers={'Authorization':'Bearer valid'}).status_code,422)
    def test_missing_bridge_configuration_returns_explicit_partial_failure(self):
        with patch.dict(os.environ,{'DEERAFT_INTERNAL_TOKEN':''}):
            response=self.client.get('/api/v1/community/status',headers={'Authorization':'Bearer valid'})
        self.assertEqual(response.status_code,200)
        self.assertIsNone(response.json()['mc'])
        self.assertFalse(response.json()['sources']['kook']['available'])
    def test_socket_rejects_bad_token_before_log_subscription(self):
        with self.client.websocket_connect('/api/v1/mobile/chat/ws?token=invalid') as socket:
            self.assertEqual(socket.receive()['code'],1008)
        self.logs.websocket_chat_messages.assert_not_called()
    def test_socket_reuses_existing_log_broadcaster(self):
        class Socket:
            async def accept(self):raise AssertionError('Host broadcaster owns acceptance')
        socket=Socket()
        asyncio.run(self.mobile.chat_socket(socket,token='valid',db=None))
        self.logs.websocket_chat_messages.assert_awaited_once_with(socket,permission_code='server-side-only')

if __name__=='__main__':unittest.main()
