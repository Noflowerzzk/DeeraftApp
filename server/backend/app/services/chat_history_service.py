"""One server-owned collector, independent of HTTP/WS client lifetimes."""
import asyncio
import logging
import time
from fastapi import WebSocketDisconnect
from app.services.chat_history_store import ChatHistoryStore
from app.services.server_service import server_service

logger=logging.getLogger(__name__)

class ChatHistoryService:
    def __init__(self,store=None,provider=None,interval=1):
        self.store=store or ChatHistoryStore()
        self.provider=provider or server_service
        self.interval=interval
        self.current_server=None
        self._next_discovery=0
        self._task=None
        self._subscribers=set()
        self._tracked=set()
        self._scan_task=None
        self._scan_lock=asyncio.Lock()

    def _scan(self):
        changed=False
        if time.monotonic()>=self._next_discovery:
            active=self.provider.get_running_server()
            self._next_discovery=time.monotonic()+5
            if active:
                self._tracked.add(active)
                if active!=self.current_server:
                    self.current_server=active;self.store.remember_server(active);changed=True
        messages=[]
        # Also drain the final lines after an instance stops or another starts.
        for server in sorted(self._tracked):
            messages.extend(self.store.ingest(server,self.provider.get_latest_log_path(server)))
        return changed,messages

    async def _cycle(self):
        async with self._scan_lock:
            self._scan_task=asyncio.create_task(asyncio.to_thread(self._scan))
            changed,messages=await asyncio.shield(self._scan_task)
        if changed:self._publish({'reset':True})
        if messages:self._publish({'messages':messages})

    def _publish(self,event):
        for queue in tuple(self._subscribers):
            if queue.full():
                while not queue.empty():queue.get_nowait()
                queue.put_nowait({'reset':True})
            else:queue.put_nowait(event)

    async def start(self):
        if self._task is not None:return
        self.current_server=await asyncio.to_thread(self.store.last_server)
        if self.current_server:self._tracked.add(self.current_server)
        try:await self._cycle()
        except Exception:logger.exception('Initial chat collection failed; will retry')
        self._task=asyncio.create_task(self._run(),name='chat-history-collector')

    async def _run(self):
        while True:
            await asyncio.sleep(self.interval)
            try:await self._cycle()
            except Exception:logger.exception('Chat collection failed; checkpoint retained for retry')

    async def stop(self):
        if self._task is not None:
            self._task.cancel()
            try:await self._task
            except asyncio.CancelledError:pass
            self._task=None
        if self._scan_task is not None:
            await asyncio.gather(self._scan_task,return_exceptions=True)
        await asyncio.to_thread(self.store.close)

    async def history(self,limit=100):
        return await asyncio.to_thread(self.store.history,self.current_server,limit)

    async def serve(self,websocket):
        await websocket.accept()
        queue=asyncio.Queue(maxsize=64);self._subscribers.add(queue)
        async def send():
            server=None;last_id=0
            async def snapshot():
                nonlocal server,last_id
                server=self.current_server
                history=await asyncio.to_thread(self.store.history,server,100)
                last_id=max((m['id'] for m in history['messages']),default=0)
                await websocket.send_json({'type':'initial_chat_messages','messages':history['messages'],
                                           'count':history['returned'],'total_lines':history['total']})
            await snapshot()
            while True:
                event=await queue.get()
                if event.get('reset') or server!=self.current_server:
                    await snapshot();continue
                rows=[m for m in event.get('messages',[]) if m['server_name']==server and m['id']>last_id]
                if rows:
                    await websocket.send_json({'type':'new_chat_messages','messages':rows,'count':len(rows)})
                    last_id=max(m['id'] for m in rows)
        async def receive():
            while True:
                if await websocket.receive_text()=='ping':await websocket.send_text('pong')
        tasks=[asyncio.create_task(send()),asyncio.create_task(receive())]
        try:
            done,_=await asyncio.wait(tasks,return_when=asyncio.FIRST_COMPLETED)
            for task in done:task.result()
        except WebSocketDisconnect:pass
        finally:
            self._subscribers.discard(queue)
            for task in tasks:task.cancel()
            await asyncio.gather(*tasks,return_exceptions=True)

chat_history_service=ChatHistoryService()
