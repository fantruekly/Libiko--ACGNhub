### Task 4: 搜索页与入口

**Files:**
- Create: `lib/modules/novel/novel_search.dart`
- Modify: `lib/shell/main_shell.dart`
- Test: `test/modules/novel/novel_search_page_test.dart`

**Interfaces:**
- Consumes: `novelSearchProvider` / `NovelSearchResult`（Task 3）、`NovelCard`（`lib/modules/novel/novel_home.dart`）、`NovelDetailPage`、`noTransitionRoute`、`EmptyState`、`ShimmerLoader`。
- Produces: `class NovelSearchPage extends ConsumerStatefulWidget { final String? initialKeyword; const NovelSearchPage({super.key, this.initialKeyword}); }`

- [ ] **Step 1: 写失败测试**

创建 `test/modules/novel/novel_search_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';
import 'package:acgnhub/modules/novel/novel_search.dart';

void main() {
  testWidgets('renders results from the provider', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSearchProvider('关键词').overrideWith((ref) async => const [
              NovelSearchResult(
                  novel: Novel(id: '1', title: '结果书'), sourceKey: 'lknovel'),
            ]),
      ],
      child: const MaterialApp(home: NovelSearchPage(initialKeyword: '关键词')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('结果书'), findsOneWidget);
  });

  testWidgets('shows a prompt before searching', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: NovelSearchPage()),
    ));
    expect(find.text('输入关键词搜索轻小说'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_search_page_test.dart`
Expected: 编译失败（`novel_search.dart` 不存在）。

- [ ] **Step 3: 实现搜索页**

创建 `lib/modules/novel/novel_search.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'novel_detail_page.dart';
import 'novel_home.dart';
import 'novel_providers.dart';

const _muted = Color(0xFF5A5A5F);

class NovelSearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;
  const NovelSearchPage({super.key, this.initialKeyword});

  @override
  ConsumerState<NovelSearchPage> createState() => _NovelSearchPageState();
}

class _NovelSearchPageState extends ConsumerState<NovelSearchPage> {
  final _ctrl = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialKeyword?.trim() ?? '';
    if (initial.isNotEmpty) {
      _ctrl.text = initial;
      _keyword = initial;
    }
  }

  void _search() {
    final k = _ctrl.text.trim();
    if (k.isEmpty) return;
    setState(() => _keyword = k);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(cs),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border:
            Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: widget.initialKeyword == null,
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '搜索轻小说...',
                        hintStyle: TextStyle(color: _muted, fontSize: 15),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _search(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() {});
                      },
                      child: Icon(Icons.close_rounded,
                          size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
              onPressed: _search,
              child: const Text('搜索', style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _body() {
    if (_keyword.isEmpty) {
      return const EmptyState(
          icon: Icons.search_rounded, message: '输入关键词搜索轻小说');
    }
    final async = ref.watch(novelSearchProvider(_keyword));
    return async.when(
      loading: () => const ShimmerLoader(
        crossAxisCount: 6,
        itemCount: 12,
        aspectRatio: 0.58,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      ),
      error: (error, __) => EmptyState(
        icon: Icons.error_outline_rounded,
        message: error.toString(),
        actionLabel: '重试',
        onAction: () => ref.invalidate(novelSearchProvider(_keyword)),
      ),
      data: (results) {
        if (results.isEmpty) {
          return const EmptyState(
              icon: Icons.search_off_rounded, message: '没有找到轻小说');
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.58),
          itemCount: results.length,
          itemBuilder: (_, i) {
            final r = results[i];
            return NovelCard(
              novel: r.novel,
              onTap: () => Navigator.push(
                context,
                noTransitionRoute(NovelDetailPage(
                  sourceKey: r.sourceKey,
                  novelId: r.novel.id,
                  title: r.novel.title,
                  cover: r.novel.coverUrl,
                )),
              ),
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_search_page_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 接入顶栏入口**

编辑 `lib/shell/main_shell.dart`：

(a) 加 import：

```dart
import '../modules/novel/novel_search.dart';
```

(b) 把顶栏搜索图标的条件与跳转：

```dart
              if (_currentIndex == 0 || _currentIndex == 1)
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  color: _muted,
                  splashRadius: 20,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _currentIndex == 0
                              ? const AnimeSearchPage()
                              : const ComicSearchPage())),
                ),
```

替换为：

```dart
              if (_currentIndex >= 0 && _currentIndex <= 2)
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  color: _muted,
                  splashRadius: 20,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _currentIndex == 0
                              ? const AnimeSearchPage()
                              : _currentIndex == 1
                                  ? const ComicSearchPage()
                                  : const NovelSearchPage())),
                ),
```

- [ ] **Step 6: 运行静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/modules/novel/novel_search.dart lib/shell/main_shell.dart test/modules/novel/novel_search_page_test.dart
git commit -m "feat(novel): search page and top-bar entry"
git push origin dev
```

---

## 验证（任务全部完成后）

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` 全绿。
2. 构建并启动应用，切到轻小说模块：
   - 顶栏出现搜索图标；点击打开搜索页。
   - 输入关键词（如「败犬」）回车/点「搜索」→ 出现结果网格（合并两个源、按书名去重）。
   - 点结果进入详情页。
   - 空关键词显示「输入关键词搜索轻小说」；无结果显示「没有找到轻小说」。

## 已知取舍

- 单页、无分页/加载更多；不做搜索历史与按源筛选。
- 结果不标来源；同名书只保留第一个。