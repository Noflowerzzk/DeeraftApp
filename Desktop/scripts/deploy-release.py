"""Publish immutable installer + signed static manifest on the existing website via SSH."""
import argparse,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('installer',type=Path);a=p.parse_args()
desktop=Path(__file__).resolve().parents[1]
name=a.installer.name
if not name.startswith('DeeraftApp-') or not name.endswith('-windows-x64-setup.exe') or '/' in name or '\\' in name:raise SystemExit('Unexpected installer filename')
def remote(source):subprocess.run(['ssh','-o','BatchMode=yes','AInfinity','python3','-'],input=source.encode(),check=True)
root='/home/ainfinity/backend/frontend/public/downloads'
stage='/home/ainfinity/backend/.deeraft-release-stage'
remote(f"from pathlib import Path\nPath({root!r}+'/windows').mkdir(parents=True,exist_ok=True)\nPath({stage!r}).mkdir(parents=True,exist_ok=True)\n")
for local,target in [(a.installer,stage+'/'+name+'.part'),(desktop/'release/latest.json',stage+'/latest.json.part'),(desktop/'release/site/index.html',stage+'/index.html.part'),(desktop/'app/assets/deeraft.png',stage+'/deeraft.png.part')]:
 subprocess.run(['scp','-q',str(local),'AInfinity:'+target],check=True)
remote(f'''from pathlib import Path
from datetime import datetime,timezone
import os,json,base64,hashlib
root=Path({root!r});stage=Path({stage!r});name={name!r}
manifest=json.loads((stage/'latest.json.part').read_text());release=json.loads(base64.b64decode(manifest['payload']))
installer=root/'windows'/name
with (stage/(name+'.part')).open('rb') as file: actual=hashlib.file_digest(file,'sha256').hexdigest()
if actual!=release['sha256'] or (stage/(name+'.part')).stat().st_size!=release['size']:raise SystemExit('Uploaded installer does not match manifest')
if installer.exists():
 with installer.open('rb') as file: old=hashlib.file_digest(file,'sha256').hexdigest()
 if old!=actual:raise SystemExit('An existing release cannot be overwritten with different bytes; choose a new version')
os.replace(stage/(name+'.part'),installer)
os.replace(stage/'deeraft.png.part',root/'deeraft.png')
os.replace(stage/'index.html.part',root/'index.html')
os.replace(stage/'latest.json.part',root/'windows/latest.json')
header=Path('/home/ainfinity/backend/frontend/src/components/layout/Header.vue');source=header.read_text()
if 'href="/downloads/index.html"' not in source:
 anchor='        <ThemeToggle />'
 if source.count(anchor)!=1:raise SystemExit('Header anchor changed; release published but navigation was not changed')
 backups=Path('/home/ainfinity/backend/backend/data/deeraft-source-backups');backups.mkdir(parents=True,exist_ok=True)
 (backups/('Header-'+datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')+'.vue')).write_text(source)
 header.write_text(source.replace(anchor,'        <a class="tab-item" href="/downloads/index.html" style="color:inherit;text-decoration:none;white-space:nowrap">下载 App</a>'+chr(10)+anchor))
print('Published signed release',release['version'],'without restarting the backend')
''')
