"""Replacement function bodies. Imported only by the patch installer."""
MC_FORMATTER = '''async def get_mc_info(show_all_players: bool = False) -> Message:
    from src.services.community_query import query_mc
    try:
        data = await query_mc()
        msg = (
            f"🖥️ MC 服务器: {data['motd']}\\n"
            f"🎮 版本: {data['version']}\\n"
            f"📶 延迟: {data['latency_ms']} ms\\n"
            f"🫃 人数: {data['online_count']} / {data['max_players']}\\n"
        )
        return Message(msg + _format_player_list(data['players'], data['online_count'], show_all_players))
    except Exception as exc:
        return Message(f"⚠️ MC 查询失败: \\n{exc}")
'''

KOOK_FORMATTER = '''async def get_deep_kook_info(guild_id: str) -> Message:
    from src.services.community_query import query_kook
    try:
        data = await query_kook(guild_id=guild_id, token=KOOK_TOKEN)
        msg = Message(f"🎮 KOOK 服务器：{data['name']}\\n")
        user_icons = USER_ICON_CONFIG.get() or {}
        occupied = [channel for channel in data['channels'] if channel['users']]
        if not occupied:
            msg.append("Nobody here. 💔")
        for index, channel in enumerate(occupied):
            if index:
                msg.append("\\n")
            msg.append(f"🎙️ 【{channel['name']}】")
            for user in channel['users']:
                name = user['name']
                msg.append(f"\\n  └ {name} ")
                items = user_icons.get(name, ["🗣️"])
                for item in items:
                    msg.append(_build_icon(item))
        return msg
    except Exception:
        return Message("⚠️ KOOK 查询暂不可用")
'''
