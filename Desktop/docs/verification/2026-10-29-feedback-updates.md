# 任务反馈、聊天与安装更新 · 2026-10-29

延续已确认的绿色 Material 3 Expressive 桌面方向，重用 QmlMaterial 控件。目标是让运行、进度、失败和普通通知清楚区分，不新增宣传文案。

## 已实现

- 输入框描边内缩半个笔画，修复左侧被裁切；浮动标签遵循减少动态效果设置。目录窗口文字使用深色主题的前景色。
- 有活动任务时显示实心变形加载标识；无活动时隐藏。`NetJob::updateState()` 保存真实进度，43/183 显示 23%。失败任务进入“已结束任务”。
- 内存不足保留日志警告、继续启动，通过应用内 Snackbar 提示。通知沿用 QmlMaterial，使用 Expressive 弹簧位移、圆角形变与退出反馈；文字宽度固定，避免入场重排。取消重复的父层高度动画，支持减少动态效果。
- 聊天采用相同 SearchBar，标题、图标与搜索入口对齐；退出搜索清空过滤。加入与离开提示采用手机端相同的居中系统消息格式。
- Fabric、Forge、NeoForge、Quilt Maven 与旧 Forge 地址按受支持规则映射 BMCLAPI。修复官方回退后重试一直停留官方源的问题；自动模式使用 15 秒无数据超时，取消不会触发回退。
- Windows 安装包、网站入口、静态签名更新通道已发布。自动每天至多检查一次小清单，大文件按需下载，游戏运行中禁止安装，更新保留数据目录。Prism 保持 11.1.1。

## 验证

- 24 项启用的 CTest 通过，上游 FileSystem 测试保持禁用。新增真实本地 HTTP 用例验证更新发现、签名、下载、进度、同尺寸损坏文件拒绝、取消不留下成功产物，以及运行游戏时拒绝安装。
- 本次专项 Qt UI 检查连续三次通过：加载标识活动/空闲、43/183→23%、失败任务归档与历史、深色文字、聊天搜索与清空、应用内通知。
- 安装、覆盖更新、包内 Qt/QML 运行、卸载均实际完成，原 `data/preserve.txt` 与安装目录中的用户文件保留。测试使用项目内中文路径，不写用户注册表或桌面快捷方式。
- 线上下载页面、清单与安装包 HEAD 均为 200。打包程序实际通过公网签名清单校验，报告 `version=latest=0.6.0`、`kernel=11.1.1`、`status=已是最新版本`。
- 窗口未在真实桌面前台曝光；专项截图采用减少动态效果验证几何与颜色。弹簧推进另由实际计时单元用例验证，未将静态截图当作真人动画验收。存量全流程 polish 探针在无曝光窗口中出现时序不稳定，本轮没有通过修改产品行为来迎合该探针。
- oil-ui 一轮独立静态走查，不评分。修正隐藏搜索仍过滤、通知宽度变化可能换行的问题；保持用户要求的运行状态加载标识。未重做网络头像策略。
- 下载页 Edge 截图启动被自动审批拒绝，工具仅返回 `blocked by policy`。未取得该页面的浏览器截图；已检查静态 HTML、HTTP 返回和实际客户端更新通道。

## Fabric 故障解释

当天实测：Fabric 1.20.1 intermediary 镜像为 200；截图中 26.3 intermediary 的两个 BMCLAPI 地址均返回 404，官方地址一次 TLS 握手超时；同版本的 sponge-mixin 镜像为 200。Quilt 0.26.4 的一个样例镜像返回 404。说明镜像覆盖和外部链路状态都可能影响首次下载。程序保留官方回退、摘要校验与重试，不把缺失文件标记为成功；不能保证第三方源始终可用。

## 交付与证据

安装包 `Desktop/dist/DeeraftApp-0.6.0-windows-x64-setup.exe`，SHA-256：`C8F6EE3EB592D492228D4AAE2651BF9A600923AFA3B3E1D1EFC8E02FFD36A8B5`。

网站：[下载页](http://mc.ainfinitythecoder.cn/downloads/index.html)。同名目录内保存专项 JSON、线上检查 JSON 和实际 Qt 截图，不包含用户账号或日志。

参考：[Material Snackbar](https://m3.material.io/components/snackbar/overview)、[BMCLAPI](https://bmclapidoc.bangbang93.com/)、[NSIS 参数与脚本](https://nsis.sourceforge.io/Docs/Chapter4.html)。
