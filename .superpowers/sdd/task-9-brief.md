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
