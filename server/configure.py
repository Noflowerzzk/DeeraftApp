"""Create private bridge configuration using existing bot credentials, never printing them."""
import argparse
import ast
import os
from pathlib import Path
import secrets
import shlex

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bot',type=Path,default=Path('/home/ainfinity/QQ_bot'))
    parser.add_argument('--guild',default='4862343700531985')
    args=parser.parse_args()
    path=Path.home()/'.config/deeraft-app/environment'
    if path.exists():
        print('Private bridge configuration already exists; left unchanged.')
        return
    tree=ast.parse((args.bot/'src/plugins/kook.py').read_text(encoding='utf-8'))
    token=next(ast.literal_eval(node.value) for node in tree.body if isinstance(node,ast.Assign)
               and any(isinstance(target,ast.Name) and target.id=='KOOK_TOKEN' for target in node.targets))
    settings={'DEERAFT_INTERNAL_TOKEN':secrets.token_urlsafe(48),'DEERAFT_KOOK_TOKEN':token,
              'DEERAFT_KOOK_GUILD_ID':args.guild,'DEERAFT_BOT_ORIGIN':'http://127.0.0.1:8080'}
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    os.chmod(path.parent,0o700)
    fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w',encoding='utf-8') as handle:
        for key,value in settings.items():handle.write(key+'='+shlex.quote(value)+'\n')
    print('Private bridge configuration created (0600). No credentials printed.')

if __name__=='__main__':main()
