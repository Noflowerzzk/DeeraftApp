# Material 3 Styles 学习与应用记录

来源：[Material 3 Styles](https://m3.material.io/styles)。学习日期：2026-10-27。通过真实浏览器执行页面 JavaScript，读取渲染后的 HTML、DOM、图例说明与表格，并沿站内 Styles 链接逐页检查。目录共 50 个入口，去除根路径与默认标签的别名后为 **38 个独立页面**，包含入口页。

页面与组件快照保存在项目内 `Desktop/.oil-ui/m3-expressive/`，不把官网全文或缓存提交到产品源码。官网内容导出版本为 `2026-10-13_06-10-19`。

## 七个章节的实际结论

### Color

用角色而非固定色块思考界面：primary/onPrimary、container/onContainer、surface/onSurface 必须成对。不能给深浅色模式只换背景而留下原来的文字颜色。动态方案可以结合固定语义色，但单屏不要混入太多独立色源。HCT 的 tone 决定对比，不能用 HSL lightness 等价代替。颜色保真、协调色和自定义角色是解决具体问题的工具，不必全部启用。

本稿由独立品牌源生成明暗角色色，语义错误保持 error 角色。主启动按钮使用 primary/onPrimary，选中导航使用 secondary container/onSecondaryContainer。标准文本以 4.5:1、大字以 3:1 为最低检查目标；不靠降低整块文字透明度表达次要信息。

### Elevation

六个层级为 0/1/3/6/8/12dp；层级本身不是阴影。通常的静止组件只需 0–3 级，悬停和拖动才考虑更高层级。表面角色与层级不是一对一关系。模态遮罩采用 scrim 32%。不通过给所有卡片加阴影制造层级。

### Icons

使用同一套 Material Symbols，区分 weight、fill、grade、optical size。桌面密集区域适合 20dp 符号、40dp 目标；普通操作默认 24dp/48dp。不要用字符或表情替代关键操作图标。抽象导航必须带标签。深色中可用 grade 微调视觉重量，不通过混用图标风格解决。

### Motion

新版以 spring 为主：spatial 处理位置、尺寸与形状，可轻微越过目标；effects 处理颜色和透明度，不应回弹。小组件用 fast，侧栏用 default，大区域慎用 slow。可打断的运动保留当前速度。旧版 easing/duration 与 transitions 文档仍需阅读，但不能将旧的固定时长系统误当 Expressive 弹簧。

转场遵守语义：顶层导航淡出再淡入；同级标签横向；层级进退遵循前后关系；容器展开仅在关系清晰的重点场景使用。避免同时把所有元素向不同方向移动。减少动态效果必须生效。

### Shape

完整尺度为 0/4/8/12/16/20/28/32/48/full。不要把 full 理解为始终设置 50%；矩形组件需要真正的全圆端点。相邻连接组件可以非对称。内外嵌套圆角应满足光学关系：外圆角减内边距约等于内圆角。35 种抽象形状只在有意图的少量图像、头像或进度节点出现，不用于文字密集容器。

### Spacing

以 8dp 为基准，保留常用的 2/4/6/10 等嵌套单位。父容器先管理 padding 和 gap，减少对子元素随意加 margin。桌面密度和可用窗口宽度可以改变映射。文字放大时不要同比放大所有间距，以免内容离散；应让组件与文本重排。

### Typography

15 个 baseline 加 15 个 emphasized；不必全部用于一个产品。Display/Headline/Title/Body/Label 职责不同，醒目不等于所有文字加粗。变量字体适用于实例名等重点，正文保持易读。Roboto Flex 不是自动等同于默认类型尺度，属于本稿的品牌字体定制；中文回退 Noto。中文属于 medium language height，需比 Latin base 更高的行框。表格与时间使用 tabular numbers，避免更新时抖动。Editorial 只用于内容重点，不能把每个标签做成宣传海报。

## Token 数据核对

官网动态 Token 查看器在本地浏览器没有完整显示。已从它所调用的**公开同源 JSON**读取对应资料，未使用图片估算值：`COLOR`、`ELEVATION`、`TOKEN_TYPE_UNSPECIFIED`、`MEASUREMENT`、`TYPOGRAPHY`，系统 `Google Material 3`，版本 `38.2.9`。核对范围含配色角色、状态透明度、spring、圆角、间距、baseline/emphasized 字体及语言行高上下文。原始数据只保存在忽略的研究目录；未把作者元数据放入交付文件。

有关视频：阅读了页面提供的动效说明、图例与可获取的文字内容，设计稿复现相关交互。没有将所有外链演讲视频完整观看冒充成已完成的工作。

## 逐页阅读清单

下列清单按站点实际链接生成，包含各标签页而不只包含章节首页。

- 已读：[styles](https://m3.material.io/styles)
- 已读：[styles / color / system / overview](https://m3.material.io/styles/color/system/overview)
- 已读：[styles / color / roles](https://m3.material.io/styles/color/roles)
- 已读：[styles / color / choosing-a-scheme](https://m3.material.io/styles/color/choosing-a-scheme)
- 已读：[styles / color / static / baseline](https://m3.material.io/styles/color/static/baseline)
- 已读：[styles / color / dynamic / choosing-a-source](https://m3.material.io/styles/color/dynamic/choosing-a-source)
- 已读：[styles / color / advanced / overview](https://m3.material.io/styles/color/advanced/overview)
- 已读：[styles / color / resources](https://m3.material.io/styles/color/resources)
- 已读：[styles / elevation / overview](https://m3.material.io/styles/elevation/overview)
- 已读：[styles / icons / overview](https://m3.material.io/styles/icons/overview)
- 已读：[styles / motion / overview / how-it-works](https://m3.material.io/styles/motion/overview/how-it-works)
- 已读：[styles / motion / easing-and-duration / applying-easing-and-duration](https://m3.material.io/styles/motion/easing-and-duration/applying-easing-and-duration)
- 已读：[styles / motion / transitions / transition-patterns](https://m3.material.io/styles/motion/transitions/transition-patterns)
- 已读：[styles / shape / overview-principles](https://m3.material.io/styles/shape/overview-principles)
- 已读：[styles / spacing / overview](https://m3.material.io/styles/spacing/overview)
- 已读：[styles / typography / overview](https://m3.material.io/styles/typography/overview)
- 已读：[styles / color / system / how-the-system-works](https://m3.material.io/styles/color/system/how-the-system-works)
- 已读：[styles / color / static / custom-brand](https://m3.material.io/styles/color/static/custom-brand)
- 已读：[styles / color / dynamic / user-generated-source](https://m3.material.io/styles/color/dynamic/user-generated-source)
- 已读：[styles / color / dynamic / content-based-source](https://m3.material.io/styles/color/dynamic/content-based-source)
- 已读：[styles / color / advanced / apply-colors](https://m3.material.io/styles/color/advanced/apply-colors)
- 已读：[styles / color / advanced / define-new-colors](https://m3.material.io/styles/color/advanced/define-new-colors)
- 已读：[styles / color / advanced / adjust-existing-colors](https://m3.material.io/styles/color/advanced/adjust-existing-colors)
- 已读：[styles / elevation / applying-elevation](https://m3.material.io/styles/elevation/applying-elevation)
- 已读：[styles / elevation / tokens](https://m3.material.io/styles/elevation/tokens)
- 已读：[styles / icons / designing-icons](https://m3.material.io/styles/icons/designing-icons)
- 已读：[styles / icons / applying-icons](https://m3.material.io/styles/icons/applying-icons)
- 已读：[styles / motion / overview / specs](https://m3.material.io/styles/motion/overview/specs)
- 已读：[styles / motion / easing-and-duration / tokens-specs](https://m3.material.io/styles/motion/easing-and-duration/tokens-specs)
- 已读：[styles / motion / transitions / applying-transitions](https://m3.material.io/styles/motion/transitions/applying-transitions)
- 已读：[styles / shape / corner-radius-scale](https://m3.material.io/styles/shape/corner-radius-scale)
- 已读：[styles / shape / shape-morph](https://m3.material.io/styles/shape/shape-morph)
- 已读：[styles / spacing / applying-spacing](https://m3.material.io/styles/spacing/applying-spacing)
- 已读：[styles / spacing / tokens](https://m3.material.io/styles/spacing/tokens)
- 已读：[styles / typography / fonts](https://m3.material.io/styles/typography/fonts)
- 已读：[styles / typography / type-scale-tokens](https://m3.material.io/styles/typography/type-scale-tokens)
- 已读：[styles / typography / applying-type](https://m3.material.io/styles/typography/applying-type)
- 已读：[styles / typography / editorial-treatments](https://m3.material.io/styles/typography/editorial-treatments)
