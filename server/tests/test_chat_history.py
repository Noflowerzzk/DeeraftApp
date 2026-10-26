import asyncio
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import patch
from fastapi import WebSocketDisconnect

ROOT=Path(__file__).resolve().parents[1]/'backend/app/services'
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
store_module=load('chat_store_tests',ROOT/'chat_history_store.py')
with patch.dict(sys.modules,{
    'app.services.chat_history_store':store_module,
    'app.services.server_service':SimpleNamespace(server_service=SimpleNamespace()),
}):service_module=load('chat_service_tests',ROOT/'chat_history_service.py')

def chat(message='hello',player='Alice'):
    return f'[12:34:56] [Server thread/INFO]: <{player}> {message}\n'.encode()

class StoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.log=self.root/'latest.log'
        self.store=store_module.ChatHistoryStore(self.root/'history.sqlite3')
        self.addCleanup(self.store.close)
    def test_backfill_finds_chat_before_last_500_noise_lines(self):
        self.log.write_bytes(chat()+b'[12:35:00] [Server thread/INFO]: noise\n'*2000)
        self.assertEqual(len(self.store.ingest('test',self.log)),1)
        self.assertEqual(self.store.history('test')['messages'][0]['message'],'hello')
        self.assertEqual(self.store.ingest('test',self.log),[])
    def test_checkpoint_survives_restart_without_duplicates(self):
        self.log.write_bytes(chat());self.store.ingest('test',self.log);self.store.close()
        self.store=store_module.ChatHistoryStore(self.root/'history.sqlite3')
        self.addCleanup(self.store.close)
        self.assertEqual(self.store.ingest('test',self.log),[])
        with self.log.open('ab') as handle:handle.write(chat('next'))
        self.assertEqual(len(self.store.ingest('test',self.log)),1)
        self.assertEqual(self.store.history('test')['total'],2)
    def test_history_requests_do_not_read_the_log(self):
        self.log.write_bytes(chat());self.store.ingest('test',self.log)
        self.store.close();self.log.unlink()
        self.assertEqual(self.store.history('test')['messages'][0]['message'],'hello')
    def test_partial_utf8_line_is_collected_only_when_complete(self):
        line=chat('你好')
        self.log.write_bytes(line[:-3])
        self.assertEqual(self.store.ingest('test',self.log),[])
        with self.log.open('ab') as handle:handle.write(line[-3:])
        self.assertEqual(self.store.ingest('test',self.log)[0]['message'],'你好')
    @unittest.skipIf(os.name=='nt','Active-file rename semantics are verified on the Linux deployment host')
    def test_rotation_drains_old_handle_before_new_file(self):
        self.log.write_bytes(chat('first'));self.store.ingest('test',self.log)
        with self.log.open('ab') as handle:handle.write(chat('before rotation'))
        self.log.rename(self.root/'previous.log')
        self.log.write_bytes(chat('after rotation'))
        self.assertEqual([m['message'] for m in self.store.ingest('test',self.log)],['before rotation','after rotation'])
        self.assertEqual(self.store.history('test')['total'],3)
    def test_copy_truncate_regrow_detected_by_checkpoint_anchor(self):
        self.log.write_bytes(chat('first'));self.store.ingest('test',self.log)
        self.log.write_bytes(chat('different and longer content'))
        self.assertEqual(self.store.ingest('test',self.log)[0]['message'],'different and longer content')
        self.assertEqual(self.store.history('test')['total'],2)
    def test_repeated_identical_messages_are_not_deduplicated_by_text(self):
        self.log.write_bytes(chat()+chat());self.store.ingest('test',self.log)
        self.assertEqual(self.store.history('test')['total'],2)
    def test_history_is_limited_ordered_and_partitioned_by_server(self):
        self.log.write_bytes(chat('one')+chat('two')+chat('three'));self.store.ingest('A',self.log)
        self.store.ingest('B',self.log)
        history=self.store.history('A',2)
        self.assertEqual([m['message'] for m in history['messages']],['two','three'])
        self.assertEqual(history['total'],3);self.assertEqual(self.store.history('B')['total'],3)
    def test_join_leave_parser_and_non_chat_lines(self):
        self.assertEqual(store_module.parse_message('[26Oct2026 12:34:56.123] [Server thread/INFO]: Alice joined the game')['type'],'join')
        self.assertEqual(store_module.parse_message('[12:34:56] [Server thread/INFO]: Alice left the game')['type'],'leave')
        self.assertIsNone(store_module.parse_message('[12:34:56] [Server thread/INFO]: Saving world'))

class ServiceTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.logs={name:self.root/f'{name}.log' for name in ('A','B')}
        for path in self.logs.values():path.write_bytes(b'')
        self.active='A'
        self.store=store_module.ChatHistoryStore(self.root/'history.sqlite3')
        self.service=service_module.ChatHistoryService(store=self.store,provider=SimpleNamespace(
            get_running_server=lambda:self.active,get_latest_log_path=lambda server:self.logs[server]),interval=3600)
        await self.service.start()
    async def asyncTearDown(self):
        await self.service.stop();self.tmp.cleanup()
    async def test_collection_runs_with_no_clients_and_persists_when_server_stops(self):
        self.logs['A'].write_bytes(chat())
        await self.service._cycle()
        self.assertEqual((await self.service.history())['total'],1)
        self.active=None;self.service._next_discovery=0
        await self.service._cycle()
        self.assertEqual((await self.service.history())['total'],1)
    async def test_server_switch_publishes_reset_and_keeps_separate_histories(self):
        queue=asyncio.Queue(maxsize=5);self.service._subscribers.add(queue)
        self.logs['A'].write_bytes(chat('A'));await self.service._cycle();await queue.get()
        self.logs['B'].write_bytes(chat('B'));self.active='B';self.service._next_discovery=0
        await self.service._cycle()
        self.assertTrue((await queue.get())['reset'])
        self.assertEqual((await self.service.history())['messages'][0]['message'],'B')
        self.assertEqual(self.store.history('A')['total'],1)
    async def test_ws_history_and_live_messages_share_the_database_stream(self):
        self.logs['A'].write_bytes(chat('history'));await self.service._cycle()
        first=asyncio.Event();new=asyncio.Event();finished=asyncio.Event();frames=[]
        class Socket:
            async def accept(self):pass
            async def send_json(self,data):
                frames.append(data)
                if data['type']=='initial_chat_messages':first.set()
                else:new.set()
            async def receive_text(self):
                await finished.wait();raise WebSocketDisconnect()
        task=asyncio.create_task(self.service.serve(Socket()))
        await asyncio.wait_for(first.wait(),2)
        with self.logs['A'].open('ab') as handle:handle.write(chat('live'))
        await self.service._cycle();await asyncio.wait_for(new.wait(),2)
        finished.set();await task
        self.assertEqual(frames[0]['messages'][0]['message'],'history')
        self.assertEqual(frames[1]['messages'][0]['message'],'live')
        self.assertEqual(len(self.service._subscribers),0)
        self.assertIsNotNone(self.service._task)

if __name__=='__main__':unittest.main()
