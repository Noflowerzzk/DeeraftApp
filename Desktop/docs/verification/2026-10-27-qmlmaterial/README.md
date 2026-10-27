# QmlMaterial 主窗口与排版验证（2026-10-27）

主窗口改用独立 DesktopWindow + QQuickView。Prism 主窗口不再承载主界面，只保留隐藏的命令适配器；原有二级窗口使用 Windows11 样式。QmlMaterial 固定提交及本地适配见 app/vendor/QmlMaterial。

## 排版修正

- 使用显式 Roboto Flex / Noto Sans SC 字体链及 Qt PreferTypoLineMetrics，修复宋体回退和中文字形相对图标偏低。
- 以 design/m3-expressive 的 HTML/CSS/DOM 为依据设置行高、列宽、页签、按钮、导航和列表间距；不通过逐个文字 y 偏移补偿字体问题。
- 修正社区双栏约束、MOTD/在线数行高、玩家区域间距、个人页柱状图内边距、统计条确定进度和第三方服务器标题操作对齐。
- 下拉背景保留非零隐式尺寸，解决菜单首次打开时锚点布局失败。菜单统一淡入淡出与轻微缩放，三点菜单位于覆盖层。

## 已执行

- Release 构建通过；23 项启用的核心测试通过，FileSystem 的提权测试保持禁用；独立 community-tests 通过。
- 1440×960 原生运行截图，与脚本读取的设计稿 DOM 和截图比较。设计数据只在显式启用 DEERAFT_SMOKE_DIR 和 DEERAFT_DESIGN_FIXTURE 的视觉夹具中使用，便携包验证未启用夹具。
- 便携包在移除 QML_IMPORT_PATH / QT_PLUGIN_PATH / DEERAFT_QML_DIR、PATH 仅保留 Windows 系统目录后正常启动退出（exit 0）。直接加载内嵌 QML。
- native-checks.json：中文实际 glyph run 字体为 Noto Sans SC / Roboto Flex；sourceMenuOpened=true；账号/设置更新回调后 legacyWindowHiddenAfterAccountChange=true，appToolbarCount=0。
- 未发现 QML ReferenceError、TypeError、控件类型或属性赋值错误。外部头像网络请求不作为视觉夹具的保证内容。
- 此轮完成运行截图和程序化输入检查，未重新进行微软账号真实授权、游戏启动、所有权限下的服务器操作或 Windows10 实机验收。此前用户已确认游戏正常启动。

## 交付

- Desktop/dist/DeeraftApp-win64-20261027-224333.zip
- SHA256: 0b858e6dd636359657886069557be8bba80af9f1f663b7db8a240aa23063025a
- ZIP 不包含用户 data、账号或登录凭据。

截图为实际便携程序；完整设计夹具对照过程文件位于 Desktop/.cache/strict-ui（未纳入版本管理）。
