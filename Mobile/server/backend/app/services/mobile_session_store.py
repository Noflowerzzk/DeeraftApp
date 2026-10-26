"""Revocable opaque mobile sessions; only SHA-256 token digests are persisted."""
from contextlib import contextmanager
import hashlib
import os
from pathlib import Path
import secrets
import sqlite3
import time

IDLE_SECONDS = 90 * 86400
MAX_SECONDS = 365 * 86400

class SessionStore:
    def __init__(self, path=None, clock=time.time):
        self.path=Path(path or Path(__file__).resolve().parents[2]/'data/mobile_sessions.sqlite3')
        self.clock=clock

    @contextmanager
    def connect(self):
        self.path.parent.mkdir(parents=True,exist_ok=True)
        conn=sqlite3.connect(self.path,timeout=5,isolation_level=None)
        try:
            os.chmod(self.path,0o600)
            conn.execute('CREATE TABLE IF NOT EXISTS sessions (digest TEXT PRIMARY KEY,user_id INTEGER NOT NULL,expires REAL NOT NULL,absolute_expires REAL NOT NULL)')
            conn.execute('DELETE FROM sessions WHERE expires<=? OR absolute_expires<=?',(self.clock(),self.clock()))
            yield conn
        finally:conn.close()

    def issue(self,user_id):
        token=secrets.token_urlsafe(48)
        now=self.clock()
        with self.connect() as db:
            db.execute('INSERT INTO sessions VALUES(?,?,?,?)',(self.digest(token),user_id,now+IDLE_SECONDS,now+MAX_SECONDS))
        return token

    @staticmethod
    def digest(token):return hashlib.sha256(token.encode()).hexdigest()

    def resolve(self,token):
        now=self.clock()
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            row=db.execute('SELECT user_id,absolute_expires FROM sessions WHERE digest=? AND expires>? AND absolute_expires>?',
                           (self.digest(token),now,now)).fetchone()
            if row:db.execute('UPDATE sessions SET expires=? WHERE digest=?',(min(now+IDLE_SECONDS,row[1]),self.digest(token)))
            db.commit()
        return row[0] if row else None

    def revoke(self,token):
        with self.connect() as db:db.execute('DELETE FROM sessions WHERE digest=?',(self.digest(token),))
