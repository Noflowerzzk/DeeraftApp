import gzip
import importlib.util
from datetime import datetime
from pathlib import Path
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('daily_reader', Path(__file__).resolve().parents[1]/'backend/app/services/daily_playtime_reader.py')
reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)

class DailyTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
    def write(self, server, name, lines, mcdr=False):
        folder=self.root/server/('server/logs' if mcdr else 'logs');folder.mkdir(parents=True,exist_ok=True)
        p=folder/name
        if name.endswith('.gz'):
            with gzip.open(p,'wt',encoding='utf-8') as out:out.write(lines)
        else:p.write_text(lines,encoding='utf-8')
        return p
    def test_paper_login_disconnect_ignores_system_chat(self):
        self.write('a','2026-10-26.log','\n'.join([
            '[10:00:00] [Server thread/INFO]: Alice[/127.0.0.1:1] logged in with entity id 2 at (x)',
            '[10:00:01] [Server thread/INFO]: System chat: Fake joined the game',
            '[10:05:00] [Server thread/INFO]: Alice lost connection: Disconnected',
        ]))
        self.assertEqual(reader.read_daily(self.root,datetime(2026,10,26),now=datetime(2026,10,26,12)),{'Alice':5})
    def test_rotated_gzip_mcdr_and_multi_server_aggregate(self):
        self.write('a','2026-10-25-1.log.gz','[23:50:00] [Server thread/INFO]: Alice joined the game\n')
        self.write('a','2026-10-26-1.log.gz','[00:10:00] [Server thread/INFO]: Alice left the game\n')
        self.write('b','2026-10-26.log','[2026-10-26 11:00:00] [Server thread/INFO] [minecraft/Server]: Alice joined the game\n[2026-10-26 11:20:00] [Server thread/INFO] [minecraft/Server]: Alice left the game\n',True)
        self.assertEqual(reader.read_daily(self.root,datetime(2026,10,26),now=datetime(2026,10,26,12)),{'Alice':30})
    def test_stop_bounds_sessions_duplicate_join_does_not_double_count(self):
        self.write('a','2026-10-26.log','[10:00:00] [Server thread/INFO]: Alice joined the game\n[10:00:01] [Server thread/INFO]: Alice joined the game\n[10:10:00] [Server thread/INFO]: Stopping server\n')
        self.assertEqual(reader.read_daily(self.root,datetime(2026,10,26),now=datetime(2026,10,26,12),running_server='a'),{'Alice':10})
    def test_unclosed_offline_server_is_not_counted_until_now(self):
        self.write('a','2026-10-26.log','[10:00:00] [Server thread/INFO]: Alice joined the game\n[10:05:00] [Server thread/INFO]: Saving world\n')
        self.assertEqual(reader.read_daily(self.root,datetime(2026,10,26),now=datetime(2026,10,26,12)),{'Alice':5})
        self.assertEqual(reader.read_daily(self.root,datetime(2026,10,26),now=datetime(2026,10,26,12),running_server='a'),{'Alice':120})

if __name__=='__main__':unittest.main()
