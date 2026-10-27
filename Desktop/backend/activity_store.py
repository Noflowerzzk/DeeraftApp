"""Bounded launcher activity history. No paths, credentials, or server addresses."""
import sqlite3
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

class ActivityStore:
    def __init__(self, path):
        self.path = Path(path)

    def connect(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        db.execute("CREATE TABLE IF NOT EXISTS activity (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, event_id TEXT NOT NULL, player TEXT NOT NULL, instance TEXT NOT NULL, version TEXT NOT NULL, time TEXT NOT NULL, UNIQUE(user_id,event_id))")
        db.commit()
        return db

    def record(self, user_id, player, event_id, instance, version):
        with closing(self.connect()) as db, db:
            db.execute('BEGIN IMMEDIATE')
            existing = db.execute('SELECT * FROM activity WHERE user_id=? AND event_id=?', (user_id,event_id)).fetchone()
            if existing:
                return dict(existing)
            now = datetime.now(timezone.utc).isoformat()
            cursor = db.execute('INSERT INTO activity(user_id,event_id,player,instance,version,time) VALUES(?,?,?,?,?,?)', (user_id,event_id,player,instance,version,now))
            row = db.execute('SELECT * FROM activity WHERE id=?', (cursor.lastrowid,)).fetchone()
            db.execute('DELETE FROM activity WHERE id < (SELECT COALESCE(MAX(id),0)-20000 FROM activity)')
            return dict(row)

    def history(self, after=0, limit=50):
        limit = max(1,min(int(limit),200))
        with closing(self.connect()) as db:
            if after:
                rows = db.execute('SELECT * FROM activity WHERE id>? ORDER BY id LIMIT ?', (after,limit)).fetchall()
            else:
                rows = list(reversed(db.execute('SELECT * FROM activity ORDER BY id DESC LIMIT ?', (limit,)).fetchall()))
            # User IDs are internal; clients display the server-resolved username.
            items = [{k:r[k] for k in ('id','event_id','player','instance','version','time')} for r in rows]
            return {'items':items,'cursor':items[-1]['id'] if items else after}
