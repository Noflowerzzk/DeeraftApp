"""Restore only unchanged installed files from one manifest; never overwrite later edits."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest',type=Path)
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    records=json.loads(args.manifest.read_text(encoding='utf-8'))
    for item in records:
        path=Path(item['path'])
        if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=item['installed_sha256']:
            raise RuntimeError(f'File changed after installation: {path}')
    for item in records:
        path=Path(item['path']);print(('restore ' if item['backup'] else 'remove ')+str(path))
        if args.apply:
            if item['backup']:
                shutil.copy2(args.manifest.parent/item['backup'],path)
            else:
                path.unlink()
    print('Processes were not restarted.')

if __name__=='__main__':main()
