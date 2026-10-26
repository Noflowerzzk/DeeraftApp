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

工具链位于 `.toolchain/`；Gradle、Pub、Android/AVD、Java、临时文件和 Flutter 配置位于 `.cache/`。脚本只修改当前进程的环境变量，不改系统 PATH。固定版本与下载校验值见 `scripts/toolchain.json`。

默认地址为 `http://mc.ainfinitythecoder.cn`。HTTP 例外仅对这个域名开放；其它站点使用 HTTPS。连接设置可修改地址，修改后需重新登录。当前登录和查询沿用网站的 HTTP 传输方式。

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
