# Deeraft

Flutter Android 客户端。复用网站账号，提供服务器状态、在线玩家、KOOK 语音成员、只读 MC 聊天、个人资料和游玩时长。

## 运行与构建

在项目目录打开 PowerShell：

```powershell
./scripts/setup.ps1                 # 首次安装工具链
./scripts/flutter.ps1 run -d <设备ID>
./scripts/build.ps1                 # 检查、测试并构建测试 APK
```

APK 输出至 `dist/Deeraft-test.apk`，使用本地测试签名。登录页的“演示模式”不请求服务器，所有演示页面均标明演示数据。

v0.4.0 已整体改为 Material 3：系统深浅色、标准顶栏和底部导航、分段筛选、服务器详情和资料编辑面板，并统一切页、列表展开和数字更新动效。设计依据见 [Material 设计说明](docs/Material设计说明.md)，当前演示截图位于 `docs/screenshots/v0.4.0/`，视频为 `dist/Deeraft-material-motion.mp4`。v0.3.x 截图和视频保留为历史版本。

工具链位于 `.toolchain/`；Gradle、Pub、Android/AVD、Java、临时文件和 Flutter 配置位于 `.cache/`。脚本只修改当前进程的环境变量，不改系统 PATH。固定版本与下载校验值见 `scripts/toolchain.json`。

固定连接 `http://mc.ainfinitythecoder.cn`，不提供连接设置。当前登录和查询沿用网站的 HTTP 传输方式。

App 安全存储登录会话，自动续期 24 小时访问 Token；刷新会话闲置 90 天失效，正常使用会自动延长，最长持续 1 年。退出登录撤销对应会话。短暂断网不会清空登录状态。旧版未过期的登录可自动迁移，已经失效的旧登录需重新登录一次。

可选模拟器：

```powershell
./scripts/setup.ps1 -WithEmulator
./scripts/start-emulator.ps1
./scripts/flutter.ps1 run -d emulator-5554
```

## 后端

`server/` 包含兼容现有网站和 QQ 命令的扩展、安装/回滚脚本及测试。查看 [部署说明](docs/部署说明.md) 和 [API 文档](docs/API接口文档.md)。安装前校验基线，备份现有文件，不重置远程 Git 工作区。

Microsoft 移动端登录流程已实现，但当前服务器未配置 Microsoft OAuth 客户端，不能完成真实微软登录。账号密码登录可用。App 不包含机器人凭据或共享权限码。

首版没有服务器管理操作、双向聊天或后台推送。App 在前台更新，进入后台断开连接，恢复时重新获取数据。

## 检查

```powershell
./scripts/flutter.ps1 analyze
./scripts/flutter.ps1 test
. ./scripts/env.ps1
./.toolchain/python/Scripts/python.exe -m unittest discover -s server/tests -v
```

Python 测试依赖可安装在 `.toolchain/python` 的 venv 中：`httpx mcstatus fastapi sqlalchemy python-jose`。

设计数据见 [UI设计依据](docs/UI设计依据.md)，测试记录见 [验证记录](docs/验证记录.md)。源码使用本地 Git 管理；工具链、缓存、密钥、临时测试资料和 APK 不提交。
