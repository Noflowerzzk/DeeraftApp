"""Scoped service reload. Dry-run unless --apply is explicitly supplied.
Preserves the original process environment in memory; never serializes it.
"""
import json,os,signal,subprocess,sys,time,urllib.request
from pathlib import Path
ROOT=Path('/home/ainfinity/backend/backend')
pid=int(sys.argv[1]);proc=Path('/proc')/str(pid)
cwd=Path(os.readlink(proc/'cwd')).resolve()
args=[x.decode() for x in (proc/'cmdline').read_bytes().split(b'\0') if x]
if cwd!=ROOT or args[1:4]!=['-m','uvicorn','main:app']:
 raise SystemExit('Process did not match the website backend; no action taken')
if '--apply' not in sys.argv:
 print('Verified the website backend process; --apply is required to restart')
 raise SystemExit(0)
environment={}
for item in (proc/'environ').read_bytes().split(b'\0'):
 if b'=' in item:
  key,value=item.split(b'=',1);environment[key.decode()]=value.decode()
log=Path(os.readlink(proc/'fd/1'))
if not log.is_absolute() or not str(log).startswith('/home/ainfinity/'):
 raise SystemExit('Unexpected log destination; no action taken')
# All verification and environment reads precede signaling the exact process.
os.kill(pid,signal.SIGTERM)
for _ in range(450):
 try:os.kill(pid,0)
 except ProcessLookupError:break
 time.sleep(.1)
else:raise SystemExit('Backend is still draining; no replacement was started')
def launch():
 with open(log,'ab',buffering=0) as out:
  return subprocess.Popen(args,cwd=ROOT,env=environment,stdin=subprocess.DEVNULL,stdout=out,stderr=out,start_new_session=True)
child=launch()
for _ in range(150):
 try:
  with urllib.request.urlopen('http://127.0.0.1:8000/openapi.json',timeout=1) as response:
   schema=json.load(response)
  if '/api/v1/mobile/activity' in schema.get('paths',{}):
   print('Website restarted with the activity API; process',child.pid)
   raise SystemExit(0)
 except (OSError,ValueError):pass
 if child.poll() is not None:break
 time.sleep(.2)
# Roll back only the router lines introduced by this change.
if child.poll() is None:
 child.terminate()
 try:child.wait(timeout=10)
 except subprocess.TimeoutExpired:raise SystemExit('New process is still draining; inspect the service log')
main=ROOT/'main.py';text=main.read_text(encoding='utf-8')
block='\nfrom app.controllers.activity_controller import router as activity_router\napp.include_router(activity_router)'
if text.count(block)!=1:raise SystemExit('Router rollback anchor changed; no unrelated source was modified')
main.write_text(text.replace(block,''),encoding='utf-8')
restored=launch()
raise SystemExit('New API startup failed; original router registration restored and backend restarted as '+str(restored.pid))
