# 轻小说界面修复与优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复哔哩轻小说文库加载失败、给 lknovel 详情提速、把轻小说首页分页改成漫画风格、并给截断的章节名加鼠标悬停滚动。

**Architecture:** 文库改用未被 Cloudflare 挑战的移动端域名 `w.linovelib.com` 并新增移动端列表解析；lknovel 详情分卷并发 6→12；首页 `_pager` 换成漫画式图标分页；新增 `MarqueeText` 组件并在 `PillButton` 与阅读器目录复用。

**Tech Stack:** Flutter/Dart 3.6、Riverpod、Dio、`package:html`。

## Global Constraints

- 运行环境：Flutter 在 `C:\flutter\bin`；命令前缀 `$env:Path = "C:\flutter\bin;$env:Path";`；工作目录 `D:\ACGNhub`。
- 每个任务结束必须：`flutter analyze lib test` 无问题 + `flutter test` 全绿。
- 每个任务结束提交并推送：`git add <精确文件>` → `git commit` → `git push origin dev`。
- 不新增依赖；不改 `pubspec.yaml`。
- 不加代码注释（与现有风格一致者除外）。中文 UI 文案。
- 排行/详情/章节仍用 `https://www.linovelib.com`；仅文库列表用 `https://w.linovelib.com`。
- 封面沿用 `novelImageHeaders`。

---

### Task 1: 文库改用移动端域名

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `test/core/novel/linovelib_browse_test.dart`
- Test: `test/core/novel/linovelib_mobile_test.dart`

**Interfaces:**
- Consumes: `novelIdFromHref`、`_absUrl`、`_textOf`（文件内已有）、`Novel`。
- Produces:
  - `const String linovelibMobileBaseUrl = 'https://w.linovelib.com'`
  - `List<Novel> parseMobileBookList(String html)`
  - `bool mobileHasNextPage(String html, int page)`
  - `LinovelibSource.browsePath(String optionKey, int page)` 现在返回**绝对 URL**：排行 → `https://www.linovelib.com/top/<key>/<page>.html`；文库 → `https://w.linovelib.com/wenku/<key>/<page>.html`。
  - `LinovelibSource.browse(String optionKey, {int page})` 用 `browsePath` 抓取；排行用 `parseRankRows`/`hasNextPage`，文库用 `parseMobileBookList`/`mobileHasNextPage`。

- [ ] **Step 1: 写移动端解析的失败测试**

创建 `test/core/novel/linovelib_mobile_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';

const _mobileHtml = '''
<ol class="book-ol book-ol-normal">
  <li class="book-li"><a href="/novel/22.html" class="book-layout">
    <div class="book-cover"><img src="x.svg" data-src="https://www.bilinovel.com/files/article/image/0/22/22s.jpg" class="lazyload" alt="加速世界"></div>
    <div class="book-cell">
      <div class="book-title-x"><h4 class="book-title">加速世界</h4></div>
      <p class="book-desc">简介</p>
      <div class="book-meta">
        <div class="book-meta-l"><span class="book-author"><svg class="icon icon-human"><title>作者</title><use xlink:href="#icon-human"></use></svg>川原砾</span></div>
        <div class="book-meta-r"><span class="tag-small-group"><em class="tag-small yellow">校园 科幻</em><em class="tag-small red">连载</em></span></div>
      </div>
    </div>
  </a></li>
</ol>
<div class="pagelink" id="pagelink"><a href="/wenku/dengekibunko/1.html" class="first">1</a><strong>1</strong><a href="/wenku/dengekibunko/2.html">2</a><a href="/wenku/dengekibunko/21.html" class="last">21</a></div>
''';

void main() {
  test('parseMobileBookList reads mobile book cards', () {
    final items = parseMobileBookList(_mobileHtml);
    expect(items, hasLength(1));
    final n = items.single;
    expect(n.id, '22');
    expect(n.title, '加速世界');
    expect(n.coverUrl, 'https://www.bilinovel.com/files/article/image/0/22/22s.jpg');
    expect(n.author, '川原砾');
    expect(n.tags, ['校园', '科幻']);
  });

  test('mobileHasNextPage uses the last page link', () {
    expect(mobileHasNextPage(_mobileHtml, 1), isTrue);
    expect(mobileHasNextPage(_mobileHtml, 20), isTrue);
    expect(mobileHasNextPage(_mobileHtml, 21), isFalse);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_mobile_test.dart`
Expected: 编译失败（`parseMobileBookList`/`mobileHasNextPage` 未定义）。

- [ ] **Step 3: 实现移动端解析与抓取**

编辑 `lib/core/novel/linovelib_source.dart`：

(a) 在 `const String linovelibBaseUrl = ...` 之后新增：

```dart
const String linovelibMobileBaseUrl = 'https://w.linovelib.com';
```

(b) 在 `parseBookList` 函数之后新增两个函数：

```dart
List<Novel> parseMobileBookList(String html) {
  final doc = html_parser.parse(html);
  final out = <Novel>[];
  for (final li in doc.querySelectorAll('ol.book-ol li.book-li')) {
    final a = li.querySelector('a.book-layout');
    final id = novelIdFromHref(a?.attributes['href']);
    if (a == null || id == null) continue;
    final img = li.querySelector('div.book-cover img');
    final cover =
        _absUrl(img?.attributes['data-src'] ?? img?.attributes['src']);
    final title = _textOf(li.querySelector('h4.book-title'));
    final authorEl = li.querySelector('span.book-author');
    authorEl?.querySelector('svg')?.remove();
    final author = _textOf(authorEl);
    final tags = <String>[];
    final tagEl = li.querySelector('em.tag-small.yellow');
    if (tagEl != null) {
      tags.addAll(_textOf(tagEl)
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty));
    }
    out.add(Novel(
      id: id,
      title: title,
      author: author.isEmpty ? null : author,
      coverUrl: cover.isEmpty ? null : cover,
      tags: tags,
      extra: {'url': '$linovelibBaseUrl/novel/$id.html'},
    ));
  }
  return out;
}

bool mobileHasNextPage(String html, int page) {
  final doc = html_parser.parse(html);
  final max = int.tryParse(_textOf(doc.querySelector('div.pagelink a.last')));
  if (max == null) return false;
  return page < max;
}
```

(c) 在 `LinovelibSource` 内、`_get` 方法之后新增绝对 URL 抓取：

```dart
  Future<String> _getUrl(String url) async {
    final res = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final data = res.data;
    if (res.statusCode != 200 || data == null) {
      throw Exception('linovelib 请求失败：$url (${res.statusCode})');
    }
    return data;
  }
```

(d) 把 `browsePath` 改为返回绝对 URL：

```dart
  static String browsePath(String optionKey, int page) =>
      rankingKeys.contains(optionKey)
          ? '$linovelibBaseUrl${rankPath(optionKey, page)}'
          : '$linovelibMobileBaseUrl/wenku/$optionKey/$page.html';
```

(e) 把 `browse` 替换为：

```dart
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async {
    final isRanking = rankingKeys.contains(optionKey);
    final html = await _getUrl(browsePath(optionKey, page));
    final items =
        isRanking ? parseRankRows(html) : parseMobileBookList(html);
    final hasMore = isRanking
        ? (hasPaginationControl(html) ? hasNextPage(html) : items.length >= 10)
        : mobileHasNextPage(html, page);
    return NovelList(items: items, page: page, hasMore: hasMore);
  }
```

- [ ] **Step 4: 更新既有 browse 测试的期望值**

编辑 `test/core/novel/linovelib_browse_test.dart`：把文件末尾两个 `browsePath` 测试（第 29–39 行）整体替换为：

```dart
  test('browsePath routes ranking keys to the www host', () {
    expect(LinovelibSource.browsePath('allvisit', 1),
        'https://www.linovelib.com/top/allvisit/1.html');
    expect(LinovelibSource.browsePath('allvisit', 2),
        'https://www.linovelib.com/top/allvisit/2.html');
  });

  test('browsePath routes bunko keys to the mobile host', () {
    expect(LinovelibSource.browsePath('dengekibunko', 2),
        'https://w.linovelib.com/wenku/dengekibunko/2.html');
  });
```

- [ ] **Step 5: 运行测试与静态检查**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/`
Expected: 全部通过。

- [ ] **Step 6: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_mobile_test.dart test/core/novel/linovelib_browse_test.dart
git commit -m "fix(novel): load linovelib bunko via the mobile host"
git push origin dev
```

---

### Task 2: lknovel 详情并发提速

**Files:**
- Modify: `lib/core/novel/lknovel_source.dart`

**Interfaces:**
- Consumes: 现有 `LknovelSource.detail`。
- Produces: `detail` 的分卷批次大小由 6 改为 12；其余不变。

- [ ] **Step 1: 改并发上限**

编辑 `lib/core/novel/lknovel_source.dart`，在 `detail` 方法内把：

```dart
    const batchSize = 6;
```

改为：

```dart
    const batchSize = 12;
```

- [ ] **Step 2: 运行静态检查与测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: 全部通过（既有「detail loads every volume and its chapters」覆盖正确性）。

- [ ] **Step 3: 提交**

```bash
git add lib/core/novel/lknovel_source.dart
git commit -m "perf(novel): raise lknovel volume-chapter concurrency"
git push origin dev
```

---

### Task 3: 首页分页改为漫画样式

**Files:**
- Modify: `lib/modules/novel/novel_home.dart`
- Modify: `test/modules/novel/novel_home_pager_test.dart`

**Interfaces:**
- Consumes: `_ExploreTabState` 现有 `_page`/`_body`。
- Produces: `_pager(bool hasMore)` 改为漫画 `_paginationBar` 风格；删除 `_pagerButtonStyle`。

- [ ] **Step 1: 更新 pager 测试**

编辑 `test/modules/novel/novel_home_pager_test.dart`，把测试体里对「上一页/下一页」文字的断言替换为对 chevron 图标的断言。把：

```dart
    await tester.pump();
    await tester.tap(find.text('排行'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('上一页'), findsOneWidget);
    expect(find.text('下一页'), findsOneWidget);
    expect(tester.takeException(), isNull);
```

替换为：

```dart
    await tester.pump();
    await tester.tap(find.text('排行'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('第 1 页'), findsOneWidget);
    expect(tester.takeException(), isNull);
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_home_pager_test.dart`
Expected: 失败（仍是「上一页/下一页」按钮，找不到 chevron 图标）。

- [ ] **Step 3: 实现新分页**

编辑 `lib/modules/novel/novel_home.dart`，删除 `_pagerButtonStyle` 静态字段，并把 `_pager` 替换为：

```dart
  Widget _pager(bool hasMore) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: '上一页',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
          ),
          const SizedBox(width: 16),
          Text('第 $_page 页',
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(width: 16),
          IconButton(
            tooltip: '下一页',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: hasMore ? () => setState(() => _page++) : null,
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: 运行测试与静态检查**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/`
Expected: 全部通过。

- [ ] **Step 5: 提交**

```bash
git add lib/modules/novel/novel_home.dart test/modules/novel/novel_home_pager_test.dart
git commit -m "feat(novel): comic-style pager on the novel home"
git push origin dev
```

---

### Task 4: 章节名悬停滚动（MarqueeText）

**Files:**
- Create: `lib/core/widgets/marquee_text.dart`
- Test: `test/core/widgets/marquee_text_test.dart`
- Modify: `lib/core/widgets/pill_button.dart`
- Modify: `lib/modules/novel/novel_reader_page.dart`

**Interfaces:**
- Produces: `class MarqueeText extends StatefulWidget { final String text; final TextStyle? style; final double gap; final double velocity; const MarqueeText({super.key, required this.text, this.style, this.gap = 40, this.velocity = 40}); }`
- Consumes（修改点）: `PillButton` 的 label、阅读器目录弹层 `ListTile.title`。

- [ ] **Step 1: 写 MarqueeText 的失败测试**

创建 `test/core/widgets/marquee_text_test.dart`：

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/widgets/marquee_text.dart';

void main() {
  testWidgets('short text renders without scrolling', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 200, child: MarqueeText(text: '短标题')),
        ),
      ),
    ));
    expect(find.text('短标题'), findsOneWidget);
    expect(
      find.descendant(
          of: find.byType(MarqueeText), matching: find.byType(MouseRegion)),
      findsNothing,
    );
  });

  testWidgets('long text scrolls while hovered', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 80,
            child: MarqueeText(text: '这是一个非常非常非常长的章节名字需要滚动显示完整'),
          ),
        ),
      ),
    ));
    expect(
      find.descendant(
          of: find.byType(MarqueeText), matching: find.byType(MouseRegion)),
      findsOneWidget,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(MarqueeText)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final transform = tester.widget<Transform>(find.descendant(
      of: find.byType(MarqueeText),
      matching: find.byType(Transform),
    ));
    expect(transform.transform.getTranslation().x, lessThan(0));
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/widgets/marquee_text_test.dart`
Expected: 编译失败（`marquee_text.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/core/widgets/marquee_text.dart`**

```dart
import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double gap;
  final double velocity;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.gap = 40,
    this.velocity = 40,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start(double overflow) {
    final distance = overflow + widget.gap;
    final ms = (distance / widget.velocity * 1000).round();
    _controller.duration = Duration(milliseconds: ms.clamp(400, 60000));
    _controller.repeat();
  }

  void _stop() {
    _controller.stop();
    _controller.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final overflow = painter.width - maxWidth;
        if (!maxWidth.isFinite || overflow <= 0) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }
        return ClipRect(
          child: MouseRegion(
            onEnter: (_) => _start(overflow),
            onExit: (_) => _stop(),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Transform.translate(
                offset:
                    Offset(-_controller.value * (overflow + widget.gap), 0),
                child: Text(
                  widget.text,
                  maxLines: 1,
                  softWrap: false,
                  style: style,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/widgets/marquee_text_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 在 PillButton 与阅读器目录应用**

编辑 `lib/core/widgets/pill_button.dart`：加 import

```dart
import 'marquee_text.dart';
```

把 `child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(...))` 替换为：

```dart
          child: MarqueeText(
            text: label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1C1C1E),
            ),
          ),
```

编辑 `lib/modules/novel/novel_reader_page.dart`：加 import

```dart
import '../../core/widgets/marquee_text.dart';
```

把目录弹层里：

```dart
                    title: Text(c.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
```

替换为：

```dart
                    title: MarqueeText(text: c.title),
```

- [ ] **Step 6: 运行静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/core/widgets/marquee_text.dart test/core/widgets/marquee_text_test.dart lib/core/widgets/pill_button.dart lib/modules/novel/novel_reader_page.dart
git commit -m "feat(novel): hover-scroll truncated chapter names"
git push origin dev
```

---

## 验证（任务全部完成后）

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` 全绿。
2. 构建并启动应用，切到轻小说模块：
   - 哔哩轻小说 →「文库」：任选文库可加载出书籍网格，翻页正常。
   - 轻之国度 → 打开一本书详情明显更快（并发 12）。
   - 首页底部分页是 `‹ 第 X 页 ›` 图标样式。
   - 详情页章节 pill 与阅读器目录里，鼠标悬停在被截断的章节名上会水平滚动显示完整文字，移出复位。

## 已知取舍

- lknovel 仍为「1 + N 次请求」，仅提高并发；未做目录懒加载或持久缓存。
- `PillButton` 的改动会同时影响动漫剧集按钮/漫画章节按钮（仅在悬停 + 溢出时滚动，非溢出时行为不变）。
