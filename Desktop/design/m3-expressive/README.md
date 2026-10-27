# DeeraftApp · 桌面设计稿

直接用 Edge / Chrome 打开 **index.html**，无需联网、安装依赖或启动服务。请保留同目录 CSS、JS、assets 和 vendor。

## 查看

- `index.html`：默认启动器，五个页面可从左侧导航切换。
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
