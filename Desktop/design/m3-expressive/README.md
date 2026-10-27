# DeeraftApp · 桌面设计稿

直接用 Edge / Chrome 打开 **index.html**，无需联网、安装依赖或启动服务。请保留同目录 CSS、JS、assets 和 vendor。

## 查看

- `index.html`：默认启动器，左侧四个主入口；聊天从社区进入。
- `index.html?theme=dark`：深色主题。
- `index.html?page=community`：社区页面。
- `index.html?state=mods`：模组列表。
- `index.html?state=downloads`：下载侧栏。
- `previews/`：浅色、深色、社区、服务器、聊天、个人资料与交互状态预览图。
- `DESIGN.md`：布局、组件、动效、主界面与二级窗口的边界。
- `STYLE-STUDY.md`：Styles 七章及 38 个独立页面的学习清单。
- `SOURCES.md`：参考、素材与字体许可。

这是**设计原型**。所有账号、在线人数、聊天、服务器、下载与游玩数据均为展示数据；启动、保存、启停和命令操作不连接真实服务、不修改游戏文件、不启动游戏。

## 检查

独立视觉评审一轮，初评分 8/10。随后修正了跨页面头像映射、辅助文字大小和启动器留白；本稿未以未经复评的分数代替初评分。

主 Agent 实测 16 项交互全部通过，包含实例/筛选/搜索、模组开关、启动状态、可打断侧栏、Escape、社区启动链路、1080×800 和 920×720 窗口检查。明暗主题共 14 组角色配色均达到至少 4.5:1。结果见 `previews/interaction-checks.json` 与 `previews/contrast-checks.json`。

Oil UI 工具完成四种状态截图、2 倍像素密度图、遮字图与动作录屏，未发现控制台错误、横向溢出或加载失败图片。证据位于工作区 `Desktop/.oil-ui/m3-expressive/evidence-final/`。2 倍图是像素密度，不等同于完成 200% 浏览器缩放布局验收。

已检查静态稿和交互状态；动效有可重放录屏与关键帧，没有宣称完成原速视频手感审查。文案从首稿即保持简短，修正了“搜索实例、服务器”对能力范围的过度承诺。


## 本轮批注修改

导航展开保持固定行高与标签宽度，连续平移；聊天从社区进入并有返回入口。搜索、目录和分组筛选集中到我的实例。封面显示游玩时长，系统状态收为底部折叠入口。

社区与服务器可配置关联实例；新增个人第三方服务器的新增、编辑、移除、快捷启动设计。配置在此原型的浏览器存储中保存；没有发送到网站。启动状态完成后更新玩家动态并显示右下角 Snackbar，真实游戏加入和后端动态尚未接入。完整的数据规则与后端接入约定见 DESIGN.md。

本轮未新增视觉评分，按批注逐项自检；之前的 8/10 仅属于首版。更新后的截图见 previews/，本轮浏览器交互检查见 previews/annotation-checks.json，动画证据位于 Desktop/.oil-ui/m3-expressive/evidence-annotations/。


## 状态列表与 Material 菜单修订

实例目录与分组使用自绘菜单并保留键盘操作。按最新批注，目录与分组取消菜单、箭头及筛选动画，弹层样式对齐启动菜单；标签指示条与配置弹窗的动效保留。

第三方服务器状态设计可通过 `index.html?state=server-status` 查看，或打开 `server-status-preview.html`。该入口的在线、版本、人数与延迟均为演示数据，不写入常规个人配置；普通新增记录显示未检测。当前 HTML 没有真实 Minecraft 查询服务，刷新演示检测中与查询失败，不伪造在线结果。

预览图：previews/material-menu-light.png、material-menu-dark.png、third-party-statuses.png。检查报告：previews/refinements-checks.json。新动作证据保存在工作区 Desktop/.oil-ui/m3-expressive/evidence-refinements/。本轮为按批注修改和自检，不新增评分，未宣称完成原速录像手感审查。


本轮 20 项新增检查连续三次通过：菜单键盘选择 / 关闭 / 焦点、目录分组交叉过滤、菜单打断反向、effects 不越界、指示条落位、弹窗入场、第三方在线 / 离线 / 失败状态、刷新去重、迟到响应、减少动态效果、1080 / 920px 窗口以及无运行时异常。

取证工具提示单入口 HTML 超过 40 KiB：为保持离线双击可用，仍使用静态 HTML；菜单逻辑、业务状态、物理动效和样式已分文件，不为这个设计原型引入打包器。菜单录屏可用；标签录像及单独补取的录像均遇到 ffmpeg 编码失败，已保留 start/mid/end 关键帧，详见 evidence-refinements-tabs/。不将编码失败解释为页面动效失败，亦不声称已有可播放的标签录像。


## 最新下拉栏修订

目录 / 分组立即展开收起，样式与启动菜单一致；三点菜单的遮挡与快速重开问题已修正。10 项针对性检查及更新后的 20 项回归检查通过。证据见 previews/menu-fix-checks.json、library-menu-fixed.png、library-menu-fixed-dark.png；当前无菜单动效，不沿用上一轮菜单动效检查结果作为当前验收。

最新补充：目录与分组菜单恢复与启动菜单相同的淡入淡出（x-transition.opacity），保留无位移、无缩放、无箭头及列表重排动画。
