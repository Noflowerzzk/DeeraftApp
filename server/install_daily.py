"""Install only the reviewed daily-reader fix without rewriting other backend code."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import shutil
import time
from daily_patch import DAILY_ROUTE


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend',type=Path,required=True)
    parser.add_argument('--expected-log-sha',required=True)
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    root=Path(__file__).resolve().parent
    controller=args.backend/'app/controllers/log_controller.py'
    original=controller.read_bytes()
    if hashlib.sha256(original).hexdigest()!=args.expected_log_sha:
        raise RuntimeError('Controller changed since inspection; review again')
    source=original.decode('utf-8');lines=source.splitlines(keepends=True)
    node=next(n for n in ast.parse(source).body if isinstance(n,ast.AsyncFunctionDef) and n.name=='get_daily_playtime')
    patched=''.join(lines[:node.lineno-1])+DAILY_ROUTE+''.join(lines[node.end_lineno:])
    reader_file=root/'backend/app/services/daily_playtime_reader.py'
    if not reader_file.exists():reader_file=root/'daily_playtime_reader.py'
    target=args.backend/'app/services/daily_playtime_reader.py'
    changes={controller:patched.encode(),target:reader_file.read_bytes()}
    for data in changes.values():ast.parse(data.decode('utf-8-sig'))
    originals={p:p.read_bytes() if p.exists() else None for p in changes}
    print(json.dumps({'mode':'apply' if args.apply else 'check','files':[str(p) for p in changes]}))
    if not args.apply:return
    backup=root/'backups'/time.strftime('%Y%m%d-%H%M%S');backup.mkdir(parents=True,mode=0o700)
    manifest=[]
    for i,(path,data) in enumerate(changes.items()):
        if originals[path] is not None:shutil.copy2(path,backup/str(i))
        manifest.append({'path':str(path),'backup':str(i) if originals[path] is not None else None,'installed_sha256':hashlib.sha256(data).hexdigest()})
    (backup/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    for path,data in changes.items():
        if (path.read_bytes() if path.exists() else None)!=originals[path]:raise RuntimeError('File changed during install')
        temporary=path.with_name(path.name+'.deeraft-tmp');temporary.write_bytes(data);temporary.replace(path)
    print('Backup manifest: '+str(backup/'manifest.json'))

if __name__=='__main__':main()
