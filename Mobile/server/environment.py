"""Load only Deeraft settings from an optional owner-only environment file."""
import os
from pathlib import Path
import shlex

def load_environment():
    path = Path(os.environ.get('DEERAFT_ENV_FILE', str(Path.home()/'.config/deeraft-app/environment')))
    if not path.exists():
        return
    if path.stat().st_mode & 0o077:
        raise RuntimeError('Deeraft environment file must be owner-only (chmod 600)')
    allowed = {'DEERAFT_INTERNAL_TOKEN', 'DEERAFT_KOOK_TOKEN', 'DEERAFT_KOOK_GUILD_ID',
               'DEERAFT_BOT_ORIGIN', 'DEERAFT_MC_HOST', 'DEERAFT_MC_QUERY_PORT',
               'DEERAFT_MC_STATUS_ADDRESS', 'DEERAFT_OAUTH_DB'}
    for line in path.read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.lstrip().startswith('#') or '=' not in line:
            continue
        key, raw = line.split('=', 1)
        key = key.strip()
        if key in allowed:
            values = shlex.split(raw, comments=True)
            if len(values) == 1:
                os.environ.setdefault(key, values[0])
