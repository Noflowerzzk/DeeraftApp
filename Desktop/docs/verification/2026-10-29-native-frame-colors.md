# 原生窗口栏、分段配色与 Windows 图标 · 0.6.2

- 恢复 Qt/Windows 原生窗口栏；删除 QML 标题栏、边缘拖拽覆盖层与自定义非客户区处理。关闭任务确认保持有效。
- 配色选择直接复用“全部 / 收藏”的 QmlMaterial Connected ButtonGroupContainer 与 ToggleButton。每个按钮使用自身种子生成的 Material 色彩作为底色，选中用勾标记，不随选择改变宽度。
- 删除自拟的森林、苔原等显示名称；保留内部 ID 以兼容已保存的选择。未找到这些种子对应的官方专名，界面只显示颜色，无名称。辅助技术读出实际颜色值。
- 检查用户正在运行的 D:/DeeraftApp/DeeraftApp.exe：与发布的 0.6.1 哈希一致，内嵌 D 图标正确。原检查遗漏 Windows Shell 集成；现增加独立进程与窗口 AppUserModelID、窗口重启图标资源、独立 DeeraftApp.ico，快捷方式明确引用该 ICO，安装后通知 Shell 刷新图标。
- 保留 Prism 认证使用的原标识，只将 Windows Shell 身份设为 cn.ainfinity.DeeraftApp，避免改变登录流程。

验证：24 项启用的 CTest 通过；专项 Qt 检查连续三次通过，包括原生窗口标志、五种不同按钮底色、无自拟名称、真实 Windows API 读回进程/窗口 ID 与任务栏图标属性、最大化/还原、关闭确认和原有任务/聊天回归。截图检查分段颜色与相邻控件。Windows 原生窗口栏不在 QQuick 客户区截图中；未将该截图视为系统任务栏像素验收。

官方色彩变体参考：[Material Color Utilities](https://github.com/material-foundation/material-color-utilities/blob/main/typescript/dynamiccolor/variant.ts)。本轮为用户明确指定的组件复用，没有重新探索设计方向。

交付：DeeraftApp-0.6.2-windows-x64-setup.exe，SHA-256：`7C175470376BCA5029DD4A91FBCB2100B58BEDAC6FD75263CE49CC9E7AA71726`。
安装、同目录覆盖、安装后 Qt/QML 检查及卸载通过；data 和未知用户文件保留。EXE、安装器内嵌图标均与 D 标记匹配，安装后的独立 ICO 已被窗口任务栏属性引用。
线上签名更新通道已发布并由打包客户端校验：version=latest=0.6.2，内核仍为 11.1.1。无需重启网站后端。
