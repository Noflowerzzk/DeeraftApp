# DeeraftApp

Minecraft 社区应用与启动器，包含 Windows 桌面端和 Android 手机端。

[下载安装包与便携版](https://github.com/Noflowerzzk/DeeraftApp/releases/latest) · [网站下载页](http://mc.ainfinitythecoder.cn/downloads/index.html)

Windows 当前版本为 **0.6.2**，Prism 启动核心固定为 **11.1.1**。主界面使用 Qt Quick/QML 与 QmlMaterial，支持社区、服务器、聊天、实例管理、离线/正版/第三方账号和外部实例目录。详细功能与使用方法见 [桌面端说明](Desktop/README.md)。

已有便携版用户请安装到原程序目录，保留 `data/` 中的账号和设置。安装后可在“设置 → 应用更新”中检查更新。

## 工程

```text
Mobile/       Flutter Android 客户端及后端配套扩展
Desktop/
  app/        QML 界面、社区接口及桌面集成
  launcher/   Prism 11.1.1 源码和适配
  scripts/    构建、验证、打包与发布脚本
  release/    安装包与签名更新通道说明
```

- [Android 构建与使用](Mobile/README.md)
- [Windows 构建与使用](Desktop/README.md)
- [Windows 安装包与发布](Desktop/release/README.md)

工具链、缓存、构建产物和便携数据均保留在项目目录内，不提交到 Git。发布签名私钥不在仓库中。

## 上游与许可

桌面启动器基于 [Prism Launcher](https://github.com/PrismLauncher/PrismLauncher)，遵循所包含的 [GPL-3.0 许可](Desktop/launcher/LICENSE)。界面使用 [QmlMaterial](https://github.com/hypengw/QmlMaterial)。第三方源码、字体、素材及其许可证随对应工程保留；二进制包也包含许可证目录。
