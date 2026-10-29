# Windows 安装包与更新发布

应用版本 0.6.0，Prism 基线 11.1.1。工具链与 NSIS 均安装在 `Desktop/.toolchain/`，不修改系统 PATH。

发布顺序（从仓库根目录运行）：

```powershell
./Desktop/scripts/package.ps1
./Desktop/scripts/build-installer.ps1 -PackageDirectory 'Desktop/dist/本次便携目录'
./Desktop/scripts/verify-installer.ps1 -Installer 'Desktop/dist/DeeraftApp-0.6.0-windows-x64-setup.exe' -PackageDirectory 'Desktop/dist/本次便携目录'
python Desktop/scripts/sign-release.py Desktop/dist/DeeraftApp-0.6.0-windows-x64-setup.exe
python Desktop/scripts/deploy-release.py Desktop/dist/DeeraftApp-0.6.0-windows-x64-setup.exe
./Desktop/scripts/verify-updates.ps1 -Executable 'Desktop/dist/本次便携目录/DeeraftApp.exe' -Packaged
```

后续版本应同时修改 `AppUpdater::version()`、安装包版本参数与签名脚本版本参数。部署拒绝用不同字节覆盖已经发布的同版本安装包。

发布私钥保存在 **`Desktop/.secrets/release-signing/private.pem`**，已被 Git 忽略；请独立备份、后续沿用，不能随意更换。私钥不进入安装包、ZIP、网站或 Git。客户端只内置公钥，校验 Ed25519 签名，再根据签名内容校验安装包大小与 SHA-256。仓库中的 `latest.json` 是公开签名信封。

上传先进入前端目录之外的暂存区，上传后校验摘要，再原子替换公开文件。文件位于既有网站 `frontend/public/downloads/`，不新增动态 API、轮询服务或数据库工作。原始网站 Header 修改前备份；仅增加“下载 App”入口，不重启后端。

客户端启动 15 秒后考虑自动检查，并以本地计时器检查 24 小时期限。自动检查可关闭；手动检查始终可用。安装包只有用户选择下载时才传输。安装使用当前用户权限，等待旧进程退出，保留 `data/` 与未知用户文件；自动更新时保留自定义数据目录，完成后重启。

当前安装包未附加 Windows Authenticode 证书。更新清单签名与安装包摘要校验已经启用；它们与 Windows 发布者证书是不同机制。
