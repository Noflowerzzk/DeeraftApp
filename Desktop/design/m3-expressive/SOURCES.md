# 参考、素材与许可

## 设计规范

- Google [Material 3 Styles](https://m3.material.io/styles)：全部 Styles 子页，见 STYLE-STUDY.md。
- Google [M3 Expressive](https://m3.material.io/blog/building-with-m3-expressive)：整体方向。
- Google [Canonical layouts](https://m3.material.io/foundations/layout/canonical-examples/overview)：启动器 list–detail、社区 supporting pane。
- Google [Navigation rail](https://m3.material.io/components/navigation-rail/overview)、[Button groups](https://m3.material.io/components/button-groups/overview)：折叠/展开导航轨、连接筛选与按压反馈。
- 本稿的 Web 实现是根据规范编写的原型，未宣称使用尚未提供的官方 Expressive Web 组件包。

## 实现与字体

- Alpine.js 3.14.9：MIT，https://github.com/alpinejs/alpine 。vendor/alpine.min.js 保留来源版本。
- Material Color Utilities 0.3.0：Apache-2.0，https://github.com/material-foundation/material-color-utilities 。用于从 `#216C5E` 生成配色，输出见 palette.json。
- Material Symbols Rounded：Apache-2.0，https://github.com/google/material-design-icons 。仅使用一套图标风格。
- Roboto Flex：SIL Open Font License，https://github.com/googlefonts/roboto-flex 。拉丁字母与数字。
- Noto Sans SC：SIL Open Font License，复用本项目已有字体文件；许可随 assets/OFL.txt 提供。
- 示例玩家头像：本设计稿生成的 8×8 SVG 图形，不是真实账号的皮肤或身份声明。

## 封面图

图片通过 CSS object-fit 裁切展示，没有修改原始图像文件。

- `village.png`：[Minecraft village panorama](https://commons.wikimedia.org/wiki/File:Minecraft_village_panorama.png)，SkullFurry69，CC BY-SA 4.0；https://creativecommons.org/licenses/by-sa/4.0/ 。
- `forest.png`：[Minecraft dappled forest](https://commons.wikimedia.org/wiki/File:Minecraft_dappled_forest.png)，SkullFurry69，CC BY-SA 4.0；同上。
- `map.png`：[Bluemap-screenshot (1)](https://commons.wikimedia.org/wiki/File:Bluemap-screenshot_(1).png)，ForestBrotherLT，CC0 1.0；https://creativecommons.org/publicdomain/zero/1.0/ 。
- `landscape.png`：[Minecraft Beta 1.8.1 Gameplay Screenshot](https://commons.wikimedia.org/wiki/File:Minecraft_Beta_1.8.1_Gameplay_Screenshot.png)，Xbox México，CC BY 3.0；https://creativecommons.org/licenses/by/3.0/ 。研究素材，本稿主界面未采用。

这些公开截图只用于说明游戏封面如何进入设计，不代表用户服务器的实际景观，也不构成 Mojang/Microsoft 的认可。


## 批注修订补充参考

以下均通过实际浏览器阅读渲染后的文本，非只读取截图。Snackbars 放在底部且不打断当前任务；搜索采用圆角 tonal surface 容器。选择器保留原生键盘和 optgroup 支持，使用本稿 Material 色彩与布局。

- [Snackbar overview](https://m3.material.io/components/snackbar/overview)
- [Menus overview](https://m3.material.io/components/menus/overview)
- [Search overview](https://m3.material.io/components/search/overview)

研究 DOM 文本记录在工作区 Desktop/.oil-ui/m3-expressive/shots/official-*.txt，不包含进正式交付包。
