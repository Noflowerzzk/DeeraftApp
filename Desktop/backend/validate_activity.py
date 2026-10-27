"""Dependency-free ASGI checks inside the existing backend environment."""
import asyncio
import json
from types import SimpleNamespace
from pathlib import Path
from tempfile import TemporaryDirectory
from uuid import uuid4
from fastapi import FastAPI
from app.controllers import activity_controller as activity
from app.services.activity_store import ActivityStore

async def main():
 app=FastAPI();app.include_router(activity.router)
 app.dependency_overrides[activity.get_db]=lambda:None
 async def http(method,path,payload=None,query=b''):
  messages=[];sent=False
  async def receive():
   nonlocal sent
   if not sent:
    sent=True
    return {'type':'http.request','body':json.dumps(payload).encode() if payload is not None else b'','more_body':False}
   return {'type':'http.disconnect'}
  async def send(message):messages.append(message)
  await app({'type':'http','asgi':{'version':'3.0'},'http_version':'1.1','scheme':'http','method':method,'path':path,'raw_path':path.encode(),'root_path':'','query_string':query,'headers':[(b'content-type',b'application/json')],'client':('127.0.0.1',1234),'server':('test',80)},receive,send)
  status=next(m['status'] for m in messages if m['type']=='http.response.start')
  body=b''.join(m.get('body',b'') for m in messages if m['type']=='http.response.body')
  return status,json.loads(body) if body else None
 with TemporaryDirectory(prefix='deeraft-activity-test-') as temporary:
  activity.store=ActivityStore(Path(temporary)/'activity.sqlite3')
  assert (await http('GET','/api/v1/mobile/activity'))[0] in (401,403)
  app.dependency_overrides[activity.get_current_user]=lambda:SimpleNamespace(id=123,username='ActivityFixture')
  event={'event_id':str(uuid4()),'instance':'Fixture World','version':'1.21.4','player':'Untrusted','user_id':999}
  code,row=await http('POST','/api/v1/mobile/activity',event)
  assert code==200,(code,row)
  assert row['player']=='ActivityFixture' and 'user_id' not in row
  assert (await http('POST','/api/v1/mobile/activity',event))[1]['id']==row['id']
  assert len((await http('GET','/api/v1/mobile/activity'))[1]['items'])==1
  assert (await http('GET','/api/v1/mobile/activity',query=('after='+str(row['id'])).encode()))[1]['items']==[]
  assert (await http('POST','/api/v1/mobile/activity',{**event,'event_id':'invalid'}))[0]==422
  messages=[]
  async def receive():return {'type':'websocket.connect'}
  async def send(message):messages.append(message)
  await app({'type':'websocket','asgi':{'version':'3.0'},'scheme':'ws','path':'/api/v1/mobile/activity/ws','raw_path':b'/api/v1/mobile/activity/ws','root_path':'','query_string':b'','headers':[],'subprotocols':[],'client':('127.0.0.1',1234),'server':('test',80)},receive,send)
  assert any(m['type']=='websocket.close' and m['code']==1008 for m in messages),messages
 print('Activity authentication, actor binding, deduplication, cursor, validation and websocket rejection: PASS')
asyncio.run(main())
