## Task 3: 轻小说探索页接入

**Files:**
- Modify: `lib/modules/novel/novel_home.dart`
- Test: `test/modules/novel/novel_home_tabs_test.dart`、`test/modules/novel/novel_home_pager_test.dart`（回归）

### Step 1: 接入

1) import 加入 `import '../../core/widgets/slide_switcher.dart';`

2) 在 `_ExploreTabState._body`（第 201 行起）顶部加入：

```dart
    final sourceIndex =
        ref.watch(novelSourcesProvider).indexWhere((s) => s.id == _sourceId);
```

3) 「推荐」分支（`_groupIndex < 0`）的 `return async.when(...)`（第 204–217 行）替换为（`SlideSwitcher` 包住整个 `async.when`）：

```dart
      return SlideSwitcher(
        id: (_sourceId, '__home__'),
        index: sourceIndex * 1000000,
        child: async.when(
          loading: () => const ShimmerLoader(
              crossAxisCount: 6,
              itemCount: 12,
              aspectRatio: 0.58,
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
          error: (_, __) => EmptyState(
            icon: Icons.cloud_off_rounded,
            message: '加载失败',
            actionLabel: '重试',
            onAction: () => ref.invalidate(novelHomeProvider(_sourceId)),
          ),
          data: (home) => _grid(flattenHome(home)),
        ),
      );
```

4) 分组分支的 `return async.when(...)`（第 225–244 行）替换为（`SlideSwitcher` 包住整个 `async.when`，分页栏在其外）：

```dart
      final pageData = async.valueOrNull;
      return Column(
        children: [
          Expanded(
            child: SlideSwitcher(
              id: (_sourceId, option.key, _page),
              index: sourceIndex * 1000000 +
                  (_groupIndex + 1) * 10000 +
                  _optionIndex * 100 +
                  _page,
              child: async.when(
                loading: () => const ShimmerLoader(
                    crossAxisCount: 6,
                    itemCount: 12,
                    aspectRatio: 0.58,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
                error: (_, __) => EmptyState(
                  icon: Icons.cloud_off_rounded,
                  message: '加载失败',
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(
                      novelBrowseProvider((_sourceId, option.key, _page))),
                ),
                data: (list) => _grid(list.items),
              ),
            ),
          ),
          if (pageData != null) _pager(pageData.hasMore),
        ],
      );
```

### Step 2: 运行回归

Run:
- `C:\flutter\bin\flutter.bat test test/modules/novel/novel_home_tabs_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/novel/novel_home_pager_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: PASS；analyze 无问题。

### Step 3: 提交

```bash
git add lib/modules/novel/novel_home.dart
git commit -m "feat(novel): slide the grid when switching sections or pages"
```

---

