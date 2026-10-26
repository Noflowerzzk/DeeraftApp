"""Daily presence from actual server events, shared by the website and App."""
import asyncio
from datetime import datetime, timedelta
import gzip
from pathlib import Path
import re
import time

HEADER = re.compile(r'^\[([^\]]+)\]\s+\[Server thread/INFO\](?:\s+\[[^\]]+\])?:\s*(.*)$')
LOGIN = re.compile(r'^([A-Za-z0-9_]{1,16})\[/[^\]]+\] logged in with entity id\b')
JOIN = re.compile(r'^([A-Za-z0-9_]{1,16}) joined the game$')
LEAVE = re.compile(r'^([A-Za-z0-9_]{1,16})(?: \([^\n]*\))? (?:left the game|lost connection:.*)$')
CLOCK = re.compile(r'^(\d{2}):(\d{2}):(\d{2})')
DATE = re.compile(r'^(\d{4}-\d{2}-\d{2})')
ANSI = re.compile(r'\x1b\[[0-9;]*m|§[0-9a-fk-or]', re.I)
_cache = {}


def events(path):
    """Resolve time-only Paper lines using archive date/mtime and midnight order."""
    archive_date = DATE.match(path.name)
    day = datetime.strptime(archive_date[1], '%Y-%m-%d').date() if archive_date else datetime.fromtimestamp(path.stat().st_mtime).date()
    opener = gzip.open if path.suffix == '.gz' else open
    with opener(path, 'rt', encoding='utf-8', errors='replace') as stream:
        lines = list(stream)
    resolved = []
    last_clock = None
    last_seen = None
    for raw in reversed(lines):
        match = HEADER.match(ANSI.sub('', raw.strip()))
        if not match:
            continue
        stamp, body = match.groups()
        try:
            if DATE.match(stamp):
                when = datetime.fromisoformat(stamp.replace(',', '.'))
            elif CLOCK.match(stamp):
                clock = datetime.strptime(stamp[:8], '%H:%M:%S').time()
                if last_clock is not None and clock > last_clock:
                    day -= timedelta(days=1)
                when = datetime.combine(day, clock)
                last_clock = clock
            else:
                legacy = re.match(r'(\d{2})(\d{2})月(\d{4})\s+(\d{2}:\d{2}:\d{2})', stamp)
                if not legacy:
                    continue
                dd, mm, yy, clock = legacy.groups()
                when = datetime.strptime(f'{yy}-{mm}-{dd} {clock}', '%Y-%m-%d %H:%M:%S')
        except ValueError:
            continue
        last_seen = max(last_seen, when) if last_seen else when
        login = LOGIN.match(body) or JOIN.fullmatch(body)
        leave = LEAVE.fullmatch(body)
        if login:
            resolved.append((when, 'join', login[1]))
        elif leave:
            resolved.append((when, 'leave', leave[1]))
        elif body.startswith(('Stopping server', 'Starting minecraft server version')):
            resolved.append((when, 'stop', ''))
        # System chat and player messages cannot masquerade as presence events.
    return resolved, last_seen


def read_daily(root, target, now=None, running_server=None):
    now = now or datetime.now()
    start = datetime.combine(target.date() if isinstance(target, datetime) else target, datetime.min.time())
    end = min(start + timedelta(days=1), now)
    if end <= start:
        return {}
    totals = {}
    for server in sorted(Path(root).iterdir()):
        if not server.is_dir():
            continue
        logs = (server / 'server' if (server / 'server').is_dir() else server) / 'logs'
        if not logs.is_dir():
            continue
        files = set()
        for day in (start.date(), (start - timedelta(days=1)).date()):
            files.update(logs.glob(f'{day.isoformat()}*.log*'))
        files.update(p for p in (logs/'latest.log', logs/'latest.log.1', logs/'latest.log.old') if p.is_file())
        all_events, last_seen = set(), None
        for path in sorted(files):
            parsed, seen = events(path)
            all_events.update(parsed)
            if seen:
                last_seen = max(last_seen, seen) if last_seen else seen
        cap = end if server.name == running_server else min(end, last_seen or start)
        online = {}
        def finish(player, when):
            joined = online.pop(player, None)
            if joined is not None:
                seconds = (min(when, end) - max(joined, start)).total_seconds()
                if seconds > 0:
                    totals[player] = totals.get(player, 0) + seconds
        for when, kind, player in sorted(all_events):
            if when > end:
                break
            if kind == 'join':
                online.setdefault(player, when)
            elif kind == 'leave':
                finish(player, when)
            else:
                for name in list(online):
                    finish(name, when)
        for player in list(online):
            finish(player, cap)
    return {player: round(seconds / 60, 2) for player, seconds in totals.items()}


async def community_daily_playtime(root, target, running_server=None):
    key = (str(root), target.date(), running_server)
    cached = _cache.get(key)
    if cached and time.monotonic() - cached[0] < 20:
        return dict(cached[1])
    result = await asyncio.to_thread(read_daily, root, target, running_server=running_server)
    _cache.clear()
    _cache[key] = (time.monotonic(), result)
    return dict(result)
