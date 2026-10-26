DAILY_ROUTE = '''async def get_daily_playtime(
    permission_code: str = Query(..., description="权限码"),
    date: str = Query(None, description="日期（YYYY-MM-DD），默认为今天"),
    db: Session = Depends(get_db)
):
    if permission_code != PERMISSION_CODE:
        raise HTTPException(status_code=403, detail="权限码错误")
    try:
        target = datetime.strptime(date, "%Y-%m-%d") if date else datetime.now()
    except ValueError:
        raise HTTPException(status_code=400, detail="日期格式错误，请使用 YYYY-MM-DD 格式")
    # DEERAFT_DAILY_PLAYTIME: one aggregate for the website and mobile adapter.
    from app.services.daily_playtime_reader import community_daily_playtime
    cached = player_playtime_service.get_playtime(db, target.date())
    try:
        observed = await community_daily_playtime(
            server_service.servers_path, target, server_service.get_running_server())
        for player, minutes in observed.items():
            cached[player] = minutes
            player_playtime_service.save_playtime(db, player, target.date(), minutes)
    except Exception:
        import logging
        logging.getLogger(__name__).exception("Daily presence log scan failed; retaining stored totals")
    players = [PlayerPlaytime(player=player, playtime_minutes=minutes)
               for player, minutes in sorted(cached.items(), key=lambda item: (-item[1], item[0]))]
    return DailyPlaytimeResponse(date=target.strftime("%Y-%m-%d"), players=players, total_players=len(players))
'''
