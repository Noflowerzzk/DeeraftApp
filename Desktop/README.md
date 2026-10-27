# DeeraftApp Windows

已固定 Prism Launcher 11.1.1 源码，并完成项目内 Qt/C++ 工具链及可启动的集成版本。当前处于开发阶段，不代表完整功能已验收。

用户最新确认：启动器主界面必须完全融入 App，只保留 Prism 的相关二级窗口；桌面端重新按 M3 Expressive 设计，不沿用手机端配置。正式界面替换暂停，先审阅 [可交互设计稿](design/m3-expressive/index.html)、[设计说明](design/m3-expressive/DESIGN.md) 和 [Styles 学习记录](design/m3-expressive/STYLE-STUDY.md)。

## 目录

- `app/`：Qt/QML 壳层、社区客户端、第三方账号、目录兼容和下载源适配。
- `launcher/`：固定版本 Prism 源码，来源见 `launcher/UPSTREAM.md`。
- `design/m3-expressive/`：独立 HTML 设计稿，含本地字体、素材、明暗主题与交互状态。
- `scripts/`：工作区内工具链、构建、运行、打包和设计取证脚本。
- `.toolchain/`、`.cache/`、`build/`、`dist/`：本地产物，不提交。

## 开发命令

从仓库根目录执行：

```powershell
./Desktop/scripts/bootstrap.ps1
./Desktop/scripts/build.ps1
./Desktop/scripts/run.ps1
./Desktop/scripts/package.ps1
```

开发脚本只在当前进程设置环境，不修改系统 PATH。编译器、Qt、依赖与临时目录留在 Desktop 内。便携数据默认为程序旁 `data/`；开发时可用 `run.ps1 -AppArguments @('--dir','绝对路径')` 指定独立数据目录。

## 验证边界

已通过桌面默认 CTest 22 项、独立社区测试 8 项、目录兼容测试 9 项，手机端静态检查与 Android 调试构建通过。Windows 符号链接的提权测试默认禁用，不自动触发 UAC；文件链接辅助程序已部署其 Qt DLL，并在不含开发环境 PATH 的进程中验证加载。

尚未完成：最终 Expressive Qt 界面替换、所有账号的真实授权、实际 Minecraft/模组/整合包启动、镜像故障和完整性异常的端到端验证、网站管理写操作的真实角色联调、Windows 10 实机及完整便携发行回归。HTML 设计稿使用展示数据，不执行这些操作。
