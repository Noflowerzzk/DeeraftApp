"""Register only the new activity router, preserving all other backend edits."""
from datetime import datetime,timezone
from pathlib import Path
import sys
root=Path(sys.argv[1]).resolve()
main=root/'main.py'
source=main.read_text(encoding='utf-8')
marker='from app.controllers.activity_controller import router as activity_router'
if marker in source:
 print('Activity router is already registered')
else:
 anchor='app.include_router(mobile_session_router)'
 if source.count(anchor)!=1:raise SystemExit('Expected router registration anchor was not unique')
 backup=root/'data'/'deeraft-source-backups'/('main-'+datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')+'.py')
 backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(main.read_bytes())
 updated=source.replace(anchor,anchor+'\n'+marker+'\napp.include_router(activity_router)')
 compile(updated,str(main),'exec')
 main.write_text(updated,encoding='utf-8')
 print('Registered activity router; preserved original main.py in',backup)
