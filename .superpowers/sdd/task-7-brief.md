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
