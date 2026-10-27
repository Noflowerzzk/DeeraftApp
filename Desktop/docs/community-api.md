# 桌面社区接口

`Desktop/app/community/CommunityClient.{h,cpp}` 是独立于 Minecraft 账号的社区客户端。固定连接现有 `http://mc.ainfinitythecoder.cn`，沿用手机端服务，不部署或修改远程服务。

## C++ / CMake 接入

```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Gui Network WebSockets)
target_sources(your_launcher_target PRIVATE
    ../app/community/CommunityClient.cpp
    ../app/community/CommunityClient.h)
target_link_libraries(your_launcher_target PRIVATE Qt6::Gui Qt6::Network Qt6::WebSockets)
if(WIN32)
    target_link_libraries(your_launcher_target PRIVATE crypt32)
endif()
```

保持 AUTOMOC 开启；构造 `CommunityClient(dataDirectory, parent)`，将其作为 QML context property `communityClient` 注册。`dataDirectory` 是程序便携数据目录；会话保存至其 `community/session.dat`。窗口加载后调用 `restoreSession()`。

Windows 使用当前用户 DPAPI 加密访问令牌、刷新令牌和缓存资料；不持久化密码。不提供明文回退。复制便携目录到不同 Windows 用户后需要重新登录。网络中断保留刷新凭据；服务明确返回 401 才清除会话。刷新并发合并、提前 60 秒刷新，并对 401 至多重放一次请求。退出或切换用户后，旧请求结果不会更新新用户状态。

## QML 绑定

所有属性以 `changed()` 通知，原始字段与现有 API 一致。属性不包含令牌或密码。

| 属性 | 类型 / 内容 |
| --- | --- |
| authenticated, busy, error | bool、bool、QString；busy 表示仍有 HTTP 请求 |
| profile | QVariantMap：id、username、role、bio、avatar_url |
| community | QVariantMap：mc、kook、sources、fetched_at；MC 中含 players、human_players、motd 等 |
| servers | QVariantList：网站服务器列表 |
| chat | QVariantList：最多 300 条，id/time/player/message/type |
| playtime | QVariantList：已按 playtime_minutes 降序排序；界面显示前 5，合计应使用完整列表 |
| daily, dailyDate | QVariantList、YYYY-MM-DD；日期查询结果不会覆盖后选日期 |
| hostedStatus | QVariantMap：is_running、server_name、system_stats，WebSocket 更新 |
| liveRooms | QVariantList：id、roomId、embedUrl、name |
| users | QVariantList：管理员查询的用户列表 |
| logLines | QVariantList：日志文本行，最多 2000 行 |
| backups | QVariantList：name、timestamp、description |
| rconConfig | QVariantMap：enabled、mcdr_console_available 等 |
| commandResult | QString：最后一次 RCON 返回文本 |
| uploading, uploadProgress | bool、double [0,1]；进度满值不代表解压完成，需 uploading=false 且 operationFinished(upload) |
| connectionStatus | QString：聊天连接状态；无需在主界面占位显示 |

`operationFinished(operation,result)` 提供可观察成功结果；`operationFailed(operation,message)` 提供失败。错误同时写入 `error`；`clearError()` 清除。HTTP 失败的 operation 为实际 API path；显式本地验证使用 login/profile/upload 等名称。`liveStatusReceived(roomId,status)` 返回直播状态。

## 可调用操作

- `login(username,password)`、`registerAccount(username,password)`、`logout()`、`restoreSession()`、`refresh()`。
- `updateProfile(username,bio)`：修改用户名时接受服务重签的访问令牌，重连实时流，然后保存简介。`uploadAvatar(fileUrl)` 上传 ≤5MB 图片。`imageUrl(path)` 将后端相对图片地址解析为可用 URL。
- `loadDaily("2026-10-27")`。
- `serverAction(action,name,args)`：下表中的网站原有操作；普通用户如需权限码，由用户输入 `args.permission_code`，应用不内置权限码。服务仍决定权限，不把 UI 的角色判断当作授权。
- `loadBackups(name)`、`uploadCover(name,fileUrl)`。
- `loadUsers(search)`、`setUserRole(userId,"admin"|"user")`。
- `loadLiveRooms()`、`saveLiveRooms(rooms)`、`loadLiveStatus(roomId)`。
- `watchLogs(name)` 开启指定服务器日志并读取控制台能力；`watchLogs("")` 关闭日志。`loadLogs(name,lines)` 手动读取；`loadRconConfig(name)` 刷新能力。`sendCommand(name,command,mcdr=false)` 分别调用管理员 RCON/MCDR 接口。
- `uploadServer(fileUrl,metadata,chunked=true)`：metadata 包含 name、version、launch_command，以及可选 motd、img、permission_code。默认顺序上传 8MB 分片，最后调用 complete；可选择网站的完整 ZIP 上传。`cancelUpload()` 中止当前请求并阻止后续分片，服务器现有协议没有上传清理接口，因此不会声称远端临时片已删除。分片会话丢失或文件被修改时明确失败。

| action | args |
| --- | --- |
| start | 可选 permission_code；name 独立参数 |
| stop | 可选 permission_code；停止当前服务器 |
| update | motd、img、可选 permission_code |
| backup | backup_name、可选 description |
| backups | 无；结果写入 backups |
| restore | backup_name |
| delete | 可选 permission_code；UI 必须先显示确认 |

`serverAction` 的恢复、删除操作沿用原站行为，调用方必须在用户确认后调用。

## 实时消息

登录后连接手机端聊天 WS 和服务器状态 WS；管理员进入控制台后增加对应日志 WS。每 20 秒发送 ping，断开指数重试，最长 30 秒；社区 MC/KOOK 每 30 秒刷新。HTTP 初始聊天快照不会覆盖更新的 WS 数据；聊天按 id 或尾部重叠去重，保留内容相同但实际重复发送的独立消息。日志兼容后端的字符串 payload。

## 社区微软登录

`startMicrosoftLogin()` 复用手机端 PKCE 接口并打开系统浏览器；`microsoftAuthorizationStarted(url)` 同时通知 UI。该流程与 Prism 的 Minecraft 正版登录无关。

后端当前固定跳转 `deeraft://oauth/callback`，因此主程序需提供协议注册及把回调转交运行中进程的机制，然后调用 `completeMicrosoftLogin(callbackUrl)`；回调必须与 5 分钟内的 pending state 匹配。此模块不修改系统注册表，也不会把社区 JWT 当作 Minecraft token。若尚未完成协议路由，界面应暂不暴露该入口，不能用复制粘贴官方游戏账号令牌替代。

## 验证与限制

- 使用本地 UCRT64 GCC 对 `.cpp` 完成 C++20 语法检查。
- API 方法、字段、权限及 WS payload 已对照本地手机代码和 SSH 上的现有后端源码；未调用启动、停止、删除、上传等会变更真实服务器的接口。
- 尚需主程序构建链接、真实用户登录、DPAPI 重启恢复及 UI 流程验收。微软社区 OAuth 依赖既有服务端配置；直播播放由主程序的 WebView2 组件实现，客户端仅管理列表和状态。
- 目前上传不支持跨应用重启断点续传，网站也未提供查询分片会话的持久接口。失败或取消可重新开始，不展示伪成功。
