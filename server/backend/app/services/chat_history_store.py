"""Incremental single-writer log ingestion with durable byte checkpoints."""
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path
import re
import sqlite3

MAX_BATCH = 1024 * 1024
ANSI = re.compile(r'\x1b\[[0-9;]*m')
INFO = re.compile(r'\[(?:Server thread|Async Chat Thread[^\]]*)/INFO\]')
CHAT = re.compile(r'<([^>]+)>\s+(.+)')
PRESENCE = re.compile(r'([^\s]+)\s+(joined|left) the game')
CLOCK = re.compile(r'(?<!\d)(\d{2}:\d{2}:\d{2})(?:\.\d+)?')

def parse_message(raw):
    line=ANSI.sub('',raw.decode('utf-8',errors='replace') if isinstance(raw,bytes) else raw).rstrip('\r\n')
    header=INFO.search(line)
    if not header:return None
    clock=CLOCK.search(line[:header.start()])
    time=clock.group(1) if clock else '00:00:00'
    text=line[header.end():]
    chat=CHAT.search(text)
    if chat:return {'time':time,'player':chat.group(1),'message':chat.group(2),'type':'chat'}
    presence=PRESENCE.search(text)
    if presence:
        joined=presence.group(2)=='joined'
        return {'time':time,'player':presence.group(1),'message':'joined the game' if joined else 'left the game','type':'join' if joined else 'leave'}
    return None

class ChatHistoryStore:
    def __init__(self,path=None):
        self.path=Path(path or Path(__file__).resolve().parents[2]/'data/chat_history.sqlite3')
        self.handles={}

    @contextmanager
    def connect(self):
        self.path.parent.mkdir(parents=True,exist_ok=True)
        db=sqlite3.connect(self.path,timeout=5,isolation_level=None)
        db.row_factory=sqlite3.Row
        try:
            os.chmod(self.path,0o600)
            db.execute('PRAGMA journal_mode=WAL')
            db.execute('CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY AUTOINCREMENT,server_name TEXT NOT NULL,time TEXT NOT NULL,player TEXT NOT NULL,message TEXT NOT NULL,type TEXT NOT NULL,source TEXT NOT NULL,generation INTEGER NOT NULL,position INTEGER NOT NULL,captured_at TEXT NOT NULL,UNIQUE(source,generation,position))')
            db.execute('CREATE INDEX IF NOT EXISTS chat_server_id ON messages(server_name,id)')
            db.execute('CREATE TABLE IF NOT EXISTS checkpoints (source TEXT PRIMARY KEY,dev INTEGER,ino INTEGER,offset INTEGER,generation INTEGER,anchor TEXT,skipping INTEGER NOT NULL DEFAULT 0)')
            db.execute('CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY,value TEXT)')
            yield db
        finally:db.close()

    def last_server(self):
        with self.connect() as db:
            row=db.execute("SELECT value FROM metadata WHERE key='server'").fetchone()
            return row['value'] if row else None

    def remember_server(self,server):
        with self.connect() as db:
            db.execute("INSERT INTO metadata VALUES('server',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",(server,))

    @staticmethod
    def anchor(handle,offset):
        handle.seek(max(0,offset-64))
        return hashlib.sha256(handle.read(min(offset,64))).hexdigest()

    def _ingest_handle(self,server,source,handle,final=False):
        stat=os.fstat(handle.fileno())
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            row=db.execute('SELECT * FROM checkpoints WHERE source=?',(source,)).fetchone()
            same=row is not None and (row['dev'],row['ino'])==(stat.st_dev,stat.st_ino)
            intact=same and stat.st_size>=row['offset'] and self.anchor(handle,row['offset'])==row['anchor']
            offset=row['offset'] if intact else 0
            generation=row['generation'] if intact else (row['generation']+1 if row else 0)
            skipping=bool(row['skipping']) if intact else False
            handle.seek(offset)
            data=handle.read(MAX_BATCH)
            end=data.rfind(b'\n')+1
            if final and len(data)<MAX_BATCH:end=len(data)
            messages=[]
            if end:
                consumed=data[:end]
                position=offset
                for raw in consumed.splitlines(keepends=True):
                    if skipping:skipping=False
                    else:
                        message=parse_message(raw)
                        if message:
                            result=db.execute('INSERT OR IGNORE INTO messages(server_name,time,player,message,type,source,generation,position,captured_at) VALUES(?,?,?,?,?,?,?,?,?)',
                                (server,message['time'],message['player'],message['message'],message['type'],source,generation,position,datetime.now(timezone.utc).isoformat()))
                            if result.rowcount:messages.append({'id':result.lastrowid,'server_name':server,**message})
                    position+=len(raw)
                offset+=end
            elif len(data)==MAX_BATCH:
                # Skip a pathological oversized log line without blocking all later chat.
                offset+=len(data);skipping=True
            # A normal incomplete UTF-8/log line is retried after its newline arrives.
            anchor=self.anchor(handle,offset)
            db.execute('INSERT INTO checkpoints VALUES(?,?,?,?,?,?,?) ON CONFLICT(source) DO UPDATE SET dev=excluded.dev,ino=excluded.ino,offset=excluded.offset,generation=excluded.generation,anchor=excluded.anchor,skipping=excluded.skipping',
                       (source,stat.st_dev,stat.st_ino,offset,generation,anchor,int(skipping)))
            db.commit()
        return messages, offset>=os.fstat(handle.fileno()).st_size

    def ingest(self,server,path):
        path=Path(path);source=server+'\0'+str(path.absolute())
        handle=self.handles.get(source)
        try:current=path.stat()
        except FileNotFoundError:current=None
        result=[]
        if handle is not None:
            opened=os.fstat(handle.fileno())
            if current is None or (opened.st_dev,opened.st_ino)!=(current.st_dev,current.st_ino):
                messages,finished=self._ingest_handle(server,source,handle,final=True)
                result.extend(messages)
                if not finished:return result
                handle.close();self.handles.pop(source,None);handle=None
        if handle is None:
            if current is None:return result
            handle=path.open('rb');self.handles[source]=handle
        messages,_=self._ingest_handle(server,source,handle)
        return result+messages

    def history(self,server,limit=100):
        if server is None:return {'messages':[],'total':0,'returned':0}
        with self.connect() as db:
            db.execute('BEGIN')
            total=db.execute('SELECT COUNT(*) FROM messages WHERE server_name=?',(server,)).fetchone()[0]
            sql='SELECT id,time,player,message,type FROM messages WHERE server_name=? ORDER BY id DESC'
            args=[server]
            if limit>0:sql+=' LIMIT ?';args.append(limit)
            rows=[dict(row) for row in db.execute(sql,args).fetchall()][::-1]
        return {'messages':rows,'total':total,'returned':len(rows)}

    def close(self):
        for handle in self.handles.values():handle.close()
        self.handles.clear()
