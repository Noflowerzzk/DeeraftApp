# 转场与侧栏背景修正

## 实现

- 主页面和实例详情使用 Fade through：旧内容先淡出，再替换内容，随后新内容淡入并从 0.985 轻微放大到 1。采用 QmlMaterial 的 short2 / short4 / medium2 时长及 emphasized 曲线，不改变设计稿的最终布局。
- AppDialog 统一 Enter and exit：进入淡入并轻微放大，退出淡出并轻微缩小；菜单、侧栏和任务抽屉继续使用现有 QmlMaterial 动效。
- 重复点击更新待切换目标；开启减少动态效果后立即完成替换。实例切换中暂不响应启动按钮，避免启动旧选择。
- 修复 RailItem 的选中背景和 ripple 忽略 topPadding 的问题。指示器现在与内容使用同一个垂直偏移。

参考：[M3 transition patterns](https://m3.material.io/styles/motion/transitions/transition-patterns)、[Material 官方组件库 Motion 文档](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md)。未使用没有对应容器关系的 Container transform。

## 运行检查

- Release 构建通过，实际原生窗口捕捉到退出和进入两个阶段。
- rapidNavigationLastRequestWins、pageSettled、instanceSwapSettled、reducedMotionImmediate 均为 true。
- 社区、启动器、服务器、我的、设置五个 RailItem：收起时图标与背景中心 dx=0 / dy=0；展开时 dy=0，图标按设计位于宽背景的起始侧。
- native-checks.json 为实际 Qt Quick 图元位置测量；动画阶段截图使用显式测试夹具，未操作真实账号或服务器。
- QML 无类型、引用或属性赋值错误。最终便携包另以清除开发环境变量的方式检查内嵌 QML。

## 便携包

`Desktop/dist/DeeraftApp-win64-20261027-230354.zip`

SHA256：`bfb85cce1ed49286456988b2d3170c668fcd93da49b1b8a26335d503c55e9d1c`

最终包在仅保留 Windows 系统 PATH、移除 Qt 开发路径与视觉夹具后正常退出（exit 0），加载内嵌 QML；目录菜单可见、旧 Prism 主窗口隐藏且工具栏数为 0，未发现 QML 引用、类型或属性赋值错误。
