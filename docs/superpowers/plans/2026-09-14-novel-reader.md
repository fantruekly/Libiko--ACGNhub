# 轻小说阅读器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 点章节进入正文阅读器：抓取/清洗 linovelib 章节正文（含同章分页拼接），支持上一/下一章、目录跳转、阅读设置（字号/行距/主题）。

**Architecture:** `lib/core/novel/` 加章节解析函数与阅读设置；`LinovelibSource.chapter()` 抓取并拼接同章分页；`lib/modules/novel/` 加 `novelChapterProvider`、`flattenChapters` 与 `NovelReaderPage`，并把详情页章节点击接到阅读器。

**Tech Stack:** Flutter（Windows）、Riverpod 2.6、`dio`、`html`；**不引入新依赖**。

## Global Constraints

- `environment.sdk >=3.6.0`；`flutter_riverpod ^2.6.1`；`dio ^5.7.0`；`html ^0.15.5`。**不新增依赖。**
- 平台：Windows 桌面。
- 源：`https://www.linovelib.com`，UTF-8；`LinovelibSource._get` 已带 UA/`Accept`/`Accept-Language`/`Referer`，超时 20s。
- 设计色：accent `0xFF007AFF`、fg `0xFF1C1C1E`、muted `0xFF5A5A5F`。
- **`TextStyle` 里不要设 `fontFamily`**（全局 `NotoSansSC`）。
- 复用共享组件：`EmptyState`、`smoothRoute`。
- 每个 task 收尾：`flutter analyze lib test` 无问题、`flutter test` 全绿，然后 `git add` 指定文件 + `git commit` + `git push`。
- 命令前缀（PowerShell）：`$env:Path = "C:\flutter\bin;$env:Path";`
- 交流用中文。

## File Structure

- Modify `lib/core/novel/linovelib_source.dart` — 加 `parseChapter`/`nextPageHref`/`fetchChapterPages`；实现 `LinovelibSource.chapter`。
- Create `lib/core/novel/novel_reader_settings.dart` — 阅读设置模型 + manager + provider。
- Modify `lib/modules/novel/novel_providers.dart` — 加 `novelChapterProvider`、`flattenChapters`。
- Create `lib/modules/novel/novel_reader_page.dart` — `NovelReaderPage`。
- Modify `lib/modules/novel/novel_detail_page.dart` — 章节点击接阅读器。
- Test: `test/core/novel/linovelib_chapter_parser_test.dart`、`test/core/novel/novel_reader_settings_test.dart`、`test/modules/novel/novel_reader_page_test.dart`。

---

### Task 1: 章节解析函数

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Test: `test/core/novel/linovelib_chapter_parser_test.dart`

**Interfaces:**
- Consumes: `models.dart` 的 `NovelChapter { String title; String content; }`（已存在）。
- Produces（`linovelib_source.dart` 顶层函数）：
  - `NovelChapter parseChapter(String html, String fallbackTitle)` — 标题 `#mlfy_main_text h1`（回退 `fallbackTitle`）；正文取 `div#TextContent` 的 `<p>`，按 `\n\n` 连接。
  - `String? nextPageHref(String html, String novelId, String chapterId)` — `div.mlfy_page` 里「下一页」`<a>` 的 href，仅当形如 `/novel/<novelId>/<chapterId>_<n>.html` 时返回，否则 `null`。
  - `Future<NovelChapter> fetchChapterPages({required String novelId, required String chapterId, required Future<String> Function(String path) fetch, int maxPages = 50})` — 抓首页 + 循环拼接同章分页。

- [ ] **Step 1: 写失败测试（含 fixture）**

`test/core/novel/linovelib_chapter_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';

const _pagedHtml = '''
<div id="mlfy_main_text"><h1>第60話 規則（2）</h1>
<div id="TextContent" class="TextContent"><p>第一段。</p><br><p>第二段。</p><br><p>第三段。</p></div></div>
<div class="mlfy_page"><a href="/novel/5340/334299.html">上一页</a><a href="/novel/5340/catalog">目录</a><a href="/novel/5340/334356_2.html">下一页</a></div>
''';

const _lastPageHtml = '''
<div id="mlfy_main_text"><h1>第60話 規則（2）</h1>
<div id="TextContent"><p>末段。</p></div></div>
<div class="mlfy_page"><a href="/novel/5340/334356_1.html">上一页</a><a href="/novel/5340/334357.html">下一页</a></div>
''';

void main() {
  test('parseChapter reads title and paragraphs', () {
    final ch = parseChapter(_pagedHtml, 'FB');
    expect(ch.title, '第60話 規則（2）');
    expect(ch.content, '第一段。\n\n第二段。\n\n第三段。');
  });

  test('parseChapter falls back to the given title', () {
    final ch = parseChapter('<div id="TextContent"><p>只有正文</p></div>', '备用标题');
    expect(ch.title, '备用标题');
    expect(ch.content, '只有正文');
  });

  test('nextPageHref returns same-chapter page links only', () {
    expect(nextPageHref(_pagedHtml, '5340', '334356'), '/novel/5340/334356_2.html');
    expect(nextPageHref(_lastPageHtml, '5340', '334356'), isNull); // next chapter
    expect(nextPageHref('<div class="mlfy_page"></div>', '5340', '334356'), isNull);
  });

  test('fetchChapterPages concatenates same-chapter pages', () async {
    final pages = {
      '/novel/5340/334356.html': _pagedHtml,
      '/novel/5340/334356_2.html': _lastPageHtml,
    };
    var calls = 0;
    final ch = await fetchChapterPages(
      novelId: '5340',
      chapterId: '334356',
      fetch: (path) async {
        calls++;
        return pages[path]!;
      },
    );
    expect(calls, 2);
    expect(ch.content, '第一段。\n\n第二段。\n\n第三段。\n\n末段。');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_chapter_parser_test.dart`
Expected: FAIL（`parseChapter` 未定义）

- [ ] **Step 3: 实现**

在 `linovelib_source.dart` 的 `parseCatalog` 之后追加：

```dart
NovelChapter parseChapter(String html, String fallbackTitle) {
  final doc = html_parser.parse(html);
  final title = _textOf(doc.querySelector('#mlfy_main_text h1'));
  final paragraphs = <String>[];
  final content = doc.querySelector('div#TextContent');
  if (content != null) {
    for (final p in content.querySelectorAll('p')) {
      final t = p.text.trim();
      if (t.isNotEmpty) paragraphs.add(t);
    }
  }
  return NovelChapter(
    title: title.isEmpty ? fallbackTitle : title,
    content: paragraphs.join('\n\n'),
  );
}

String? nextPageHref(String html, String novelId, String chapterId) {
  final doc = html_parser.parse(html);
  final prefix = '/novel/$novelId/${chapterId}_';
  for (final a in doc.querySelectorAll('div.mlfy_page a')) {
    if (a.text.trim() != '下一页') continue;
    final href = a.attributes['href'];
    if (href != null && href.startsWith(prefix) && href.endsWith('.html')) {
      return href;
    }
    return null;
  }
  return null;
}

Future<NovelChapter> fetchChapterPages({
  required String novelId,
  required String chapterId,
  required Future<String> Function(String path) fetch,
  int maxPages = 50,
}) async {
  final firstHtml = await fetch('/novel/$novelId/$chapterId.html');
  final first = parseChapter(firstHtml, '');
  final buffer = <String>[if (first.content.isNotEmpty) first.content];
  var next = nextPageHref(firstHtml, novelId, chapterId);
  var pages = 1;
  while (next != null && pages < maxPages) {
    final html = await fetch(next);
    final page = parseChapter(html, '');
    if (page.content.isNotEmpty) buffer.add(page.content);
    next = nextPageHref(html, novelId, chapterId);
    pages++;
  }
  return NovelChapter(title: first.title, content: buffer.join('\n\n'));
}
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_chapter_parser_test.dart`
Expected: PASS（4 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_chapter_parser_test.dart
git commit -m "feat(novel): add chapter parsers (paragraphs + same-chapter paging)"
git push
```

---

### Task 2: `LinovelibSource.chapter`

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Test: `test/core/novel/linovelib_source_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `fetchChapterPages`。
- Produces: `Future<NovelChapter> LinovelibSource.chapter(String novelId, String chapterId)`（替换现有 `UnimplementedError`），内部调用 `fetchChapterPages(fetch: _get)`。

- [ ] **Step 1: 写失败测试（路径助手）**

在 `test/core/novel/linovelib_source_test.dart` 追加：

```dart
  test('chapterPath builds the chapter url', () {
    expect(LinovelibSource.chapterPath('5340', '334356'), '/novel/5340/334356.html');
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: FAIL（`chapterPath` 未定义）

- [ ] **Step 3: 实现**

在 `LinovelibSource` 里，把 `chapter` 的 `throw UnimplementedError()` 替换为：

```dart
  static String chapterPath(String novelId, String chapterId) =>
      '/novel/$novelId/$chapterId.html';

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) =>
      fetchChapterPages(novelId: novelId, chapterId: chapterId, fetch: _get);
```

（`_get` 接收一个 path 字符串，签名与 `fetch` 参数一致。）

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_source_test.dart
git commit -m "feat(novel): implement LinovelibSource.chapter"
git push
```

---

### Task 3: 阅读设置

**Files:**
- Create: `lib/core/novel/novel_reader_settings.dart`
- Test: `test/core/novel/novel_reader_settings_test.dart`

**Interfaces:**
- Produces:
  - `enum NovelReaderTheme { light, sepia, dark }`。
  - `NovelReaderSettings { double fontSize; double lineHeight; NovelReaderTheme theme; }`，默认 `17 / 1.8 / light`；`copyWith`；`fromJson`/`toJson`（`fontSize` clamp 12–28、`lineHeight` clamp 1.2–2.6）。
  - `NovelReaderSettingsManager { NovelReaderSettings read(); Future<void> write(NovelReaderSettings s); }`，key `novel_reader_settings`。
  - `NovelReaderSettingsNotifier extends Notifier<NovelReaderSettings>`，方法 `setFontSize`/`setLineHeight`/`setTheme`。
  - `final novelReaderSettingsProvider = NotifierProvider<NovelReaderSettingsNotifier, NovelReaderSettings>(NovelReaderSettingsNotifier.new);`

- [ ] **Step 1: 写失败测试（纯模型）**

`test/core/novel/novel_reader_settings_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/novel_reader_settings.dart';

void main() {
  test('defaults', () {
    const s = NovelReaderSettings();
    expect(s.fontSize, 17);
    expect(s.lineHeight, 1.8);
    expect(s.theme, NovelReaderTheme.light);
  });

  test('copyWith changes one field', () {
    const s = NovelReaderSettings();
    final s2 = s.copyWith(fontSize: 22, theme: NovelReaderTheme.dark);
    expect(s2.fontSize, 22);
    expect(s2.theme, NovelReaderTheme.dark);
    expect(s2.lineHeight, 1.8);
  });

  test('round-trips through JSON and clamps out-of-range values', () {
    final decoded = NovelReaderSettings.fromJson(
      json.decode(json.encode(const NovelReaderSettings(fontSize: 22).toJson()))
          as Map<String, dynamic>,
    );
    expect(decoded.fontSize, 22);

    final clamped = NovelReaderSettings.fromJson(const {
      'fontSize': 99,
      'lineHeight': 0.1,
      'theme': 'sepia',
    });
    expect(clamped.fontSize, 28);
    expect(clamped.lineHeight, 1.2);
    expect(clamped.theme, NovelReaderTheme.sepia);
  });

  test('unknown theme falls back to light', () {
    final s = NovelReaderSettings.fromJson(const {'theme': 'weird'});
    expect(s.theme, NovelReaderTheme.light);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_reader_settings_test.dart`
Expected: FAIL（文件不存在）

- [ ] **Step 3: 实现 `lib/core/novel/novel_reader_settings.dart`**

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

enum NovelReaderTheme { light, sepia, dark }

class NovelReaderSettings {
  final double fontSize;
  final double lineHeight;
  final NovelReaderTheme theme;

  const NovelReaderSettings({
    this.fontSize = 17,
    this.lineHeight = 1.8,
    this.theme = NovelReaderTheme.light,
  });

  NovelReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    NovelReaderTheme? theme,
  }) =>
      NovelReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        theme: theme ?? this.theme,
      );

  factory NovelReaderSettings.fromJson(Map<String, dynamic> json) =>
      NovelReaderSettings(
        fontSize: ((json['fontSize'] as num?)?.toDouble() ?? 17)
            .clamp(12, 28)
            .toDouble(),
        lineHeight: ((json['lineHeight'] as num?)?.toDouble() ?? 1.8)
            .clamp(1.2, 2.6)
            .toDouble(),
        theme: NovelReaderTheme.values.firstWhere(
          (t) => t.name == json['theme'],
          orElse: () => NovelReaderTheme.light,
        ),
      );

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'theme': theme.name,
      };
}

class NovelReaderSettingsManager {
  static const _key = 'novel_reader_settings';

  NovelReaderSettings read() {
    final raw = AppDatabase().getString(_key);
    if (raw == null || raw.isEmpty) return const NovelReaderSettings();
    try {
      return NovelReaderSettings.fromJson(
          json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const NovelReaderSettings();
    }
  }

  Future<void> write(NovelReaderSettings settings) async {
    await AppDatabase().setString(_key, json.encode(settings.toJson()));
  }
}

class NovelReaderSettingsNotifier extends Notifier<NovelReaderSettings> {
  final _manager = NovelReaderSettingsManager();

  @override
  NovelReaderSettings build() => _manager.read();

  Future<void> _update(NovelReaderSettings next) async {
    await _manager.write(next);
    state = next;
  }

  Future<void> setFontSize(double value) =>
      _update(state.copyWith(fontSize: value.clamp(12, 28).toDouble()));

  Future<void> setLineHeight(double value) =>
      _update(state.copyWith(lineHeight: value.clamp(1.2, 2.6).toDouble()));

  Future<void> setTheme(NovelReaderTheme theme) =>
      _update(state.copyWith(theme: theme));
}

final novelReaderSettingsProvider =
    NotifierProvider<NovelReaderSettingsNotifier, NovelReaderSettings>(
        NovelReaderSettingsNotifier.new);
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_reader_settings_test.dart`
Expected: PASS（4 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/novel_reader_settings.dart test/core/novel/novel_reader_settings_test.dart
git commit -m "feat(novel): add reader settings (font/line-height/theme)"
git push
```

---

### Task 4: providers

**Files:**
- Modify: `lib/modules/novel/novel_providers.dart`
- Test: `test/modules/novel/novel_providers_test.dart`

**Interfaces:**
- Consumes: `novelSourceManagerProvider`；`NovelSource.chapter`；`NovelDetail`/`NovelChapterRef`。
- Produces:
  - `final novelChapterProvider = FutureProvider.family<NovelChapter, (String, String, String)>((ref, key) async { ... })`，key = `(sourceId, novelId, chapterId)`；source 不存在抛 `StateError`。
  - `List<NovelChapterRef> flattenChapters(NovelDetail detail)`。

- [ ] **Step 1: 写失败测试**

在 `test/modules/novel/novel_providers_test.dart` 追加：

```dart
  test('flattenChapters flattens volumes in order', () {
    const detail = NovelDetail(
      novel: Novel(id: '1', title: 'T'),
      volumes: [
        NovelVolume(title: 'v1', chapters: [
          NovelChapterRef(id: 'a', title: 'A'),
          NovelChapterRef(id: 'b', title: 'B'),
        ]),
        NovelVolume(title: 'v2', chapters: [
          NovelChapterRef(id: 'c', title: 'C'),
        ]),
      ],
    );
    expect(flattenChapters(detail).map((c) => c.id), ['a', 'b', 'c']);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart`
Expected: FAIL（`flattenChapters` 未定义）

- [ ] **Step 3: 实现**

在 `novel_providers.dart` 末尾追加：

```dart
/// 按分卷顺序扁平化章节（供阅读器上一/下一章与目录使用）。
List<NovelChapterRef> flattenChapters(NovelDetail detail) =>
    [for (final volume in detail.volumes) ...volume.chapters];

final novelChapterProvider =
    FutureProvider.family<NovelChapter, (String, String, String)>(
        (ref, key) async {
  final (sourceId, novelId, chapterId) = key;
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.chapter(novelId, chapterId);
});
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/modules/novel/novel_providers.dart test/modules/novel/novel_providers_test.dart
git commit -m "feat(novel): add novelChapterProvider and flattenChapters"
git push
```

---

### Task 5: 阅读器页面 + 接线

**Files:**
- Create: `lib/modules/novel/novel_reader_page.dart`
- Modify: `lib/modules/novel/novel_detail_page.dart`
- Test: `test/modules/novel/novel_reader_page_test.dart`

**Interfaces:**
- Consumes: Task 3 的 `novelReaderSettingsProvider`/`NovelReaderTheme`；Task 4 的 `novelChapterProvider`/`flattenChapters`；`novelDetailProvider`；`EmptyState`；`smoothRoute`。
- Produces: `class NovelReaderPage extends ConsumerStatefulWidget { final String sourceKey; final String novelId; final String chapterId; final String title; }`。

- [ ] **Step 1: 写失败测试**

`test/modules/novel/novel_reader_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';
import 'package:acgnhub/modules/novel/novel_reader_page.dart';

void main() {
  testWidgets('NovelReaderPage renders the chapter title and paragraphs',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelChapterProvider(('linovelib', '5340', '334356'))
            .overrideWith((ref) async =>
                const NovelChapter(title: '第60話', content: '第一段。\n\n第二段。')),
        // Avoid a real network call from the reader's chapter list lookup.
        novelDetailProvider(('linovelib', '5340')).overrideWith((ref) async =>
            const NovelDetail(
                novel: Novel(id: '5340', title: '书名'), volumes: [])),
      ],
      child: const MaterialApp(
        home: NovelReaderPage(
            sourceKey: 'linovelib',
            novelId: '5340',
            chapterId: '334356',
            title: '书名'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('第60話'), findsOneWidget);
    expect(find.text('第一段。'), findsOneWidget);
    expect(find.text('第二段。'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_reader_page_test.dart`
Expected: FAIL（`novel_reader_page.dart` 不存在）

- [ ] **Step 3: 实现 `lib/modules/novel/novel_reader_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/novel/models.dart';
import '../../core/novel/novel_reader_settings.dart';
import '../../core/widgets/empty_state.dart';
import 'novel_providers.dart';

const _accent = Color(0xFF007AFF);

class _Palette {
  final Color bg;
  final Color fg;
  final Color bar;
  final Color border;
  const _Palette(this.bg, this.fg, this.bar, this.border);

  static _Palette of(NovelReaderTheme theme) => switch (theme) {
        NovelReaderTheme.light => const _Palette(
            Color(0xFFFFFFFF), Color(0xFF1C1C1E), Color(0xFFFFFFFF), Color(0xFFE5E5EA)),
        NovelReaderTheme.sepia => const _Palette(
            Color(0xFFF5EFE0), Color(0xFF3B3226), Color(0xFFEFE6D2), Color(0xFFE0D5BC)),
        NovelReaderTheme.dark => const _Palette(
            Color(0xFF1C1C1E), Color(0xFFD8D8DC), Color(0xFF2C2C2E), Color(0xFF3A3A3C)),
      };
}

class NovelReaderPage extends ConsumerStatefulWidget {
  final String sourceKey;
  final String novelId;
  final String chapterId;
  final String title;
  const NovelReaderPage({
    super.key,
    required this.sourceKey,
    required this.novelId,
    required this.chapterId,
    required this.title,
  });

  @override
  ConsumerState<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends ConsumerState<NovelReaderPage> {
  late String _chapterId = widget.chapterId;
  bool _chromeVisible = true;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(novelReaderSettingsProvider);
    final palette = _Palette.of(settings.theme);
    final chapters = _chapters();
    final async =
        ref.watch(novelChapterProvider((widget.sourceKey, widget.novelId, _chapterId)));
    final index = chapters.indexWhere((c) => c.id == _chapterId);

    return Scaffold(
      backgroundColor: palette.bg,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _chromeVisible = !_chromeVisible),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => EmptyState(
                icon: Icons.cloud_off_rounded,
                message: '加载失败',
                actionLabel: '重试',
                onAction: () => ref.invalidate(novelChapterProvider(
                    (widget.sourceKey, widget.novelId, _chapterId))),
              ),
              data: (chapter) => _content(chapter, settings, palette),
            ),
          ),
          if (_chromeVisible) _topBar(palette, chapters, index),
          if (_chromeVisible) _bottomBar(palette, chapters, index),
        ],
      ),
    );
  }

  List<NovelChapterRef> _chapters() {
    final detail = ref
        .watch(novelDetailProvider((widget.sourceKey, widget.novelId)))
        .valueOrNull;
    return detail == null ? const [] : flattenChapters(detail);
  }

  Widget _content(
      NovelChapter chapter, NovelReaderSettings settings, _Palette palette) {
    final paragraphs = chapter.content
        .split('\n\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (paragraphs.isEmpty)
            Text('本章暂无内容',
                style: TextStyle(
                    fontSize: settings.fontSize, color: palette.fg.withValues(alpha: 0.5)))
          else
            for (final p in paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  p,
                  style: TextStyle(
                    fontSize: settings.fontSize,
                    height: settings.lineHeight,
                    color: palette.fg,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _topBar(_Palette palette, List<NovelChapterRef> chapters, int index) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: palette.bar,
          border: Border(bottom: BorderSide(color: palette.border, width: 0.5)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: palette.fg,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.fg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(_Palette palette, List<NovelChapterRef> chapters, int index) {
    final hasPrev = index > 0;
    final hasNext = index >= 0 && index < chapters.length - 1;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: palette.bar,
          border: Border(top: BorderSide(color: palette.border, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _barButton(palette, Icons.chevron_left_rounded, '上一章',
                hasPrev ? () => _goChapter(chapters[index - 1].id) : null),
            _barButton(palette, Icons.list_rounded, '目录', () => _openCatalog(chapters)),
            _barButton(palette, Icons.text_fields_rounded, '设置', _openSettings),
            _barButton(palette, Icons.chevron_right_rounded, '下一章',
                hasNext ? () => _goChapter(chapters[index + 1].id) : null),
          ],
        ),
      ),
    );
  }

  Widget _barButton(
      _Palette palette, IconData icon, String label, VoidCallback? onTap) {
    final color = onTap == null ? palette.fg.withValues(alpha: 0.3) : palette.fg;
    return TextButton(
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  void _goChapter(String chapterId) {
    setState(() => _chapterId = chapterId);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _openCatalog(List<NovelChapterRef> chapters) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        children: [
          for (final c in chapters)
            ListTile(
              dense: true,
              title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: c.id == _chapterId
                  ? const Icon(Icons.check_rounded, size: 18, color: _accent)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (c.id != _chapterId) _goChapter(c.id);
              },
            ),
        ],
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _ReaderSettingsSheet(),
    );
  }
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(novelReaderSettingsProvider);
    final notifier = ref.read(novelReaderSettingsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('字号', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Row(
            children: [
              IconButton(
                onPressed: settings.fontSize > 12
                    ? () => notifier.setFontSize(settings.fontSize - 1)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Text('${settings.fontSize.round()}', style: const TextStyle(fontSize: 15)),
              IconButton(
                onPressed: settings.fontSize < 28
                    ? () => notifier.setFontSize(settings.fontSize + 1)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('行距', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Row(
            children: [
              IconButton(
                onPressed: settings.lineHeight > 1.2
                    ? () => notifier.setLineHeight(settings.lineHeight - 0.1)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Text(settings.lineHeight.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 15)),
              IconButton(
                onPressed: settings.lineHeight < 2.6
                    ? () => notifier.setLineHeight(settings.lineHeight + 0.1)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('主题', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final t in NovelReaderTheme.values)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(switch (t) {
                      NovelReaderTheme.light => '浅色',
                      NovelReaderTheme.sepia => '米色',
                      NovelReaderTheme.dark => '深色',
                    }),
                    selected: settings.theme == t,
                    showCheckmark: false,
                    onSelected: (_) => notifier.setTheme(t),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_reader_page_test.dart`
Expected: PASS

- [ ] **Step 5: 详情页章节点击接阅读器**

在 `lib/modules/novel/novel_detail_page.dart`：
- 顶部加 `import '../../core/widgets/smooth_route.dart';` 与 `import 'novel_reader_page.dart';`。
- 把 `PillButton(label: ch.title, onTap: () => _openChapter())` 改为传入章节 id，并把 `_openChapter` 改为跳转：

```dart
                  PillButton(
                    label: ch.title,
                    onTap: () => _openChapter(ch),
                  ),
```

```dart
  void _openChapter(NovelChapterRef chapter) {
    Navigator.push(
      context,
      smoothRoute(NovelReaderPage(
        sourceKey: widget.sourceKey,
        novelId: widget.novelId,
        chapterId: chapter.id,
        title: widget.title,
      )),
    );
  }
```

（删除原 `_openChapter()` 里的 SnackBar；`NovelChapterRef` 已由 `models.dart` 导入。）

- [ ] **Step 6: 全量校验 + 手动验证**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过

```powershell
$env:Path = "C:\flutter\bin;$env:Path"
flutter build windows --debug
Start-Process -FilePath "D:\ACGNhub\build\windows\x64\runner\Debug\acgnhub.exe" -WorkingDirectory "D:\ACGNhub\build\windows\x64\runner\Debug"
```

轻小说 → 卡片进详情 → 点章节 → 确认正文显示、可上一/下一章、目录、设置（字号/行距/主题）生效。

- [ ] **Step 7: 提交**

```bash
git add lib/modules/novel/novel_reader_page.dart lib/modules/novel/novel_detail_page.dart test/modules/novel/novel_reader_page_test.dart
git commit -m "feat(novel): add reader page and wire detail chapter taps"
git push
```

---

## Self-Review

**Spec coverage:**
- `parseChapter`/`nextPageHref`/`fetchChapterPages` → Task 1。
- `LinovelibSource.chapter`（同章分页拼接、50 页上限）→ Task 1/2。
- 阅读设置（模型/manager/provider、默认值与 clamp、三主题）→ Task 3。
- `novelChapterProvider`/`flattenChapters` → Task 4。
- `NovelReaderPage`（正文、顶/底栏、目录、设置、三态、切章回顶）+ 详情页接线 → Task 5。
- 测试（解析 fixture、设置模型、阅读器 widget）→ Task 1/3/5。

**Placeholder scan:** 无 TBD/TODO；每个代码步骤含完整代码。

**Type consistency:** `NovelChapter`（已有）在 Task 1/2/4/5 一致；`parseChapter`/`nextPageHref`/`fetchChapterPages`（Task 1）在 Task 2 使用；`NovelReaderSettings`/`NovelReaderTheme`/`novelReaderSettingsProvider`（Task 3）在 Task 5 使用；`novelChapterProvider`/`flattenChapters`（Task 4）在 Task 5 使用；`NovelChapterRef` 来自 `models.dart`。
