"""Sign the static desktop release manifest. Keep the private key in Desktop/.secrets only."""
import argparse,base64,hashlib,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('installer',type=Path);p.add_argument('--version',default='0.6.1');a=p.parse_args()
desktop=Path(__file__).resolve().parents[1];key=desktop/'.secrets/release-signing/private.pem'
if not key.is_file():raise SystemExit('Release signing key is missing; do not generate a replacement key for an existing release channel')
payload=json.dumps(dict(version=a.version,kernel='11.1.1',platform='windows-x64',url='http://mc.ainfinitythecoder.cn/downloads/windows/'+a.installer.name,size=a.installer.stat().st_size,sha256=hashlib.file_digest(a.installer.open('rb'),'sha256').hexdigest()),separators=(',',':')).encode()
data=desktop/'.cache/release-signing/payload.json';signature=desktop/'.cache/release-signing/signature.bin';data.write_bytes(payload)
subprocess.run([str(desktop/'.toolchain/msys64/ucrt64/bin/openssl.exe'),'pkeyutl','-sign','-rawin','-inkey',str(key),'-in',str(data),'-out',str(signature)],check=True)
(desktop/'release/latest.json').write_text(json.dumps(dict(payload=base64.b64encode(payload).decode(),signature=base64.b64encode(signature.read_bytes()).decode()),indent=2)+'\n')
print('Signed manifest: Desktop/release/latest.json')
