import asyncio
import base64
import hashlib
import importlib.util
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import tempfile
import unittest
import sys
from types import ModuleType

ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result
store_module=module('oauth_store','backend/app/services/mobile_oauth_store.py')
environment=module('environment','environment.py')
stub=ModuleType('src.services.mobile_environment');stub.load_environment=lambda:None
sys.modules['src.services.mobile_environment']=stub
queries=module('community_queries','qq_bot/src/services/community_query.py')
installer=module('installer','formatters.py')

class OAuthTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.now=1000
        self.store=store_module.OAuthStore(Path(self.tmp.name)/'oauth.sqlite3',clock=lambda:self.now)
        self.verifier='v'*43
        self.challenge=base64.urlsafe_b64encode(hashlib.sha256(self.verifier.encode()).digest()).decode().rstrip('=')
    def prepare(self):
        state=self.store.start(self.challenge,'client-state')
        self.assertEqual(self.store.begin_callback(state),'client-state')
        return state,self.store.complete(state,'access-token')
    def test_exchange_once(self):
        state,code=self.prepare()
        self.assertIsNone(self.store.begin_callback(state))
        self.assertIsNone(self.store.exchange(code,'wrong-verifier'))
        self.assertEqual(self.store.exchange(code,self.verifier),'access-token')
        self.assertIsNone(self.store.exchange(code,self.verifier))
    def test_expiration(self):
        _,code=self.prepare();self.now+=61
        self.assertIsNone(self.store.exchange(code,self.verifier))
        state=self.store.start(self.challenge,'client-state');self.now+=301
        self.assertIsNone(self.store.begin_callback(state))
    def test_multi_worker_single_claim(self):
        _,code=self.prepare()
        with ThreadPoolExecutor(max_workers=8) as pool:
            results=list(pool.map(lambda _:self.store.exchange(code,self.verifier),range(8)))
        self.assertEqual(results.count('access-token'),1)
    def test_multi_worker_callback_claim(self):
        state=self.store.start(self.challenge,'client-state')
        with ThreadPoolExecutor(max_workers=8) as pool:
            results=list(pool.map(lambda _:self.store.begin_callback(state),range(8)))
        self.assertEqual(results.count('client-state'),1)

class QueryTests(unittest.IsolatedAsyncioTestCase):
    async def test_single_source_failure(self):
        async def good():return {'channels':[]}
        async def bad():raise RuntimeError('secret should not be exposed')
        data=await queries.collect_status(bad,good)
        self.assertIsNone(data['mc']);self.assertTrue(data['sources']['kook']['available'])
        self.assertNotIn('secret',str(data));self.assertFalse(data['sources']['mc']['available'])
    async def test_cache_coalesces_and_expires(self):
        calls=0;now=[0]
        async def loader():
            nonlocal calls
            calls+=1;await asyncio.sleep(.01);return {'version':calls}
        cache=queries.StatusCache(loader,clock=lambda:now[0])
        results=await asyncio.gather(*(cache.get() for _ in range(20)))
        self.assertEqual(calls,1);self.assertTrue(all(r=={'version':1} for r in results))
        now[0]=16;self.assertEqual(await cache.get(),{'version':2})

class FormatterTests(unittest.TestCase):
    def test_formatters_compile(self):
        compile(installer.MC_FORMATTER,'mc_formatter','exec')
        compile(installer.KOOK_FORMATTER,'kook_formatter','exec')

if __name__=='__main__':unittest.main()
