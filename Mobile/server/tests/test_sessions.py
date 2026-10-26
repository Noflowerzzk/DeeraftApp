from pathlib import Path
import importlib.util
import sqlite3
from contextlib import closing
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor

spec=importlib.util.spec_from_file_location('mobile_session_store',Path(__file__).resolve().parents[1]/'backend/app/services/mobile_session_store.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class SessionTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.now=1000
        self.path=Path(self.tmp.name)/'sessions.sqlite3'
        self.store=module.SessionStore(self.path,clock=lambda:self.now)
    def test_survives_service_restart_and_stores_no_plaintext_token(self):
        token=self.store.issue(7)
        restarted=module.SessionStore(self.path,clock=lambda:self.now)
        self.assertEqual(restarted.resolve(token),7)
        with closing(sqlite3.connect(self.path)) as db:
            self.assertNotEqual(db.execute('SELECT digest FROM sessions').fetchone()[0],token)
    def test_idle_expiration_and_revoke(self):
        token=self.store.issue(7)
        self.now+=module.IDLE_SECONDS+1
        self.assertIsNone(self.store.resolve(token))
        token=self.store.issue(8);self.store.revoke(token)
        self.assertIsNone(self.store.resolve(token))
    def test_active_session_slides_but_has_absolute_limit(self):
        token=self.store.issue(9)
        for _ in range(4):
            self.now+=80*86400
            self.assertEqual(self.store.resolve(token),9)
        self.now+=46*86400
        self.assertIsNone(self.store.resolve(token))
    def test_parallel_refresh_requests_do_not_invalidate_each_other(self):
        token=self.store.issue(10)
        with ThreadPoolExecutor(max_workers=6) as pool:
            self.assertEqual(list(pool.map(lambda _:self.store.resolve(token),range(12))),[10]*12)

if __name__=='__main__':unittest.main()
