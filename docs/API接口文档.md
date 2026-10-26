# 后端 API 接口文档

> **来源**: 服务器 `AInfinity`（ainfinity@111.231.28.197:2222）`/home/ainfinity/backend`
> **框架**: FastAPI + SQLAlchemy（SQLite），MVC 架构
> **默认前缀**: `/api/v1`
> **文档生成时间**: 2026-10-26
>
> ⚠️ **维护约定**: 本文档基于后端代码与服务器上已有文档整理。以后若 `/home/ainfinity/backend` 代码有变更（新增/修改/删除路由、参数、权限），需同步更新本文档。更新时建议核对 `backend/app/controllers/*.py` 中的路由注册。

---

## 0. 基础信息

| 项目 | 说明 |
|---|---|
| 服务框架 | FastAPI |
| 在线文档 | Swagger UI: `/docs`；ReDoc: `/redoc` |
| OpenAPI JSON | `GET /api/v1/openapi.json`、`GET /api/openapi.json` |
| 健康检查 | `GET /health` |
| 请求体限制 | 默认 10MB（上传服务器整包 1GB、分片 12MB、头像/封面 5MB） |

### 权限模型

- 角色：`user`（普通用户）、`admin`（管理员）
- 鉴权：大部分非公开接口需要请求头 `Authorization: Bearer <access_token>`
- 权限码：`permission_code`，代码中当前固定值为 `ZZKZZKZZK`；非管理员执行服务器操作（启动/停止/删除/上传等）时通常需要携带

---

## 1. 通用

| 方法 | 路径 | 说明 | 鉴权 |
|---|---|---|---|
| GET | `/` | 欢迎信息 | 无 |
| GET | `/health` | 健康检查 | 无 |

---

## 2. 认证模块 `/api/v1/auth`

| 方法 | 路径 | 说明 | 鉴权 |
|---|---|---|---|
| GET | `/api/v1/auth/login-background/{filename}` | 获取登录/注册背景图（公开，防路径穿越） | 无 |
| GET | `/api/v1/auth/avatars/{filename}` | 获取用户头像文件（公开） | 无 |
| POST | `/api/v1/auth/register` | 注册本地账号；Body: `{ "username": string, "password": string }` | 无 |
| POST | `/api/v1/auth/login` | 本地账号登录，返回 JWT token；Body: `{ "username": string, "password": string }` | 无 |
| GET | `/api/v1/auth/verify-token` | 验证 token 有效性 | JWT |
| GET | `/api/v1/auth/me` | 获取当前用户完整资料 | JWT |
| PUT | `/api/v1/auth/me/username` | 修改用户名（唯一性校验，返回新 token） | JWT |
| PUT | `/api/v1/auth/me/bio` | 修改座右铭（≤280 字符） | JWT |
| POST | `/api/v1/auth/me/avatar` | 上传头像（jpg/png/webp/gif，≤5MB） | JWT |
| GET | `/api/v1/auth/users` | 用户列表（支持模糊搜索 `?q=`） | 管理员 |
| PATCH | `/api/v1/auth/users/{user_id}/role` | 修改用户角色 `{ "role": "admin" \| "user" }` | 管理员 |
| GET | `/api/v1/auth/microsoft/login` | 获取 Microsoft OAuth 授权地址 | 无 |
| GET | `/api/v1/auth/microsoft/callback` | Microsoft OAuth 回调（微软→Xbox→Minecraft 登录，成功 302 跳转前端并带 token） | 无 |

---

## 3. 服务器模块 `/api/v1/servers`

| 方法 | 路径 | 说明 | 鉴权 |
|---|---|---|---|
| GET | `/api/v1/servers` | 服务器列表（返回 `ServerInfo[]`：名称、版本、MotD、封面等） | 无 |
| GET | `/api/v1/servers/{server_name}` | 单个服务器信息 | 无 |
| GET | `/api/v1/servers/status` | 运行状态（**已废弃**，建议改用 WS `/status/ws`） | 无 |
| GET | `/api/v1/servers/running` | 当前运行中的服务器信息；Query: `permission_code`（必填） | JWT |
| POST | `/api/v1/servers/start` | 启动服务器；Body: `{ "name": string, "permission_code": string? }` | JWT（非 admin 需权限码） |
| POST | `/api/v1/servers/kill` | 停止当前运行服务器；Body: `{ "permission_code": string? }` | JWT（非 admin 需权限码） |
| POST | `/api/v1/servers/upload` | 整包上传 ZIP 创建服务器（multipart，≤1GB，含启动命令等字段） | JWT（非 admin 需权限码） |
| POST | `/api/v1/servers/upload/init` | 初始化分片上传（multipart：`name/version/motd/img/launch_command/total_size/total_chunks/permission_code`） | JWT（非 admin 需权限码） |
| POST | `/api/v1/servers/upload/chunk` | 上传单个分片（multipart：`upload_id/chunk_index/chunk`，≤12MB） | JWT |
| POST | `/api/v1/servers/upload/complete` | 合并分片并完成创建（multipart：`upload_id/...`） | JWT |
| PUT | `/api/v1/servers/{server_name}` | 更新服务器 MotD/封面（Body: `{ "motd": string, "img": string, "permission_code": string? }`） | JWT（非 admin 需权限码） |
| POST | `/api/v1/servers/{server_name}/upload_image` | 上传服务器封面图（≤5MB） | JWT |
| GET | `/api/v1/servers/{server_name}/cover` | 获取服务器封面图 | 无 |
| DELETE | `/api/v1/servers/{server_name}` | 删除服务器 | JWT（非 admin 需权限码） |
| POST | `/api/v1/servers/{server_name}/backup` | 创建备份；Body: `{ "backup_name": string, "description"?: string }` | JWT（临时密码） |
| GET | `/api/v1/servers/{server_name}/backups` | 备份列表（`BackupListResponse`） | JWT |
| POST | `/api/v1/servers/{server_name}/restore` | 从备份恢复；Body: `{ "backup_name": string }` | JWT（临时密码） |
| GET | `/api/v1/servers/player/me/playtime` | 当前登录用户在各服务器的**累计游玩时长**（读取世界存档 `stats/<uuid>.json` 的 `minecraft:play_time`/`minecraft:play_one_minute`，离线/正版 UUID 都查，取较大值；tick/20=秒） | JWT |

## 4. 日志 / 聊天 / 玩家模块 `/api/v1/servers`

| 方法 | 路径 | 说明 | 鉴权 |
|---|---|---|---|
| GET | `/api/v1/servers/chat` | 获取聊天消息（旧接口）；Query: `permission_code`（必填）、`num`（可选，默认 0=全部） | 无（需权限码） |
| GET | `/api/v1/servers/online_players` | 在线玩家列表（旧接口）；Query: `permission_code`（必填） → `OnlinePlayersResponse { players: string[], count }` | 无（需权限码） |
| GET | `/api/v1/servers/player/avatar` | 获取玩家头像 URL（Mojang + Minotar）；Query: `username`（必填）、`size`（默认 128） | 无 |
| GET | `/api/v1/servers/{server_name}/logs` | 拉取日志（增量）；Query: `lines`（默认 100）、`last_line`（可选，只返回新日志） | 管理员 |
| GET | `/api/v1/servers/{server_name}/logs/stream` | 流式日志（HTTP chunked streaming） | 管理员 |
| GET | `/api/v1/servers/daily_playtime` | **每日每个玩家的在线时长统计**；Query: `permission_code`（必填）、`date`（可选，`YYYY-MM-DD`，默认今天），返回 `{ date, players: [{ player, playtime_minutes }], total_players }`；优先从数据库读取，今天的数据会从服务器日志重新计算并写回数据库 | 无（需权限码） |

---

## 5. RCON / MCDR `/api/v1/servers`

| 方法 | 路径 | 说明 | 鉴权 |
|---|---|---|---|
| GET | `/api/v1/servers/{server_name}/rcon/config` | 获取 RCON/MCDR 可用配置 | 管理员 |
| POST | `/api/v1/servers/{server_name}/rcon/command` | 执行 RCON 命令；Body: `{ "command": "list" }` | 管理员 |
| POST | `/api/v1/servers/{server_name}/mcdr/console` | 向 MCDR 控制台写入一行；Body: `{ "line": "!!help" }` | 管理员 |

---

## 6. WebSocket `/api/v1/servers`

| 方法 | 路径 | 说明 | 鉴权 |
|---|---|---|---|
| WS | `/api/v1/servers/status/ws?token=<jwt>` | 实时推送服务器运行状态 + 系统监控（CPU/内存/磁盘） | JWT（query token） |
| WS | `/api/v1/servers/{server_name}/logs/ws?token=<jwt>` | 实时推送服务器日志 | 管理员（query token） |
| WS | `/api/v1/servers/chat/ws?permission_code=ZZKZZKZZK` | 实时推送聊天消息 | 权限码（query） |
| WS | `/api/v1/servers/online_players/ws?token=<jwt>` | 实时推送在线玩家列表 | JWT（query token） |

---

## 7. 主要数据模型

- `UserResponse`: `id`, `username`, `role`, `avatar_url`
- `UserProfile`: `id`, `username`, `role`, `bio`, `avatar_url`
- `Token`: `access_token`, `token_type`
- `ServerInfo`: `name`, `img`, `version`, `motd`
- `ServerStatusResponse`: `is_running`, `server_name`, `system_stats`
- `ServerStartResponse`: `message`, `server_name`, `launch_mode`（mcdr / vanilla）, `working_directory`, `exec_summary`, `systemd_message`
- `RconConfigResponse`: `enabled`, `port`, `message`, `mcdr_console_available`, `mcdr_console_message`, `is_mcdr_layout`
- `ChatMessage`: `time`(HH:MM:SS), `player`, `message`, `type`(chat | join | leave)
- `OnlinePlayersResponse`: `players[]`, `count`
- `DailyPlaytimeResponse`: `date`, `players[]`（`{ player, playtime_minutes }`, 按时长降序）, `total_players`
- 数据库表：`users`、`servers`、`player_playtime`（`player_name + date` 唯一，记录每日分钟数）

---

## 8. 常见状态码

| 状态码 | 含义 |
|---|---|
| 200 | 成功 |
| 201 | 创建成功（如注册） |
| 302 | OAuth 回调重定向 |
| 400 | 请求参数错误 |
| 401 | 未认证 / token 无效 |
| 403 | 权限不足或权限码错误 |
| 404 | 资源不存在 |
| 413 | 请求体过大 |
| 502 | 上游代理调用失败（如 B 站接口） |
| 503 | 外部服务不可用 / 配置缺失 |

---

## 9. 玩家在线时长（重点说明）

### 两种统计口径

1. **累计游玩时长**（存档统计）
   - 接口：`GET /api/v1/servers/player/me/playtime`（JWT）
   - 数据来源：扫描服务器运行目录下 `<world>/stats/<uuid>.json`（1.13+ 原版统计）
   - 指标：`minecraft:custom/minecraft:play_time`（或 `play_one_minute`），单位 tick（20 tick/s）
   - 特点：只统计玩家参与过的世界；查看的是当前玩家，按其用户名匹配离线/正版 UUID

2. **每日在线时长**（日志统计）
   - 接口：`GET /api/v1/servers/daily_playtime`（需权限码）
   - 数据来源：服务器日志（join/leave 事件），由 `player_stats_service` 解析
   - 持久化：解析结果写入 `player_playtime` 表（SQLite `app.db`），按玩家 + 日期存储分钟数
   - 特点：查询今天的数据时会实时重算（因为玩家可能还在线）；历史日期优先读库
   - 注意：依赖日志中存在玩家上线/下线记录；服务器异常崩溃可能导致当天统计偏小

### 前端配套

- 个人主页（`Profile.vue`）有“游玩时长统计”卡片：展示各服务器游玩时长列表、总时长统计，调用的即为上述接口。

---

## 10. Android App 扩展（2026-10-26）

以下接口已兼容性加入现有后端，保留原网站接口与 QQ 群命令。

| 方法 | 路径 | 说明 | 鉴权 |
|---|---|---|---|
| GET | `/api/v1/community/status` | Deeraft 主 MC 与 KOOK 聚合状态，15 秒缓存并合并并发刷新 | JWT |
| GET | `/api/v1/mobile/chat?num=100` | 托管服务器聊天快照，`num` 为 1–300 | JWT |
| WS | `/api/v1/mobile/chat/ws?token=<jwt>` | 复用网站聊天历史与增量广播 | JWT |
| GET | `/api/v1/mobile/daily-playtime?date=YYYY-MM-DD` | 复用每日在线统计；不传共享权限码 | JWT |
| POST | `/api/v1/mobile/auth/microsoft/start` | Body：`code_challenge`（S256，43 字符）、`client_state`；返回 `authorize_url` | 无 |
| POST | `/api/v1/mobile/auth/microsoft/exchange` | Body：`code`、`code_verifier`；单次交换为 JWT | 一次性交换码 + PKCE |
| POST | `/api/v1/mobile/auth/login` | Body：`username`、`password`；返回访问 Token 和刷新凭据 | 账号密码 |
| POST | `/api/v1/mobile/auth/session` | 将旧版仍有效的登录升级为持久会话 | JWT |
| POST | `/api/v1/mobile/auth/refresh` | Body：`refresh_token`；返回新访问 Token | 刷新凭据 |
| POST | `/api/v1/mobile/auth/logout` | Body：`refresh_token`；撤销该持久会话 | 刷新凭据 |

聚合响应的 `mc` 与 `kook` 允许独立为 `null`，必须结合 `sources` 判断状态；查询失败不表示服务器离线或频道无人。

```json
{
  "fetched_at": "2026-10-26T07:48:12+00:00",
  "mc": {
    "online": true,
    "motd": "Deeraft",
    "version": "Java 1.21.4",
    "latency_ms": 32,
    "online_count": 2,
    "max_players": 100,
    "players": ["PlayerA", "Camera01"],
    "human_players": ["PlayerA"]
  },
  "kook": {
    "name": "Deeraft",
    "channels": [{"id": "example", "name": "语音", "users": [{"id": "example-user", "name": "PlayerA"}]}]
  },
  "sources": {
    "mc": {"available": true, "updated_at": "2026-10-26T07:48:12+00:00", "error": null},
    "kook": {"available": true, "updated_at": "2026-10-26T07:48:12+00:00", "error": null}
  }
}
```

机器人新增内部 `GET /internal/deeraft/status`，仅接受本机调用并校验 `X-Deeraft-Internal`。该接口及服务凭据不提供给手机。真人名单沿用机器人已有 JSON 数据，不是入服白名单。

移动端微软授权复用原回调 URI，以 `mobile.` state 分流。回到 App 的地址为 `deeraft://oauth/callback?code=<one_time_code>&state=<client_state>`；授权失败带 `error`。交换码 60 秒有效，客户端登录事务 5 分钟有效；网页登录流程不变。当前服务器缺少 Microsoft OAuth 配置，真实微软登录尚不可用。

### 持久登录（v0.2.0）

移动端账号密码登录和微软交换成功后返回 `{access_token, refresh_token, token_type}`。刷新成功返回 `{access_token, token_type}`；刷新凭据保持不变，以允许并发请求及网络失败后的重试。客户端在安全存储中保存会话，不保存密码。

访问 Token 有效期 24 小时，App 提前续期，遇到 401 也会续期并重试一次；同一时间只发起一次续期请求。刷新凭据使用随机不透明字符串，服务器只保存 SHA-256 摘要和用户 ID。闲置 90 天失效；续期延长闲置期限，绝对上限为首次登录后 1 年。每次签发访问 Token 都重新读取用户的当前名称与角色。删除账号或主动退出后无法再续期。

服务重启不清空会话。会话数据库为 `backend/data/mobile_sessions.sqlite3`，权限 0600。网页登录有效期及接口行为保持原样。

### 聊天记录后台维护（2026-10-26）

网页 `/api/v1/servers/chat` 与 `/api/v1/servers/chat/ws`、App `/api/v1/mobile/chat` 与 `/api/v1/mobile/chat/ws` 统一使用持久聊天记录。权限检查、核心消息字段、`initial_chat_messages` / `new_chat_messages` 推送类型保持兼容。

后端启动时启动独立采集任务，每秒增量读取日志，每 5 秒检查运行实例切换。首次接入扫描当前日志；后续按字节读取位置继续，普通日志不写入消息表。请求只查询数据库，不再扫描原始日志；没有聊天页面连接时仍持续采集。

数据库为 `backend/data/chat_history.sqlite3`，权限 0600，启用 WAL。消息和读取位置在同一事务中提交；重启继续上次位置，支持日志轮转、截断、半行 UTF-8 和重复文本消息。当前实例停止时仍可查看其历史记录，切换实例后推送新实例的历史快照，各实例记录分开保存。不自动删除既有聊天记录。

WebSocket 可附带 `id` 和 `server_name`，已有客户端可忽略。历史 HTTP 响应继续使用 `{messages,total,returned}`；`num=0` 保持返回全部记录的旧语义。历史默认 WebSocket 快照为最近 100 条。
