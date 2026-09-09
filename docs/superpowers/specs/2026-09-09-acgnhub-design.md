# ACGNhub 设计文档

> 日期：2026-09-09  
> 状态：设计中  
> 审阅：待用户确认

---

## 1. 概述

ACGNhub 是一个聚合动漫、漫画、轻小说、Galgame 游戏资源的跨平台应用，面向 Windows 和 Android。采用 Flutter 框架，单一应用内四个 Tab 切换四个模块，按阶段依次实现。

### 1.1 参考项目

| 模块 | 参考项目 | 技术栈 | 借鉴方向 |
|---|---|---|---|
| 动漫 | Kazumi (`Predidit/Kazumi`) | Flutter | XPath 规则引擎、多源聚合 |
| 动漫 | AniCh (`Sle2p/AniCh`) | Flutter | 简洁UI风格 |
| 漫画 | venera (`venera-app/venera`) | Flutter + Rust | JS 脚本化源、阅读器 |
| 轻小说 | — | — | 抓取 wenku8.net |
| 游戏 | — | — | 抓取 nekogal.com / game.galgamezywz.org |

### 1.2 开发阶段

| 阶段 | 内容 | 依赖 |
|---|---|---|
| 阶段1 | 动漫模块（XPath规则引擎 + 视频播放器） | 无 |
| 阶段2 | 漫画模块（JS脚本引擎 + 漫画阅读器） | 阶段1核心层 |
| 阶段3 | 轻小说模块（Wenku8爬虫 + 小说阅读器） | 阶段1核心层 |
| 阶段4 | 游戏模块（双站爬虫 + 信息展示） | 阶段1核心层 |

每个阶段完成后由用户验收，验收通过后再进入下一阶段。先完成 Windows 平台，全部功能实现后再适配 Android。

---

## 2. 架构设计

### 2.1 整体架构

采用"统一源引擎 + 模块化UI"方案（方案A）。核心层提供统一的 `SourceAdapter` 抽象接口，每个模块注入具体实现。

```
┌────────────────────────────────────────────────┐
│                    UI 层                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────┐│
│  │ 动漫 Tab  │ │ 漫画 Tab  │ │ 小说 Tab  │ │游戏Tab││
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──┬───┘│
├───────┼────────────┼────────────┼───────────┼────┤
│       │       Source 适配器层                  │    │
│  ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌──┴───┐│
│  │XPath引擎 │ │ JS引擎   │ │Wenku8爬虫│ │Gal爬虫││
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──┬───┘│
├───────┼────────────┼────────────┼───────────┼────┤
│       │          核心层                          │
│  ┌────┴──────────────────────────────────────┐  │
│  │  HttpClient | CacheManager | SearchEngine  │  │
│  │  FavoriteManager | Database               │  │
│  │  Work / Chapter / Source 数据模型          │  │
│  └───────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

### 2.2 目录结构

```
ACGNhub/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   │
│   ├── core/
│   │   ├── models/
│   │   │   ├── work.dart
│   │   │   ├── chapter.dart
│   │   │   ├── source.dart
│   │   │   └── search_result.dart
│   │   ├── source/
│   │   │   ├── source_adapter.dart
│   │   │   └── source_manager.dart
│   │   ├── services/
│   │   │   ├── http_client.dart
│   │   │   ├── cache_manager.dart
│   │   │   ├── search_engine.dart
│   │   │   └── favorite_manager.dart
│   │   ├── storage/
│   │   │   └── database.dart
│   │   └── widgets/
│   │       ├── work_card.dart
│   │       ├── search_bar.dart
│   │       ├── chapter_list.dart
│   │       └── loading_widget.dart
│   │
│   ├── modules/
│   │   ├── anime/
│   │   │   ├── anime_source.dart
│   │   │   ├── rules/
│   │   │   │   ├── source_a.json
│   │   │   │   └── source_b.json
│   │   │   ├── anime_player.dart
│   │   │   ├── anime_detail.dart
│   │   │   ├── anime_search.dart
│   │   │   └── anime_home.dart
│   │   │
│   │   ├── comic/
│   │   │   ├── comic_source.dart
│   │   │   ├── scripts/
│   │   │   ├── comic_reader.dart
│   │   │   ├── comic_detail.dart
│   │   │   ├── comic_search.dart
│   │   │   └── comic_home.dart
│   │   │
│   │   ├── novel/
│   │   │   ├── wenku8_adapter.dart
│   │   │   ├── novel_reader.dart
│   │   │   ├── novel_detail.dart
│   │   │   ├── novel_search.dart
│   │   │   └── novel_home.dart
│   │   │
│   │   └── game/
│   │       ├── gal_adapter.dart
│   │       ├── game_detail.dart
│   │       ├── game_search.dart
│   │       └── game_home.dart
│   │
│   └── shell/
│       ├── main_shell.dart
│       └── settings_page.dart
│
├── assets/
│   ├── rules/
│   └── scripts/
│
├── pubspec.yaml
└── test/
```

---

## 3. 数据模型

### 3.1 核心模型

```dart
enum WorkType { anime, comic, novel, game }

class Work {
  final String id;
  final String sourceId;
  final String sourceName;
  final WorkType type;
  final String title;
  final String? coverUrl;
  final String? summary;
  final List<String>? tags;
  final String? author;
  final Map<String, dynamic> extra;
}

class Chapter {
  final String id;
  final String workId;
  final String title;
  final int index;
  final String? url;
  final Map<String, dynamic> extra;
}

class SearchResult {
  final List<Work> works;
  final int totalPages;
  final int currentPage;
}
```

### 3.2 各模块扩展字段

| 模块 | Work.extra 示例 | Chapter.extra 示例 |
|---|---|---|
| 动漫 | `{ "year": 2024, "season": "秋", "rating": 8.5 }` | `{ "resolutions": ["1080p","720p"], "duration": 1440 }` |
| 漫画 | `{ "status": "连载中", "latestChapter": 142 }` | `{ "images": ["url1","url2"], "pageCount": 18 }` |
| 轻小说 | `{ "wordCount": 1200000, "status": "已完结" }` | `{ "content": "完整文本", "volume": 3 }` |
| 游戏 | `{ "brand": "柚子社", "releaseDate": "2024-06-28", "screenshots": [...] }` | 不适用（无章节概念） |

---

## 4. 源适配器系统

### 4.1 抽象接口

```dart
abstract class SourceAdapter {
  String get id;
  String get name;
  WorkType get type;
  String get baseUrl;

  Future<SearchResult> search(String keyword, {int page = 1});
  Future<Work> fetchDetail(String workId);
  Future<List<Chapter>> fetchChapters(String workId);
  Future<dynamic> fetchContent(String chapterId);
}
```

### 4.2 源管理

```dart
class SourceManager {
  void register(SourceAdapter adapter);
  void remove(String sourceId);
  List<SourceAdapter> getByType(WorkType type);
  Future<List<SearchResult>> searchAll(WorkType type, String keyword);
}
```

### 4.3 模块1：XPath 规则引擎（动漫）

规则文件为 JSON 格式，使用 XPath 选择器定位 HTML 元素：

```json
{
  "name": "示例源",
  "baseUrl": "https://example.com",
  "search": {
    "url": "/search?keyword={keyword}&page={page}",
    "list": "//div[@class='anime-list']/div",
    "title": ".//h3/text()",
    "cover": ".//img/@src",
    "link": ".//a/@href"
  },
  "detail": {
    "summary": "//div[@class='desc']/text()",
    "tags": "//span[@class='tag']/text()",
    "chapters": "//ul[@class='ep-list']/li",
    "chapterTitle": ".//a/text()",
    "chapterLink": ".//a/@href"
  },
  "video": {
    "playUrl": "//video/source/@src",
    "resolutions": "//select[@class='resolution']/option/@value"
  }
}
```

XPathAdapter 工作流程：读取规则 → 拼接URL → HTTP请求 → XPath解析HTML → 返回模型。支持规则导入/导出，内置3-5个常用源规则。

### 4.4 模块2：JS 脚本引擎（漫画）

使用 `flutter_js` 在隔离的 JS 运行时中执行源脚本：

```javascript
var source = {
  name: "示例漫画源",
  baseUrl: "https://comic.example.com",
  search: async function(keyword, page) {
    let html = await fetch(this.baseUrl + "/search?q=" + keyword + "&p=" + page);
    return { works: [...], totalPages: 5 };
  },
  getDetail: async function(workId) { ... },
  getChapters: async function(workId) { ... },
  getImages: async function(chapterId) { ... },
};
```

通过 bridge 向 JS 注入 HTTP 请求能力。内置3-5个漫画源脚本，支持用户自行安装/编写。

### 4.5 模块3：Wenku8 爬虫（轻小说）

固定网站，直接硬编码爬虫逻辑：

| 操作 | 方法 |
|---|---|
| 搜索 | POST `wenku8.net/modules/article/search.php` |
| 详情 | GET `wenku8.net/book/{id}.htm` |
| 目录 | 解析详情页中的卷/章节链接 |
| 正文 | GET `wenku8.net/novel/{bid}/{cid}.htm` |

### 4.6 模块4：双站爬虫（游戏）

| 网站 | 抓取内容 | 方法 |
|---|---|---|
| `nekogal.com` | 名称、封面、发售日、品牌、标签、简介、截图 | HTML 解析 |
| `game.galgamezywz.org` | 同上，作为补充 | HTML 解析 |

仅实现 `search` 和 `fetchDetail`，无章节/内容相关方法。

---

## 5. 核心服务

### 5.1 HttpClient

- 基于 `dio` 封装
- 自动管理 User-Agent、Referer、Cookie
- 支持请求重试与超时
- 可选的反爬策略（随机延迟）

### 5.2 CacheManager

- 基于 `flutter_cache_manager`
- 图片/视频缓存，LRU 淘汰策略
- 可配置缓存大小上限

### 5.3 SearchEngine

- 接收用户输入，分发到所有注册的适配器
- 合并去重结果
- 使用 `Isolate` 并行搜索，避免阻塞UI

### 5.4 FavoriteManager

- 跨模块收藏增删查
- 本地持久化到 isar 数据库
- 支持按模块类型筛选

### 5.5 Database

- 基于 `isar`
- 存储：收藏列表、播放/阅读历史、规则/脚本文件、用户设置

---

## 6. 状态管理

使用 **Riverpod** 作为状态管理方案：

- 每个页面的数据状态由 `AsyncNotifierProvider` 管理
- 源的注册与切换由全局 `SourceManager` provider 管理
- 收藏列表由 `FavoriteManager` provider 全局提供
- 主题/设置由 `SettingsProvider` 管理

数据流：`用户操作 → UI Widget → Riverpod Provider → SourceAdapter → HttpClient → UI 状态更新`

---

## 7. UI/UX 设计

### 7.1 应用外壳

- 底部 `NavigationBar` 四个 Tab：动漫 | 漫画 | 小说 | 游戏
- 顶部可选的搜索入口（点击跳转对应模块搜索页）
- 设置页：主题切换、缓存管理、源管理、关于

### 7.2 动漫模块

- **首页**：推荐动漫网格、时间表视图
- **搜索**：搜索栏 + 结果列表，支持按源筛选
- **详情**：封面、简介、标签、章节列表
- **播放器**：`media_kit` 播放器，支持分辨率切换、倍速、硬件加速、续播

### 7.3 漫画模块

- **首页**：推荐漫画网格
- **搜索**：搜索栏 + 结果列表
- **详情**：封面、简介、标签、章节列表、登录入口
- **阅读器**：横向翻页 / 竖向滚动，手势缩放，预加载，进度保存

### 7.4 轻小说模块

- **首页**：Wenku8 推荐/排行
- **搜索**：搜索栏 + 结果列表
- **详情**：封面、简介、卷/章节目录
- **阅读器**：文字分页，字体大小/行距/主题可调，目录侧边栏，进度保存

### 7.5 游戏模块

- **首页**：最新游戏网格
- **搜索**：搜索栏 + 结果列表
- **详情**：封面、截图、简介、品牌、发售日期、标签

---

## 8. 依赖项

### 8.1 Flutter 依赖（pubspec.yaml）

| 包名 | 用途 | 版本 |
|---|---|---|
| `flutter_riverpod` | 状态管理 | ^2.0 |
| `dio` | HTTP 请求 | ^5.0 |
| `isar` / `isar_flutter_libs` | 本地数据库 | ^3.0 |
| `flutter_cache_manager` | 缓存管理 | ^3.0 |
| `media_kit` / `media_kit_video` | 视频播放 | ^1.0 |
| `flutter_js` | JS 脚本引擎（漫画） | ^0.8 |
| `html` | HTML 解析 | ^0.15 |
| `xpath_selector` | XPath 解析（动漫） | ^5.0 |
| `cached_network_image` | 图片加载与缓存 | ^3.0 |
| `photo_view` | 图片缩放（漫画） | ^0.15 |
| `shared_preferences` | 简单配置存储 | ^2.0 |

### 8.2 开发依赖

| 包名 | 用途 |
|---|---|
| `flutter_lints` | 代码规范 |
| `mockito` | 单元测试 mock |
| `build_runner` | 代码生成（isar） |

---

## 9. 错误处理策略

| 场景 | 处理方式 |
|---|---|
| 网络请求失败 | 自动重试3次，超时15秒，展示错误提示 + 重试按钮 |
| 源规则/脚本解析失败 | 捕获异常，跳过该源，提示用户更新规则 |
| XPath 选择器无匹配 | 返回空结果，不崩溃 |
| 视频加载失败 | 显示错误提示，提供切换分辨率/源选项 |
| 图片加载失败 | 显示占位图，点击重试 |
| 数据库操作失败 | 降级到内存缓存，提示用户 |

所有错误通过 Riverpod 的 `AsyncValue.error` 流式传递到 UI 层。

---

## 10. 测试策略

| 层级 | 测试类型 | 覆盖范围 |
|---|---|---|
| 单元测试 | 数据模型、工具函数、XPath 解析、HTML 解析 | `test/core/` |
| Widget 测试 | 通用组件（WorkCard、SearchBar、ChapterList） | `test/widgets/` |
| 集成测试 | 源适配器端到端（真实HTTP请求验证规则） | `test/integration/` |

目标：核心层覆盖率 > 80%，模块层关键路径覆盖。

---

## 11. 工作流

- 开发在 `dev` 分支进行
- 每个阶段完成后提交 commit，信息格式：`feat(module): 描述`
- 用户验收通过后，通过 PR 合并到 `main` 分支
- 先完成 Windows 平台，再适配 Android

---

## 12. 开放问题

- [ ] 阶段1需要内置哪些具体的动漫源规则？（需用户确认）
- [ ] 阶段2需要内置哪些具体的漫画源脚本？（需用户确认）
- [ ] 是否需要实现追番/追漫功能？（阶段1可先不做）
- [ ] 是否需要离线下载功能？（spec未提及，先不做）