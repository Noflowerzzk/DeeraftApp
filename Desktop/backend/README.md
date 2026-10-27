# 启动动态后端适配

目标网站：`/home/ainfinity/backend/backend`。新增 `app/services/activity_store.py` 与 `app/controllers/activity_controller.py`，在现有移动端路由旁注册，不重写既有网站代码。

- POST `/api/v1/mobile/activity`：现有社区会话鉴权，服务端确定玩家身份；按用户及 event_id 去重。
- GET 同路径：按游标读取；初次返回最近 50 条。
- WebSocket `/api/v1/mobile/activity/ws`：初始快照与后续动态；支持 Bearer 请求头与原有 token 参数，未登录关闭为 1008。
- 动态包含实例显示名、版本、服务器时间，不包含游戏目录、启动参数、令牌及个人服务器地址。
- SQLite 文件在服务端 `backend/data/launcher_activity.sqlite3`，保留约两万条，不混入 Minecraft 聊天记录。

`validate_activity.py` 使用 ASGI 与临时数据库测试，不增加生产依赖。`install_activity.py` 保存现有 main.py 备份，只追加新路由。`restart_backend.py` 默认只检查；经用户同意后使用 `--apply` 重启精确匹配的进程，保留原环境且不将环境变量写入文件。启动失败时仅回滚新增路由。

2026-10-27：用户同意重启后已启用接口；公网未登录访问返回 401。真实用户授权在应用内完成，不在聊天中收集凭据。
