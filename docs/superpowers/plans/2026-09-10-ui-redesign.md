# ACGNhub 界面设计原型 — 实现计划

> **产出目录：** `D:\ACGNhub\opendesign/`
> **形式：** 纯 HTML/CSS/JS 单页设计原型
> **说明：** 所有 UI 屏幕在一个 HTML 文件内通过左侧导航切换展示

**Goal:** 在 `D:\ACGNhub\opendesign/` 产出完整的 ACGNhub 视觉设计原型。

**Architecture:** 单个 `index.html` 包含所有 CSS/JS，左侧竖列导航切换 10+ 个屏幕，所有交互为模拟状态。

**Tech Stack:** HTML5, CSS3 (内联), Vanilla JS

## Global Constraints

- 产出目录：`D:\ACGNhub\opendesign/`
- 色彩 token：bg=#F2F2F7, surface=#FFF, accent=#007AFF, fg=#1C1C1E, muted=#8E8E93, border=#E5E5EA
- 排版：标题 20-28px/590-600w, 正文 14px/400w, CAPS letter-spacing ≥ 0.06em
- CJK 标题行高 ≥ 1.3, 正文 ≥ 1.7
- 每视图仅一个 primary CTA
- 全局竖向滚动
- 侧边栏可收起
- 占位数据使用真实感日文/中文名称，不造假数字

---

### Task 1: 创建完整设计原型

**产出：** `D:\ACGNhub\opendesign\index.html`

**结构（顺序实现各部分）：**

1. **CSS 变量与基础样式** — `:root` 定义全部 token，body flex 布局，侧边栏 72px + 主内容区

2. **侧边栏组件** — 5 项导航（动漫/漫画/轻小说/游戏 + 底线 + 设置），收起 ☰ 按钮，AnimatedSwitcher 式 CSS transition，选中态左侧 3px accent 竖线

3. **顶部栏** — 48px，模块标题 + 搜索按钮，背景 surface + 底部 0.5px border

4. **通用组件类** — `.btn-primary` / `.btn-secondary` / `.btn-text` / `.pill` / `.card` / `.card-grid` / `.tag` / `.section-title` / `.shimmer` / `.empty-state`

5. **动漫首页** — Hero 卡片(240px, 渐变遮罩, 标题+来源+立即观看按钮) → Pill 组(继续观看/热门推荐/最近更新) → section-title → 5 列卡片网格(12 张模拟卡片)

6. **动漫搜索页** — 搜索栏(返回箭头 + 圆角输入框 + 搜索按钮) → 源筛选 chips → 空态(未输入) / shimmer 加载态骨架

7. **动漫详情页** — 顶部返回+标题+收藏 → 封面大图(220px + 渐变过渡) → 左封面缩略图+右标题/评分/话数 → 标签行 → 简介(可展开) → 剧集列表 Card(每行 48px, chevron) → 底部固定 primary CTA → 点击剧集弹出播放器

8. **播放器全屏浮层** — 黑色全屏覆盖, 顶部半透明返回栏, 视频占位区, 剧集横向条(当前集 accent 高亮), 底部控制栏(进度条+播放暂停+快进+倍速)

9. **漫画首页** — 同动漫结构，Hero 用暖橙色渐变(`#FF9500`), Pill(继续阅读/热门/最新), 结果角标"更新至第XX话"

10. **漫画详情页** — 封面+话数列表 + 源信息栏(仅显示源名 + 登录需按钮) + 底部 primary "从第1话开始" + secondary "继续阅读第XX话"

11. **轻小说首页** — Hero 横幅 160px 青绿色(`#34C759`), Pill(热门排行/最新入库/完本精选), 120×160 封面卡片

12. **轻小说详情页** — 左封面+右信息(书名/作者/字数/状态) → 标签 → 简介 → 树形目录(卷折叠, 章节独立入口) → Aa 字号按钮 → 底部 primary

13. **轻小说阅读器** — 顶部返回+章节标题+Aa/目录按钮 → 正文区(max-width 680px, serif 字体, 16px/1.8 行高, 占位段落) → 底部上一章/下一章 → 字号设置底部 Sheet(滑块 12-24px, 行距紧凑/标准/宽松, 主题日间/护眼/夜间) → 目录滑入面板(右侧 280px, 树形结构)

14. **游戏首页** — 截图轮播(220px, 底部圆点指示器) → Pill(最新发布/高分推荐/品牌索引) → 卡片网格(游戏名+品牌)

15. **游戏详情页** — 截图轮播 → 标题(品牌·发售日) → 标签 → 简介 → 详细信息 Card(原画/剧本/音乐/CV 键值对) → 底部来源标注 → 无播放按钮

16. **设置页** — Card 列表(清除缓存/源管理/关于)

**JS 交互：**
- `showScreen(id)` — 切换左侧选中态 + 显示对应 screen div
- `toggleSidebar()` — 收起/展开 300ms cubic-bezier
- `openPlayer()` / `closePlayer()` — 播放器浮层
- Pill 点击切换选中态
- 所有模拟数据使用 `.innerHTML` 动态生成（不在 HTML 中硬编码大量重复卡片）

---

### Task 2: 自测

- [ ] 浏览器打开 `opendesign/index.html`
- [ ] 侧边栏全部 5 项可点击切换，收起/展开正常
- [ ] 动漫首页 Hero + Pill + 网格显示正确
- [ ] 搜索页状态展示(空态)
- [ ] 详情页 → 播放器联动
- [ ] 漫画/轻小说/游戏 3 模块页面展示
- [ ] 轻小说阅读器字号/行距/主题切换
- [ ] 设置页显示
- [ ] 所有 hover 效果正常
- [ ] 无布局溢出或重叠