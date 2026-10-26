"""Structured queries shared by QQ formatting and the mobile gateway.

No NoneBot imports: this module can be tested without registering matchers.
"""
import asyncio
import json
import os
from pathlib import Path
from datetime import datetime, timezone

import httpx
from mcstatus import JavaServer

DATA = Path(__file__).resolve().parents[2] / 'data'


def now():
    return datetime.now(timezone.utc).isoformat()


def human_ids():
    # Do not create or reset the bot's existing data on a read request.
    with (DATA / 'mc_human_players.json').open(encoding='utf-8') as handle:
        value = json.load(handle)
    if not isinstance(value, list):
        raise ValueError('真人名单格式无效')
    return {str(name).strip().casefold() for name in value if str(name).strip()}


async def query_mc():
    host = os.environ.get('DEERAFT_MC_HOST', 'mc.ainfinitythecoder.cn')
    query_port = int(os.environ.get('DEERAFT_MC_QUERY_PORT', '25555'))
    status_address = os.environ.get('DEERAFT_MC_STATUS_ADDRESS', host)
    # DNS / TCP / UDP operations stay off the event loop; use bounded socket timeouts.
    def blocking():
        query = JavaServer(host, query_port, timeout=3).query()
        status = JavaServer.lookup(status_address, timeout=3).status()
        players = sorted(query.players.list or [], key=str.casefold)
        humans = human_ids()
        return {'online': True, 'motd': status.motd.to_plain(), 'version': status.version.name,
                'latency_ms': round(status.latency), 'online_count': query.players.online,
                'max_players': query.players.max, 'players': players,
                'human_players': [name for name in players if name.casefold() in humans]}
    return await asyncio.to_thread(blocking)


async def query_kook(guild_id=None, token=None):
    token = token or os.environ.get('DEERAFT_KOOK_TOKEN')
    guild = guild_id or os.environ.get('DEERAFT_KOOK_GUILD_ID')
    if not token or not guild:
        raise ValueError('尚未配置社区 KOOK 查询')
    async with httpx.AsyncClient(timeout=3, headers={'Authorization': f'Bot {token}'}) as client:
        async def request(path, **params):
            response = await client.get(f'https://www.kookapp.cn/api/v3/{path}', params=params)
            response.raise_for_status()
            body = response.json()
            if body.get('code') != 0:
                raise ValueError('KOOK 查询暂不可用')
            return body.get('data')
        info, channels = await asyncio.gather(request('guild/view', guild_id=guild),
                                             request('channel/list', guild_id=guild))
        voices = [channel for channel in channels.get('items', []) if channel['type'] == 2]
        semaphore = asyncio.Semaphore(4)
        async def members(channel):
            async with semaphore:
                users = await request('channel/user-list', channel_id=channel['id'])
                return {'id': str(channel['id']), 'name': channel['name'],
                        'users': [{'id': str(user['id']), 'name': user.get('nickname') or user.get('username') or '?'}
                                  for user in (users or [])]}
        return {'name': info['name'], 'channels': await asyncio.gather(*(members(c) for c in voices))}


async def collect_status(mc_query=query_mc, kook_query=query_kook):
    async def one(name, query):
        try:
            data = await asyncio.wait_for(query(), timeout=10)
            return name, data, {'available': True, 'updated_at': now(), 'error': None}
        except Exception:
            # Do not expose upstream exception text, addresses or credentials.
            return name, None, {'available': False, 'updated_at': now(),
                                'error': 'MC 查询暂不可用' if name == 'mc' else 'KOOK 查询暂不可用'}
    results = await asyncio.gather(one('mc', mc_query), one('kook', kook_query))
    response = {'fetched_at': now(), 'sources': {}}
    for name, data, source in results:
        response[name] = data
        response['sources'][name] = source
    return response


class StatusCache:
    def __init__(self, loader=collect_status, ttl=15, clock=None):
        import time
        self.loader, self.ttl, self.clock = loader, ttl, clock or time.monotonic
        self.value, self.expires = None, 0
        self.lock = asyncio.Lock()

    async def get(self):
        if self.value is not None and self.clock() < self.expires:
            return self.value
        async with self.lock:
            if self.value is None or self.clock() >= self.expires:
                self.value = await self.loader()
                self.expires = self.clock() + self.ttl
            return self.value
