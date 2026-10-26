# Deeraft

同一 Git 仓库内分开管理手机端与电脑端。

```text
Mobile/             现有 Flutter Android 项目及相关文件
  android/          Android 工程
  lib/              App 源码
  server/           网站/机器人配套扩展及部署脚本
  scripts/          工具链、运行与构建脚本
  docs/             设计、接口、部署与验证记录
  dist/             测试安装包（本地，不提交）
  .toolchain/       本地工具链（不提交）
  .cache/           本地缓存（不提交）
Desktop/            电脑端项目目录（已预留）
  app/              电脑端 App
  launcher/         启动器
```

手机端说明见 [Mobile/README.md](Mobile/README.md)。电脑端目录说明见 [Desktop/README.md](Desktop/README.md)。现有后端配套文件暂随手机端一并保留，避免本次整理混入功能拆分。

在仓库根目录运行：

```powershell
./Mobile/scripts/flutter.ps1 analyze
./Mobile/scripts/build.ps1
```

也可以先进入 `Mobile`，继续使用原有命令。所有新工具链和缓存仍放在本工作目录内，不修改系统 PATH；目前工具链与缓存位于 `Mobile/.toolchain`、`Mobile/.cache`。Git 仓库保留在根目录，统一管理两个项目。
