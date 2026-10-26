"""Restart only the two known service processes, preserving their environment.

Run after install.py and the backend import check. No Minecraft process is touched.
"""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import time
import urllib.request

HOME=Path('/home/ainfinity')

def find_process(cwd, argument):
    found=[]
    for proc in Path('/proc').iterdir():
        if not proc.name.isdecimal():continue
        try:
            if (proc/'cwd').resolve()!=cwd:continue
            args=[item.decode() for item in (proc/'cmdline').read_bytes().split(b'\0') if item]
            if argument == 'run.py':
                is_backend = argument in args or args[1:4] == ['-m', 'uvicorn', 'main:app'] or any('from multiprocessing.spawn import spawn_main' in arg for arg in args)
                if not is_backend:continue
            elif argument not in args:continue
            environment=dict(entry.decode().split('=',1) for entry in (proc/'environ').read_bytes().split(b'\0') if b'=' in entry)
            found.append((int(proc.name),str((proc/'exe').resolve()),args,environment))
        except (OSError,PermissionError):continue
    if len(found)!=1:raise RuntimeError(f'Expected exactly one {argument} process, found {len(found)}')
    return found[0]

def stop(pid):
    for sig,wait in ((signal.SIGINT,6),(signal.SIGTERM,6),(signal.SIGKILL,2)):
        try:os.kill(pid,sig)
        except ProcessLookupError:return
        for _ in range(wait*4):
            path=Path(f'/proc/{pid}/stat')
            if not path.exists():return
            try:
                if path.read_text().split(') ',1)[1].startswith('Z'):return
            except OSError:return
            time.sleep(.25)
    raise RuntimeError(f'Process did not stop: {pid}')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend',action='store_true')
    parser.add_argument('--bot',action='store_true')
    args=parser.parse_args()
    logdir=HOME/'.config/deeraft-app'
    if args.backend:
        cwd=HOME/'backend/backend'
        pid,exe,argv,env=find_process(cwd,'run.py')
        stop(pid)
        fd=os.open(logdir/'backend.log',os.O_WRONLY|os.O_CREAT|os.O_APPEND,0o600)
        with os.fdopen(fd,'ab') as log:
            child=subprocess.Popen([exe,'-m','uvicorn','main:app','--host','0.0.0.0','--port','8000',
                                    '--limit-concurrency','1000','--timeout-keep-alive','600'],cwd=cwd,env=env,stdin=subprocess.DEVNULL,
                                   stdout=log,stderr=log,start_new_session=True)
        for _ in range(12):
            if child.poll() is not None:raise RuntimeError('Backend exited; inspect private backend.log')
            try:
                with urllib.request.urlopen('http://127.0.0.1:8000/health',timeout=2) as response:
                    if response.status==200:break
            except Exception:time.sleep(.5)
        else:raise RuntimeError('Backend health check failed')
        print('Backend restarted; health check passed.')
    if args.bot:
        cwd=HOME/'QQ_bot'
        pid,exe,argv,env=find_process(cwd,'bot.py')
        stop(pid)
        # nb run exits with its child; allow its old screen to close.
        time.sleep(1)
        subprocess.run(['screen','-L','-Logfile',str(logdir/'bot.log'),'-dmS','bot',exe,'bot.py'],
                       cwd=cwd,env=env,check=True)
        print('Bot restarted in screen; existing adapters and data retained.')

if __name__=='__main__':main()
