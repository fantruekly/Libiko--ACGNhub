# 游戏首页分页密度（48/页）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让游戏首页每个 App 页显示 48 个游戏（6 列 × 8 行，非末页无空格），做法是每页抓取 4 个源站页再拼接裁剪。

**Architecture:** 只改 `GalgameZywzSource.browse`：按偏移抓取源站第 `4N-3..4N` 页，拼接后裁剪到 48；遇到「无下一页」提前停止。UI 网格与分页按钮不变。

**Tech Stack:** Flutter (Dart 3.6)、dio、html（均已有，无新增依赖）。

## Global Constraints

- 仅改动游戏模块；不改网格列数、卡片、分区 chip、详情页。
- 无新增依赖。
- 不添加代码注释（除非下方给定代码已含）。
- 在 `dev` 分支开发；完成后提交。
- 测试命令：`C:\flutter\bin\flutter.bat test <path>`；静态检查：`C:\flutter\bin\flutter.bat analyze`。

---

## Task 1: 48/页 分页抓取

**Files:**
- Modify: `lib/core/game/galgamezywz_source.dart`
- Test: `test/core/game/galgamezywz_source_test.dart`

**Interfaces:**
- Consumes: 现有 `parseGameList` / `parseHasNextPage` / `galgameZywzBrowsePath` / `GameList`。
- Produces: 常量 `galgameZywzPageSize`（48）、`galgameZywzSourcePageSize`（12）；改写后的 `GalgameZywzSource.browse(String optionKey, {int page = 1})` 返回每页最多 48 个。

- [ ] **Step 1: 更新测试（先失败）**

在 `test/core/game/galgamezywz_source_test.dart` 中：

1) 删除现有的 `_listHtml` 常量（第 7–18 行那一整段），替换为下面的辅助函数（放在 `_detailHtml` 之前或之后均可）：

```dart
String _listHtmlWith(int count, {String? next, String idPrefix = 'g'}) {
  final items = StringBuffer();
  for (var i = 0; i < count; i++) {
    items.write(
        '<article class="post-item item-grid">'
        '<a class="media-img" href="/game/$idPrefix$i" data-bg="https://game.galgamezywz.org/wp-content/uploads/$idPrefix$i.jpg"></a>'
        '<h2 class="entry-title"><a href="/game/$idPrefix$i">游戏$idPrefix$i</a></h2>'
        '</article>');
  }
  final nav = next == null
      ? '<nav class="page-nav"><ul class="pagination">'
          '<li class="page-item disabled"><span class="page-link">N/N</span></li>'
          '</ul></nav>'
      : '<nav class="page-nav"><ul class="pagination">'
          '<li class="page-item"><a class="page-link page-next" href="$next">下一页</a></li>'
          '</ul></nav>';
  return '<div class="posts-warp">$items</div>$nav';
}
```

2) 删除现有的第一个测试 `test('browse requests the option path and parses the list', ...)`（第 52–64 行），替换为以下 4 个测试：

```dart
  test('browse page 1 requests four source pages and returns 48', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/lm/galgame':
          _listHtmlWith(12, next: '/lm/galgame/page/2', idPrefix: 'a'),
      '/lm/galgame/page/2':
          _listHtmlWith(12, next: '/lm/galgame/page/3', idPrefix: 'b'),
      '/lm/galgame/page/3':
          _listHtmlWith(12, next: '/lm/galgame/page/4', idPrefix: 'c'),
      '/lm/galgame/page/4':
          _listHtmlWith(12, next: '/lm/galgame/page/5', idPrefix: 'd'),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 1);
    expect(adapter.requested, [
      '/lm/galgame',
      '/lm/galgame/page/2',
      '/lm/galgame/page/3',
      '/lm/galgame/page/4',
    ]);
    expect(list.items, hasLength(48));
    expect(list.items.first.id, 'a0');
    expect(list.items.last.id, 'd11');
    expect(list.page, 1);
    expect(list.hasMore, isTrue);
  });

  test('browse page 2 requests the next four source pages', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/lm/galgame/page/5':
          _listHtmlWith(12, next: '/lm/galgame/page/6', idPrefix: 'e'),
      '/lm/galgame/page/6':
          _listHtmlWith(12, next: '/lm/galgame/page/7', idPrefix: 'f'),
      '/lm/galgame/page/7':
          _listHtmlWith(12, next: '/lm/galgame/page/8', idPrefix: 'g'),
      '/lm/galgame/page/8':
          _listHtmlWith(12, next: '/lm/galgame/page/9', idPrefix: 'h'),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 2);
    expect(adapter.requested, [
      '/lm/galgame/page/5',
      '/lm/galgame/page/6',
      '/lm/galgame/page/7',
      '/lm/galgame/page/8',
    ]);
    expect(list.items, hasLength(48));
    expect(list.items.first.id, 'e0');
    expect(list.page, 2);
    expect(list.hasMore, isTrue);
  });

  test('browse stops early when a source page has no next link', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/lm/galgame':
          _listHtmlWith(12, next: '/lm/galgame/page/2', idPrefix: 'a'),
      '/lm/galgame/page/2': _listHtmlWith(12, idPrefix: 'b'),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 1);
    expect(adapter.requested, ['/lm/galgame', '/lm/galgame/page/2']);
    expect(list.items, hasLength(24));
    expect(list.hasMore, isFalse);
  });

  test('browse trims a 52-item page to 48', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/': _listHtmlWith(16, next: '/page/2', idPrefix: 's'),
      '/page/2': _listHtmlWith(12, next: '/page/3', idPrefix: 't'),
      '/page/3': _listHtmlWith(12, next: '/page/4', idPrefix: 'u'),
      '/page/4': _listHtmlWith(12, next: '/page/5', idPrefix: 'v'),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('latest', page: 1);
    expect(adapter.requested, ['/', '/page/2', '/page/3', '/page/4']);
    expect(list.items, hasLength(48));
    expect(list.items.first.id, 's0');
    expect(list.items.last.id, 'u11');
    expect(list.hasMore, isTrue);
  });
```

其余两个测试（`detail ...`、`exposes identity ...`）保持不变。

- [ ] **Step 2: 运行测试确认失败**

Run: `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_source_test.dart`
Expected: FAIL —— 当前 `browse` 每页只抓 1 个源页，`adapter.requested` 只有 1 项，`items` 只有 12/16 个，与断言不符。

- [ ] **Step 3: 实现**

在 `lib/core/game/galgamezywz_source.dart` 的常量区（`gameImageHeaders` 之后）加入：

```dart
const int galgameZywzPageSize = 48;
const int galgameZywzSourcePageSize = 12;
```

把 `GalgameZywzSource.browse` 整体替换为：

```dart
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async {
    final pagesPerApp =
        (galgameZywzPageSize / galgameZywzSourcePageSize).ceil();
    final startServer = (page - 1) * pagesPerApp + 1;
    final items = <Game>[];
    var hasMore = false;
    for (var i = 0; i < pagesPerApp; i++) {
      final serverPage = startServer + i;
      final String html;
      try {
        html = await _get(galgameZywzBrowsePath(optionKey, serverPage));
      } catch (_) {
        if (i == 0) rethrow;
        break;
      }
      final pageItems = parseGameList(html);
      if (pageItems.isEmpty) {
        hasMore = false;
        break;
      }
      items.addAll(pageItems);
      hasMore = parseHasNextPage(html, itemCount: pageItems.length);
      if (!hasMore) break;
    }
    final trimmed = items.length > galgameZywzPageSize
        ? items.sublist(0, galgameZywzPageSize)
        : items;
    return GameList(items: trimmed, page: page, hasMore: hasMore);
  }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_source_test.dart`
Expected: PASS（6 tests：4 新增 + detail + identity）。

同时跑解析测试与游戏首页测试确认无回归：
`C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_parser_test.dart`
`C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
Expected: 均 PASS。

- [ ] **Step 5: 静态检查 + 提交**

Run: `C:\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

```bash
git add lib/core/game/galgamezywz_source.dart test/core/game/galgamezywz_source_test.dart
git commit -m "feat(game): show 48 games per home page"
```

---

## 手动验证（合并前，由用户执行）

在 Windows 上运行应用，进入「游戏」Tab：
1. 首页每页约 48 个（6 列 8 行），非末页没有空行。
2. 「下一页」翻到第 2 页，内容不重复。
3. 各分区（最近更新/玩家热评/资源推荐/好游推荐/玩家最爱）都能正常翻页。
4. 翻到最后一页时「下一页」禁用。

## 自查记录（Self-Review）

- **Spec 覆盖**：常量、`browse` 改写、提前停止、裁剪、测试均在 Task 1 内。
- **类型一致性**：`galgameZywzPageSize`/`galgameZywzSourcePageSize` 为 `int`；`browse` 返回 `GameList(items, page, hasMore)` 与 `GameSource` 接口一致；测试用 `list.items.first.id` 等现有 `Game` 字段。
- **占位符**：无 TBD/TODO；测试与实现均为完整代码。
- **注意**：现有 `browse requests the option path...` 测试会因行为变化而失效，Step 1 已明确替换它。
