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