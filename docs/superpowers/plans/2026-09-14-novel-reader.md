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

### Task 6: 最终审查修复（设置状态 / 导航测试 / chapterPath / 小项）

> 来自最终整支审查。

**Files:**
- Modify: `lib/core/novel/novel_reader_settings.dart`
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `lib/modules/novel/novel_reader_page.dart`
- Modify: `test/modules/novel/novel_reader_page_test.dart`

- [ ] **Step 1: 设置：先同步更新 state，再持久化（修 lost-update）**

`novel_reader_settings.dart` 的 `_update` 改为：

```dart
  Future<void> _update(NovelReaderSettings next) async {
    state = next;
    await _manager.write(next);
  }
```

- [ ] **Step 2: `fetchChapterPages` 复用 `chapterPath`**

在 `linovelib_source.dart` 的 `fetchChapterPages` 里，把

```dart
  final firstHtml = await fetch('/novel/$novelId/$chapterId.html');
```

改为：

```dart
  final firstHtml = await fetch(LinovelibSource.chapterPath(novelId, chapterId));
```

（`LinovelibSource.chapterPath` 已在 Task 2 定义；顶层函数可前向引用该类。）

- [ ] **Step 3: 阅读器：`_topBar` 去掉未用参数；目录按分卷分组；弹层用阅读配色**

在 `novel_reader_page.dart`：
- `_topBar` 改为 `Widget _topBar(_Palette palette)`，调用处 `_topBar(palette)`。
- `_openCatalog` 改为接收 `NovelDetail` 并按分卷分组；调用处 `_openCatalog(detail)`（`build` 里用 `ref.watch(novelDetailProvider(...)).valueOrNull`，为空则用 `flattenChapters` 的扁平列表降级）：

```dart
  void _openCatalog(NovelDetail? detail) {
    final palette = _Palette.of(ref.read(novelReaderSettingsProvider).theme);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.bg,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                surface: palette.bg,
                onSurface: palette.fg,
              ),
        ),
        child: ListView(
          children: [
            if (detail == null || detail.volumes.isEmpty)
              const ListTile(title: Text('暂无目录'))
            else
              for (final v in detail.volumes) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(v.title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.fg.withValues(alpha: 0.7))),
                ),
                for (final c in v.chapters)
                  ListTile(
                    dense: true,
                    title: Text(c.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: c.id == _chapterId
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: _accent)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (c.id != _chapterId) _goChapter(c.id);
                    },
                  ),
              ],
          ],
        ),
      ),
    );
  }
```

- `_openSettings` 同样传入 `backgroundColor: palette.bg` 并用上面的 `Theme` 包裹 `_ReaderSettingsSheet`。
- 调用处：`_openCatalog(ref.watch(novelDetailProvider((widget.sourceKey, widget.novelId))).valueOrNull)`。

- [ ] **Step 4: 补「下一章」导航测试**

在 `test/modules/novel/novel_reader_page_test.dart` 追加（该文件已有 `setUp` 的 `AppDatabase.init()`）：

```dart
  testWidgets('tapping 下一章 loads the next chapter', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelChapterProvider(('linovelib', '1', 'c1')).overrideWith((ref) async =>
            const NovelChapter(title: '第一章', content: '甲段')),
        novelChapterProvider(('linovelib', '1', 'c2')).overrideWith((ref) async =>
            const NovelChapter(title: '第二章', content: '乙段')),
        novelDetailProvider(('linovelib', '1')).overrideWith((ref) async =>
            const NovelDetail(novel: Novel(id: '1', title: '书'), volumes: [
              NovelVolume(title: '正文', chapters: [
                NovelChapterRef(id: 'c1', title: '第一章'),
                NovelChapterRef(id: 'c2', title: '第二章'),
              ]),
            ])),
      ],
      child: const MaterialApp(
        home: NovelReaderPage(
            sourceKey: 'linovelib',
            novelId: '1',
            chapterId: 'c1',
            title: '书'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('甲段'), findsOneWidget);
    await tester.tap(find.text('下一章'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('乙段'), findsOneWidget);
  });
```

- [ ] **Step 5: 全量校验**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过

- [ ] **Step 6: 提交**

```bash
git add lib/core/novel/novel_reader_settings.dart lib/core/novel/linovelib_source.dart lib/modules/novel/novel_reader_page.dart test/modules/novel/novel_reader_page_test.dart
git commit -m "fix(novel): sync settings state, wire chapterPath, grouped catalog, next-chapter test"
git push
```

---

### Task 7: 插图渲染（正文块模型）

> 用户反馈：插图无法显示。根因：linovelib 插图章节的图片在 `div#TextContent` 内，形如
> `<img src="/images/sloading.svg" data-src="https://img3.readpai.com/.../321969.jpeg" class="imagecontent lazyload">`
> ——真实地址在 `data-src`（`src` 是懒加载占位）。阅读器只取 `<p>`，故插图丢失。

**Files:**
- Modify: `lib/core/novel/models.dart`
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `lib/modules/novel/novel_reader_page.dart`
- Modify: `test/core/novel/linovelib_chapter_parser_test.dart`
- Modify: `test/modules/novel/novel_reader_page_test.dart`

**Interfaces:**
- Produces: `sealed class NovelBlock`; `class NovelText extends NovelBlock { final String text; }`; `class NovelImage extends NovelBlock { final String url; }`; `class NovelChapter { final String title; final List<NovelBlock> blocks; }`（**替换**原 `content` 字段）。

- [ ] **Step 1: 改测试**

`linovelib_chapter_parser_test.dart`：把断言 `ch.content` 改为 `ch.blocks`。例如：

```dart
  test('parseChapter reads title, paragraphs and images in order', () {
    final ch = parseChapter(_pagedHtml, 'FB');
    expect(ch.title, '第60話 規則（2）');
    expect(
      ch.blocks.map((b) => switch (b) {
            NovelText(:final text) => text,
            NovelImage(:final url) => 'IMG:$url',
          }),
      ['第一段。', '第二段。', '第三段。'],
    );
  });
```

并新增插图用例：

```dart
  test('parseChapter extracts lazy-loaded images and skips placeholders', () {
    const html = '''
<div id="TextContent">
  <p>文</p>
  <img src="/images/sloading.svg" data-src="https://img3.readpai.com/5/1/2/a.jpeg" class="imagecontent lazyload">
  <img src="/images/sloading.svg" data-src="/files/x.png">
</div>''';
    final ch = parseChapter(html, 'T');
    final images = ch.blocks.whereType<NovelImage>().map((b) => b.url).toList();
    expect(images, [
      'https://img3.readpai.com/5/1/2/a.jpeg',
      'https://www.linovelib.com/files/x.png',
    ]);
  });
```

（若测试文件未 import `models.dart` 需补 `import 'package:acgnhub/core/novel/models.dart';`。`fetchChapterPages` 测试的 `ch.content` 断言改为 `ch.blocks.whereType<NovelText>().map((b)=>b.text).join('\n\n')`。）

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_chapter_parser_test.dart`
Expected: FAIL（`NovelBlock` 未定义）

- [ ] **Step 3: 改 `models.dart`**

把 `NovelChapter` 替换为：

```dart
sealed class NovelBlock {
  const NovelBlock();
}

class NovelText extends NovelBlock {
  final String text;
  const NovelText(this.text);
}

class NovelImage extends NovelBlock {
  final String url;
  const NovelImage(this.url);
}

class NovelChapter {
  final String title;
  final List<NovelBlock> blocks;
  const NovelChapter({required this.title, this.blocks = const []});
}
```

- [ ] **Step 4: 改 `linovelib_source.dart` 的 `parseChapter` / `fetchChapterPages`**

`parseChapter` 改为按 `div#TextContent` 的子元素顺序产出块：

```dart
String? _imageUrl(dom.Element img) {
  final raw = img.attributes['data-src'] ?? img.attributes['src'];
  if (raw == null || raw.isEmpty) return null;
  if (raw.contains('sloading') || raw.endsWith('.svg')) return null;
  return _absUrl(raw);
}

NovelChapter parseChapter(String html, String fallbackTitle) {
  final doc = html_parser.parse(html);
  final title = _textOf(doc.querySelector('#mlfy_main_text h1'));
  final blocks = <NovelBlock>[];
  final content = doc.querySelector('div#TextContent');
  if (content != null) {
    for (final node in content.nodes) {
      if (node is! dom.Element) continue;
      switch (node.localName) {
        case 'p':
          final t = node.text.trim();
          if (t.isNotEmpty) blocks.add(NovelText(t));
        case 'img':
          final url = _imageUrl(node);
          if (url != null) blocks.add(NovelImage(url));
      }
    }
  }
  return NovelChapter(
      title: title.isEmpty ? fallbackTitle : title, blocks: blocks);
}
```

`fetchChapterPages` 把拼接从字符串改为块列表：

```dart
  final first = parseChapter(firstHtml, '');
  final blocks = <NovelBlock>[...first.blocks];
  var next = nextPageHref(firstHtml, novelId, chapterId);
  var pages = 1;
  while (next != null && pages < maxPages) {
    final html = await fetch(next);
    blocks.addAll(parseChapter(html, '').blocks);
    next = nextPageHref(html, novelId, chapterId);
    pages++;
  }
  return NovelChapter(title: first.title, blocks: blocks);
```

- [ ] **Step 5: 改阅读器 `_content` 渲染块**

`novel_reader_page.dart`：顶部加 `import 'package:cached_network_image/cached_network_image.dart';`；`_content` 改为遍历 `chapter.blocks`：

```dart
  Widget _content(
      NovelChapter chapter, NovelReaderSettings settings, _Palette palette) {
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chapter.title.isNotEmpty) ...[
            Text(chapter.title,
                style: TextStyle(
                    fontSize: settings.fontSize + 4,
                    fontWeight: FontWeight.w600,
                    color: palette.fg)),
            const SizedBox(height: 16),
          ],
          if (chapter.blocks.isEmpty)
            Text('本章暂无内容',
                style: TextStyle(
                    fontSize: settings.fontSize,
                    color: palette.fg.withValues(alpha: 0.5)))
          else
            for (final block in chapter.blocks)
              switch (block) {
                NovelText(:final text) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(text,
                        style: TextStyle(
                            fontSize: settings.fontSize,
                            height: settings.lineHeight,
                            color: palette.fg)),
                  ),
                NovelImage(:final url) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const SizedBox(
                            height: 180,
                            child: Center(child: CircularProgressIndicator())),
                        errorWidget: (_, __, ___) => const SizedBox(
                            height: 80,
                            child: Center(
                                child: Icon(Icons.broken_image_outlined))),
                      ),
                    ),
                  ),
              },
        ],
      ),
    );
  }
```

- [ ] **Step 6: 阅读器测试改断言**

`novel_reader_page_test.dart` 的 override 从 `NovelChapter(title:..., content:...)` 改为 `blocks:`，断言 `find.text('第一段。')` 等；「下一章」测试同理（`content: '甲段'` → `blocks: [NovelText('甲段')]`）。

- [ ] **Step 7: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/core/novel/models.dart lib/core/novel/linovelib_source.dart lib/modules/novel/novel_reader_page.dart test/core/novel/linovelib_chapter_parser_test.dart test/modules/novel/novel_reader_page_test.dart
git commit -m "fix(novel): render chapter illustrations (block model with images)"
git push
```

---

### Task 8: 详情页/阅读器加窗口控制按钮

> 用户反馈：进入轻小说详情页后右上角最小化/最大化/关闭按钮消失。根因：详情页与阅读器是 push 的全屏路由，盖住了 shell 标题栏里的 `WindowControls`。

**Files:**
- Modify: `lib/modules/novel/novel_detail_page.dart`
- Modify: `lib/modules/novel/novel_reader_page.dart`

**Interfaces:**
- Consumes: `WindowControls`（`lib/core/widgets/window_controls.dart`，已存在）。

- [ ] **Step 1: 详情页 AppBar 加 actions**

`novel_detail_page.dart`：加 `import '../../core/widgets/window_controls.dart';`；`AppBar` 增加 `actions`：

```dart
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: const [WindowControls()],
      ),
```

- [ ] **Step 2: 阅读器顶栏加窗口按钮**

`novel_reader_page.dart`：加 `import '../../core/widgets/window_controls.dart';`；`_topBar` 的 `Row` 末尾（标题之后）加 `const WindowControls()`：

```dart
            Expanded(
              child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.fg)),
            ),
            const WindowControls(),
```

- [ ] **Step 3: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/modules/novel/novel_detail_page.dart lib/modules/novel/novel_reader_page.dart
git commit -m "fix(novel): show window controls on detail and reader pages"
git push
```

---

### Task 9: 小说图片加 Referer 头（修插图与部分封面）

> 用户反馈：插图仍不显示、部分封面加载不出。根因（实测）：`img3.readpai.com` 的图片有**防盗链**——无 `Referer` 返回 403，带 `Referer: https://www.linovelib.com/` 才 200。`CachedNetworkImage` 默认不带 Referer。

**Files:**
- Modify: `lib/modules/novel/novel_home.dart`
- Modify: `lib/modules/novel/novel_detail_page.dart`
- Modify: `lib/modules/novel/novel_reader_page.dart`

**Interfaces:**
- Produces: 顶层常量 `const novelImageHeaders = {'Referer': 'https://www.linovelib.com/'};`（放 `linovelib_source.dart`，供三处复用）。

- [ ] **Step 1: 加常量**

在 `lib/core/novel/linovelib_source.dart` 顶部常量区加：

```dart
const Map<String, String> novelImageHeaders = {
  'Referer': 'https://www.linovelib.com/',
};
```

- [ ] **Step 2: 三处 `CachedNetworkImage` 加 `httpHeaders`**

- `novel_home.dart` 的 `NovelCard`：
```dart
                  ? CachedNetworkImage(
                      imageUrl: novel.coverUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      httpHeaders: novelImageHeaders,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
```
  （顶部加 `import '../../core/novel/linovelib_source.dart';`。）
- `novel_detail_page.dart` 的封面：给其 `CachedNetworkImage` 加 `httpHeaders: novelImageHeaders,`（并 import `../../core/novel/linovelib_source.dart`）。
- `novel_reader_page.dart` 的插图：给其 `CachedNetworkImage` 加 `httpHeaders: novelImageHeaders,`（并 import `../../core/novel/linovelib_source.dart`）。

- [ ] **Step 3: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/core/novel/linovelib_source.dart lib/modules/novel/novel_home.dart lib/modules/novel/novel_detail_page.dart lib/modules/novel/novel_reader_page.dart
git commit -m "fix(novel): send Referer header for novel images (hotlink protection)"
git push
```

---

### Task 10: 详情页顶栏改用 48px 自定义栏 + 无过渡进入

> 用户反馈：详情页右上角按钮要像漫画详情页那样；进入详情页不要过渡（感觉像首页按钮继续显示）。

**Files:**
- Modify: `lib/core/widgets/smooth_route.dart`
- Modify: `lib/modules/novel/novel_detail_page.dart`
- Modify: `lib/modules/novel/novel_home.dart`

**Interfaces:**
- Produces: `Route<T> noTransitionRoute<T>(Widget page)`。

- [ ] **Step 1: 加无过渡路由**

`lib/core/widgets/smooth_route.dart` 末尾加：

```dart
/// An instant route (no transition) used when the destination's own top bar
/// visually continues the shell's title bar (so a fade would look like the
/// window controls jumped).
Route<T> noTransitionRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => page,
  );
}
```

- [ ] **Step 2: 详情页改用自定义 48px 顶栏**

`novel_detail_page.dart`：加 `import 'package:window_manager/window_manager.dart';`（若未导入）。把 `Scaffold` 的 `appBar: AppBar(...)` 去掉，改为 `body: Column(children: [_header(), Expanded(child: <原 body 内容>)])`，并加：

```dart
  Widget _header() {
    return DragToMoveArea(
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 4),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          border:
              Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: _fg,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _fg),
              ),
            ),
            const WindowControls(),
          ],
        ),
      ),
    );
  }
```

（`_fg` 已在该文件定义；`WindowControls` 已导入。）

- [ ] **Step 3: 首页卡片用无过渡路由打开详情**

`novel_home.dart` 的 `_grid` `itemBuilder`：把 `smoothRoute(NovelDetailPage(...))` 改为 `noTransitionRoute(NovelDetailPage(...))`。

- [ ] **Step 4: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/core/widgets/smooth_route.dart lib/modules/novel/novel_detail_page.dart lib/modules/novel/novel_home.dart
git commit -m "fix(novel): 48px detail header and instant transition"
git push
```

---

### Task 11: 探索页卡片去掉作者（统一封面高度）

> 用户反馈：探索页部分小说带作者，导致卡片高度不一致、封面大小会变。

**Files:**
- Modify: `lib/modules/novel/novel_home.dart`
- Modify: `test/modules/novel/novel_card_test.dart`（若断言了作者）

- [ ] **Step 1: 改 `NovelCard`**

删除作者那一行：

```dart
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              novel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, height: 1.45, color: _fg),
            ),
          ),
```

（即删掉 `if (novel.author != null && novel.author!.isNotEmpty) Text(novel.author!, ...)` 整段。）

- [ ] **Step 2: 适配测试**

`test/modules/novel/novel_card_test.dart`：若断言了 `find.text('入间人间')`（作者），删掉该断言，改为断言标题仍存在。

- [ ] **Step 3: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/modules/novel/novel_home.dart test/modules/novel/novel_card_test.dart
git commit -m "fix(novel): drop author from explore cards for uniform covers"
git push
```

---

### Task 12: 阅读器插图按视口高度显示（两侧留白）

> 用户反馈：看插图时希望像看漫画一样——插图竖向与页面竖向匹配，两边留白。

**Files:**
- Modify: `lib/modules/novel/novel_reader_page.dart`

- [ ] **Step 1: 插图块改为视口高度的 `BoxFit.contain`**

在 `_content` 的 `NovelImage` 分支，把 `ClipRRect > CachedNetworkImage(fit: BoxFit.contain)` 包在固定高度的 `SizedBox` 里：

```dart
                NovelImage(:final url) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SizedBox(
                      height: _illustrationHeight(context),
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        httpHeaders: novelImageHeaders,
                        placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
```

并加方法：

```dart
  /// The height of the content viewport (between the 56px top bar and the
  /// 64px bottom bar), so an illustration fills the page vertically with the
  /// sides left blank, like a comic page.
  double _illustrationHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height - 56 - 64 - 24;
    return h.clamp(200, 4000).toDouble();
  }
```

- [ ] **Step 2: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/modules/novel/novel_reader_page.dart
git commit -m "fix(novel): size reader illustrations to the viewport height"
git push
```

---

### Task 13: 人气榜改用带封面的 URL

> 用户反馈：排行榜「人气榜」很多封面加载不出。根因（实测）：`/top.html` 用 `rank_i_li` 结构，122 行里**只有 6 行带封面**；而 `/top/allvisit/1.html`（同为人气榜）用 `rank_d_list` 结构，**30 行全部带封面**。`rankPath('allvisit')` 目前返回 `/top.html`。

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `test/core/novel/linovelib_source_test.dart`
- Modify: `docs/superpowers/specs/2026-09-14-novel-module-design.md`

- [ ] **Step 1: 改测试**

`test/core/novel/linovelib_source_test.dart`：
- `rankPath('allvisit', 1)` 断言改为 `'/top/allvisit/1.html'`；`rankPath('allvisit', 2)` → `'/top/allvisit/2.html'`。
- 删除 `isSinglePageRanking` 的测试（该方法将移除）。

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: FAIL（`allvisit` 仍返回 `/top.html`）

- [ ] **Step 3: 改 `linovelib_source.dart`**

把 `rankPath` 改为统一模式（去掉 `allvisit` 特例）：

```dart
  static String rankPath(String key, int page) => '/top/$key/$page.html';
```

删除 `isSinglePageRanking` 方法，并把 `browse` 的 `hasMore` 改为不再特判：

```dart
    final hasMore = hasPaginationControl(html)
        ? hasNextPage(html)
        : items.length >= 10;
    return NovelList(items: items, page: page, hasMore: hasMore);
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: PASS

- [ ] **Step 5: 修 spec 文案**

`docs/superpowers/specs/2026-09-14-novel-module-design.md`：把「人气榜（`allvisit`，`/top.html`）为单页」改为「人气榜同其他榜一样用 `/top/allvisit/<page>.html`（该页每行都有封面；旧的 `/top.html` 只有少数行带封面，已弃用）」。

- [ ] **Step 6: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_source_test.dart docs/superpowers/specs/2026-09-14-novel-module-design.md
git commit -m "fix(novel): use cover-rich /top/allvisit/<page>.html for 人气榜"
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
