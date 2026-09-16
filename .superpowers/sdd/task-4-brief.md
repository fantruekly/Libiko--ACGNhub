## Task 4: 漫画发现页接入

**Files:**
- Modify: `lib/modules/comic/comic_home.dart`
- Test: `test/modules/comic/comic_explore_paging_test.dart`（回归）

### Step 1: 接入

1) import 加入 `import '../../core/widgets/slide_switcher.dart';`

2) 调用点（第 133 行）改为：

```dart
            Expanded(child: _explore(selected, section, part, sources.indexOf(selected))),
```

3) `_explore` 签名（第 209 行）改为：

```dart
  Widget _explore(ComicSource source, int section, int part, int sourceIndex) {
```

4) 把 `_explore` 里的 `Expanded(child: async.when(...))`（第 224–268 行）替换为：

```dart
        Expanded(
          child: SlideSwitcher(
            id: (source.key, section, part, _page),
            index: sourceIndex * 1000000 +
                section * 10000 +
                part * 100 +
                _page,
            child: async.when(
              loading: () => const ShimmerLoader(
                crossAxisCount: 6,
                itemCount: 12,
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
              ),
              error: (_, __) => EmptyState(
                icon: Icons.cloud_off_rounded,
                message: '加载失败',
                actionLabel: '重试',
                onAction: () {
                  clearExploreCache(source.key, section);
                  ref.invalidate(comicSourcePageProvider);
                  ref.invalidate(
                      comicExploreAllProvider((source.key, section)));
                  ref.invalidate(comicExploreProvider(
                      (source.key, section, part, _page)));
                },
              ),
              data: (data) {
                if (data.comics.isEmpty) {
                  return const EmptyState(
                      icon: Icons.image_not_supported_rounded, message: '暂无内容');
                }
                return _comicGrid(
                  count: data.comics.length,
                  itemBuilder: (i) => ComicCard(
                    title: data.comics[i].title,
                    cover: data.comics[i].cover,
                    heroTag: 'comic_${source.key}_${data.comics[i].id}',
                    onTap: () => Navigator.push(
                      context,
                      smoothRoute(ComicDetailPage(
                        sourceKey: source.key,
                        comicId: data.comics[i].id,
                        title: data.comics[i].title,
                        cover: data.comics[i].cover,
                      )),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
```

（`_paginationBar` 保持在 `SlideSwitcher` 之外。）

### Step 2: 运行回归

Run:
- `C:\flutter\bin\flutter.bat test test/modules/comic/comic_explore_paging_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: PASS；analyze 无问题。

### Step 3: 提交

```bash
git add lib/modules/comic/comic_home.dart
git commit -m "feat(comic): slide the grid when switching sections or pages"
```

---

