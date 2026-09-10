# ACGNhub 品牌规范（从 spec 提取）

> 来源：`spec/2026-09-10-acgnhub-ui-redesign.md`（用户提供、已锁定）
> 风格参考：Infuse（iOS/Figma）+ Apple TV

## 一句话系统

iOS 浅色系、内容优先的极简设计语言：浅灰底、白卡片、单一系统蓝 `#007AFF` 只用于选中态与主 CTA，四模块各有仅作装饰的强调色。

## 六个核心 Token

| Token | Hex | OKLch（近似） | 用途 |
|---|---|---|---|
| `--bg` | `#F2F2F7` | `oklch(0.956 0.003 264)` | 全局背景 |
| `--surface` | `#FFFFFF` | `oklch(1 0 0)` | 卡片 / 面板 / 搜索栏 |
| `--fg` | `#1C1C1E` | `oklch(0.232 0.004 286)` | 标题 / 正文 |
| `--muted` | `#8E8E93` | `oklch(0.618 0.006 286)` | 副文本 / 占位符 |
| `--border` | `#E5E5EA` | `oklch(0.917 0.004 286)` | 分割线 / 卡片边框 |
| `--accent` | `#007AFF` | `oklch(0.585 0.204 255)` | 唯一强调色：选中态 / 主按钮 / 链接 |

补充：`--accent-hover #0056CC`、`--sidebar-bg #F9F9FC`、`--sidebar-active #E8F0FE`、`--player-bg #000000`。

模块装饰色（仅详情页封面渐变遮罩，每页上限 1 处，不用于任何交互状态）：
动漫 `#5856D6` · 漫画 `#FF9500` · 轻小说 `#34C759` · 游戏 `#AF52DE`。

## 字体栈

- 正文 / UI：`system-ui, -apple-system, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif`
- 轻小说正文：`serif, "Songti SC", "Noto Serif CJK SC", "SimSun", serif`
- 播放器内：`system-ui, -apple-system, sans-serif`

字阶：模块标题 28/1.3/600 · 区域标题 20/1.4/590 · 作品标题 15/1.45/510 · 正文 14/1.6/400 · 辅助 12/1.5/400 · 侧边栏标签 11/1.5/510（letter-spacing .02em）。

## 五条视觉语言规则

1. 单一强调色：`#007AFF` 只出现在选中态与主 CTA；其余一律中性灰阶。
2. 内容优先：最小化 UI chrome，全局竖向滚动，仅播放器剧集列表允许横向滚动。
3. 外壳固定：左侧 72px 可收起竖列导航 + 48px 顶栏；播放器进入全屏沉浸，隐藏外壳。
4. 每页只有一个 primary CTA；次要操作用 Secondary（accent 描边）/ Text / Ghost。
5. CJK 排版：标题行高 ≥ 1.3、正文 1.7–1.8、不使用负字距；卡片圆角 10–12px。
