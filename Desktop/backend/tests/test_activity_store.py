import importlib.util
from pathlib import Path
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
spec=importlib.util.spec_from_file_location('activity_store',Path(__file__).parents[1]/'activity_store.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class ActivityStoreTest(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.store=module.ActivityStore(Path(self.tmp.name)/'events.sqlite3')
 def test_persistent_and_idempotent_per_actor(self):
  first=self.store.record(1,'Alice','same-id','World','1.21.4')
  second=self.store.record(1,'Alice','same-id','Changed','other')
  other=self.store.record(2,'Bob','same-id','Other','1.20.1')
  self.assertEqual(first,second);self.assertNotEqual(first['id'],other['id'])
  history=module.ActivityStore(self.store.path).history()
  self.assertEqual([r['instance'] for r in history['items']],['World','Other'])
  self.assertNotIn('user_id',history['items'][0])
 def test_snapshot_latest_and_cursor_no_repeats(self):
  rows=[self.store.record(1,'A',str(i),'World','') for i in range(6)]
  self.assertEqual([r['id'] for r in self.store.history(limit=2)['items']],[rows[4]['id'],rows[5]['id']])
  self.assertEqual(len(self.store.history(after=rows[1]['id'],limit=2)['items']),2)
  self.assertEqual(self.store.history(after=rows[-1]['id'])['items'],[])
 def test_concurrent_duplicate_only_one_record(self):
  self.store.history()
  with ThreadPoolExecutor(max_workers=4) as pool:
   rows=list(pool.map(lambda _:self.store.record(1,'A','once','World',''),range(8)))
  self.assertEqual(len({r['id'] for r in rows}),1)
  self.assertEqual(len(self.store.history()['items']),1)
if __name__=='__main__':unittest.main()
