# Material 3 界面改版 · v0.4.0

## 方向与范围

北极星：让玩家打开应用就能看清服务器与朋友的在线状态，用标准 Material 组件完成浏览、切换和资料修改。

品类是 Minecraft 社区伴侣，主要任务是查看在线状态、服务器、聊天记录与个人时长。用户已明确选择 Google Material Design；此次只做这个方向，不另开风格候选。以官方组件样例为结构参考，保留 Deeraft 森林标识、Minecraft 皮肤头像、现有四个入口与简短中文文案。与官方组件展示 App 的区别是：首屏聚焦在线数与玩家，聊天采用按时间排列的消息，服务器展示实际封面和版本，不复制组件目录或配色切换工具。

## 官方资料与源码

本次读取网页正文与样例 Dart 源码，不仅依据截图模仿：

- [Flutter Material Design 文档](https://docs.flutter.dev/ui/design/material)：Material 官方实现与组件入口。
- [Flutter Material 3 Demo](https://github.com/flutter/samples/tree/main/material_3_demo)：原生 AppBar、NavigationBar、Card、SegmentedButton、TextField 等组件。
- [Demo 的 main.dart](https://github.com/flutter/samples/blob/main/material_3_demo/lib/main.dart)：读取其 ThemeMode.system、light/dark ThemeData 与 seed 配色实现，采用相同的主题组织思路。本项目未复制样例业务代码。
- [Material Motion](https://m3.material.io/styles/motion/overview/how-it-works)：反馈与状态连续性。
- [Flutter 减少动画说明](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html)。

过程资料保留于忽略目录 `work/material-redesign/`。原 Kole Jain 设计解析与 v0.3.x 记录作为历史资料保留，当前视觉标准以本文为准。

## 视觉规则

- 单一种子色 `#356B4A` 来自森林标识与 Minecraft 内容；`ColorScheme.fromSeed` 派生全部深浅色角色，跟随系统亮度。
- 内容区使用 surface / surfaceContainerLow；选中项和操作使用 primary / secondaryContainer。不叠加渐变、玻璃、额外阴影或装饰描边。
- Noto Sans SC 离线字体，Material 默认字号角色。页面标题与在线数分层，正文以 14–16sp 为主；状态和头像名称用标准 label 角色。
- 标准 AppBar、72dp NavigationBar、FilledButton、OutlinedButton、SegmentedButton、模态 BottomSheet、DatePicker、TextField。圆角内容卡片24dp；原生组件保留各自形状和点击反馈。
- 页面边距16dp、卡片内20dp。窄屏/大字体时数据行和玩家筛选自动换行，信息不靠缩小字体硬塞。
- Minecraft 状态和可折叠玩家放在同一卡片；真人/全部切换明确区分数据口径。超过8人折叠。头像沿用网站 Minotar 地址；加载失败保留可见占位。
- 服务器保留实际封面；缺少封面时显示简单 Material 山景图标。不生成虚构的服务器截图。
- 时长最多显示5条真实记录，累计涵盖全部；数据少于5条不补假数据。增加排行和比例条。

## 动效

| 场景 | 实现 |
| --- | --- |
| 点击与选择 | Material 原生水波纹、按钮状态与导航指示器；不另套玻璃导航 |
| 切换页面 | 260ms 小幅横移与淡入，保留页面状态及滚动位置 |
| 首次进入 | 380ms、10dp 以内的卡片/消息出场，不随定时刷新重播 |
| 在线数更新 | 260ms 数值滑动淡入，等宽数字 |
| 玩家展开收起 | 260ms 尺寸变化，展开图标同步旋转 |
| 详情与资料面板 | Material BottomSheet、拖动柄和系统返回，260ms进入/140ms退出 |

自定义曲线统一为 `Cubic(.2, 0, 0, 1)`，时长是本应用选择，不声称逐项等于 Material 官方 token。系统移除动画时自定义动画直接完成；组件原生反馈继续遵循 Flutter Material 的实现。没有常驻装饰循环。

## 状态与功能边界

保留加载、错误、上次数据、空列表、在线/离线、登录/注册、密码显隐、上传头像、资料编辑、日期选择和退出登录。资料保存中禁止重复提交；失败保留表单内容；保存完成显示新资料。长期会话及网络逻辑沿用原实现，本次不改后台接口。

不新增宣传文案。删去空签名的默认句子、重复的 DEERAFT 装饰标签及服务器详情里的管理说明。演示模式仍明确标注“演示数据”，避免与线上信息混淆。微软登录的服务器配置限制仍见 README。

## 评审与证据

Qwen 独立静态视觉评审1轮，初版7/10。指出玩家头像空白，已补加载/失败占位并检查真机画面。其“排行必须补足5条”和“12人必须全显”的判断与业务口径不符：当前演示只有2条存档时长，真人列表为6人，全部为12人；用真实数据与折叠/排行测试核实，不补假记录。保留标准顶栏字号，不为提升标题权重破坏内容优先级。Qwen未检查动效，不把它的静态报告当成动效验收。原始报告在 `work/material-redesign/qwen-review.json`。

截图为 Android 16 模拟器1080×2340实际渲染；显式演示模式，不是线上数据。正式截图在 `docs/screenshots/v0.4.0/`；原生 screenrecord 视频在 `dist/Deeraft-material-motion.mp4`。自动化路径覆盖导航、全部/真人筛选、玩家展开及详情面板，日志无崩溃或布局溢出。独立UX走查与最终验证结果记录在《验证记录》。

独立UX走查1轮（`/root/material_ux_review`）实际操作模拟器，修正卡片外链图标暗示与详情面板行为不一致。服务器连接地址/加入功能不在现有数据及本次改版范围，保留为状态浏览的能力边界。
