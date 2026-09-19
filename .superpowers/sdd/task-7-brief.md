## Task 7: 首页 UI（GameCard + GameHomePage）

**Files:**
- Create: `lib/modules/game/game_home.dart`
- Test: `test/modules/game/game_home_test.dart`

**Interfaces:**
- Consumes: `gameSourcesProvider` / `gameBrowseProvider`（Task 6）、`GameCard` 用到的 `gameImageHeaders`（Task 3）、`ChipBar` / `ShimmerLoader` / `EmptyState` / `noTransitionRoute`。
- Produces: `class GameCard extends StatelessWidget { GameCard({required Game game, VoidCallback? onTap}) }`、`class GameHomePage extends ConsumerStatefulWidget { const GameHomePage({super.key}) }`。

- [ ] **Step 1: Write the failing test**

Create `test/modules/game/game_home_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_source.dart';
import 'package:acgnhub/core/game/models.dart';
import 'package:acgnhub/modules/game/game_home.dart';
import 'package:acgnhub/modules/game/game_providers.dart';

class _FakeSource implements GameSource {
  @override
  String get id => 'galgamezywz';
  @override
  String get name => 'galgame大玩家';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions => const [
        GameBrowseOption(key: 'latest', label: '最近更新'),
        GameBrowseOption(key: 'wanjiareping', label: '玩家热评'),
      ];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async => GameList(
        items: [Game(id: '$optionKey-$page', title: '游戏$optionKey$page')],
        page: page,
        hasMore: optionKey == 'latest' && page == 1,
      );
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
}

void main() {
  testWidgets('renders source/section chips, grid and pager', (tester) async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider
          .overrideWithValue(GameSourceManager(sources: [_FakeSource()])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: GameHomePage())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('galgame大玩家'), findsOneWidget);
    expect(find.text('最近更新'), findsOneWidget);
    expect(find.text('玩家热评'), findsOneWidget);
    expect(find.text('游戏latest1'), findsOneWidget);
    expect(find.text('第 1 页'), findsOneWidget);

    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();

    expect(find.text('第 2 页'), findsOneWidget);
    expect(find.text('游戏latest2'), findsOneWidget);
    // 第 2 页 hasMore=false → 下一页禁用
    final next = tester.widget<IconButton>(find.byTooltip('下一页'));
    expect(next.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/game/game_home_test.dart`
Expected: FAIL（找不到 `game_home.dart`）。

- [ ] **Step 3: Write minimal implementation**

Create `lib/modules/game/game_home.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/game/galgamezywz_source.dart';
import '../../core/game/game_source.dart';
import '../../core/game/models.dart';
import '../../core/widgets/chip_bar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'game_detail_page.dart';
import 'game_providers.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF5A5A5F);
const _fg = Color(0xFF1C1C1E);

class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback? onTap;
  const GameCard({super.key, required this.game, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: game.coverUrl != null && game.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: game.coverUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      fadeInDuration: Duration.zero,
                      httpHeaders: gameImageHeaders,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              game.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: _fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    final hash = game.title.hashCode.abs();
    const bg = [
      Color(0xFFF3E5F5),
      Color(0xFFEDE7F6),
      Color(0xFFE8EAF6),
      Color(0xFFE0F2F1),
    ];
    return Container(
      color: bg[hash % bg.length],
      child: Center(
        child: Text(
          game.title.isEmpty ? '游' : game.title.characters.first,
          style: TextStyle(
              color: _accent.withValues(alpha: 0.2),
              fontSize: 28,
              fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}

class GameHomePage extends ConsumerStatefulWidget {
  const GameHomePage({super.key});

  @override
  ConsumerState<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends ConsumerState<GameHomePage> {
  String _sourceId = 'galgamezywz';
  int _optionIndex = 0;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(gameSourcesProvider);
    final source = ref.watch(gameSourceManagerProvider).byId(_sourceId);
    final options = source?.browseOptions ?? const <GameBrowseOption>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _sourceChips(sources),
        _sectionChips(options),
        Expanded(child: _body(options)),
      ],
    );
  }

  Widget _sourceChips(List<GameSource> sources) {
    if (sources.isEmpty) return const SizedBox.shrink();
    final labels = [for (final s in sources) s.name];
    final index = sources.indexWhere((s) => s.id == _sourceId);
    return ChipBar(
      labels: labels,
      selectedIndex: index < 0 ? 0 : index,
      onSelected: (i) => setState(() {
        _sourceId = sources[i].id;
        _optionIndex = 0;
        _page = 1;
      }),
    );
  }

  Widget _sectionChips(List<GameBrowseOption> options) {
    final labels = [for (final o in options) o.label];
    if (labels.isEmpty) return const SizedBox.shrink();
    return ChipBar(
      labels: labels,
      selectedIndex: _optionIndex.clamp(0, labels.length - 1),
      onSelected: (i) => setState(() {
        _optionIndex = i;
        _page = 1;
      }),
    );
  }

  Widget _body(List<GameBrowseOption> options) {
    if (options.isEmpty) {
      return const EmptyState(icon: Icons.games_rounded, message: '暂无内容');
    }
    final option = options[_optionIndex.clamp(0, options.length - 1)];
    final key = (_sourceId, option.key, _page);
    final async = ref.watch(gameBrowseProvider(key));
    return async.when(
      loading: () => const ShimmerLoader(
          crossAxisCount: 6,
          itemCount: 12,
          aspectRatio: 0.58,
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(gameBrowseProvider(key)),
      ),
      data: (list) => Column(
        children: [
          Expanded(child: _grid(list.items)),
          _pager(list.hasMore),
        ],
      ),
    );
  }

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

  Widget _grid(List<Game> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.games_rounded, message: '暂无内容');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: 0.58),
      itemCount: items.length,
      itemBuilder: (_, i) => GameCard(
        game: items[i],
        onTap: () => Navigator.push(
          context,
          noTransitionRoute(GameDetailPage(
            sourceKey: _sourceId,
            gameId: items[i].id,
            title: items[i].title,
            cover: items[i].coverUrl,
          )),
        ),
      ),
    );
  }
}
```

> 注：`game_detail_page.dart` 在本任务尚未创建。为避免 Task 7 无法编译，先在 `lib/modules/game/game_detail_page.dart` 放一个最小占位（Task 8 会整体替换）：

```dart
import 'package:flutter/material.dart';

class GameDetailPage extends StatelessWidget {
  final String sourceKey;
  final String gameId;
  final String title;
  final String? cover;
  const GameDetailPage({
    super.key,
    required this.sourceKey,
    required this.gameId,
    required this.title,
    this.cover,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/modules/game/game_home_test.dart`
Expected: PASS（1 test）。

- [ ] **Step 5: Commit**

```bash
git add lib/modules/game/game_home.dart lib/modules/game/game_detail_page.dart test/modules/game/game_home_test.dart
git commit -m "feat(game): add game home page with cards and paging"
```

---

