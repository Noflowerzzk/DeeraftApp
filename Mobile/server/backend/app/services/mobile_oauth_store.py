"""Process-safe, short-lived, single-use mobile OAuth transactions."""
import base64
import hashlib
import hmac
import os
import secrets
import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path


class OAuthStore:
    def __init__(self, path=None, clock=time.time):
        self.path = Path(path or os.environ.get('DEERAFT_OAUTH_DB',
                         str(Path(__file__).resolve().parents[2] / 'data' / 'mobile_oauth.sqlite3')))
        self.clock = clock

    @contextmanager
    def _connect(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.path, timeout=5, isolation_level=None)
        conn.execute('CREATE TABLE IF NOT EXISTS transactions '
                     '(state TEXT PRIMARY KEY, client_state TEXT, challenge TEXT, expires REAL, code TEXT UNIQUE, token TEXT)')
        conn.execute('DELETE FROM transactions WHERE expires < ?', (self.clock(),))
        os.chmod(self.path, 0o600)
        try:
            yield conn
        finally:
            conn.close()

    @staticmethod
    def digest(value):
        return hashlib.sha256(value.encode('ascii')).hexdigest()

    def start(self, challenge, client_state):
        state = 'mobile.' + secrets.token_urlsafe(32)
        with self._connect() as conn:
            conn.execute('INSERT INTO transactions VALUES (?,?,?,?,NULL,NULL)',
                         (self.digest(state), client_state, challenge, self.clock() + 300))
        return state

    def begin_callback(self, state):
        """Claim the pending transaction, rejecting concurrent/repeated callbacks."""
        with self._connect() as conn:
            conn.execute('BEGIN IMMEDIATE')
            row = conn.execute('SELECT client_state FROM transactions WHERE state=? AND code IS NULL AND token IS NULL AND expires>?',
                               (self.digest(state), self.clock())).fetchone()
            if row:
                conn.execute('UPDATE transactions SET token=? WHERE state=?', ('pending', self.digest(state)))
            conn.commit()
        return row[0] if row else None

    def complete(self, state, token):
        code = secrets.token_urlsafe(32)
        with self._connect() as conn:
            result = conn.execute('UPDATE transactions SET code=?,token=?,expires=? WHERE state=? AND token=? AND expires>?',
                                  (self.digest(code), token, self.clock()+60, self.digest(state), 'pending', self.clock()))
            if result.rowcount != 1:
                raise ValueError('Expired transaction')
        return code

    def exchange(self, code, verifier):
        challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode('ascii')).digest()).decode().rstrip('=')
        with self._connect() as conn:
            conn.execute('BEGIN IMMEDIATE')
            row = conn.execute('SELECT token,challenge FROM transactions WHERE code=? AND expires>?', (self.digest(code), self.clock())).fetchone()
            if not row or not hmac.compare_digest(row[1], challenge):
                conn.rollback()
                return None
            conn.execute('DELETE FROM transactions WHERE code=?', (self.digest(code),))
            conn.commit()
        return row[0]
