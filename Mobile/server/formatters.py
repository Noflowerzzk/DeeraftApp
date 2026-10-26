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

CHAT_HTTP = '''async def get_chat_message(
    permission_code: str = Query(..., description="权限码"),
    num: int = Query(0, ge=0, description="返回最新的消息数量，0 代表全部"),
):
    if permission_code != PERMISSION_CODE:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="权限码错误")
    from app.services.chat_history_service import chat_history_service
    return ChatMessageResponse(**(await chat_history_service.history(num)))
'''

CHAT_WEBSOCKET = '''async def websocket_chat_messages(websocket: WebSocket, permission_code: Optional[str] = None):
    permission_code = permission_code or websocket.query_params.get("permission_code")
    if not permission_code or permission_code != PERMISSION_CODE:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="权限码错误")
        return
    from app.services.chat_history_service import chat_history_service
    await chat_history_service.serve(websocket)
'''
