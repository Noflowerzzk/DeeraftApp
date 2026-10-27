# DeeraftApp 桌面程序

Qt Quick/QML + C++ 正式程序，复用 Prism 11.1.1 的实例、版本、账号和启动核心。界面以已确认的 `../design/m3-expressive/` 设计稿为准，真实程序不会读取设计稿的演示数据。

- `qml/`：导航、实例列表详情、社区、服务器、聊天、个人资料、设置及共享组件。
- `DesktopBridge.*`：Prism 实例、账号、任务、资源与二级窗口适配。
- `library/`：个人收藏/分组、稳定实例关联、第三方服务器配置与 Minecraft SLP 状态查询。
- `community/`：网站接口、会话续期、WebSocket、上传、管理和启动动态。
- `compat/`：PCL/HMCL 原目录解析及原生启动。
- `accounts/`：Authlib-injector / Yggdrasil Connect。
- `download/`：按资源类型选择国内源与官方回退。
- `webview/`：独立直播窗口，缓存保存在便携数据目录。

个人配置位于程序旁 `data/`；开发验证通过 `--dir` 使用工作区内独立目录。关联 PCL/HMCL 目录不转换格式；移除关联不删除游戏文件。Prism 主界面不提供切换入口，只复用相关二级窗口。
