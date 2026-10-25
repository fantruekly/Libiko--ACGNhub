import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/core/comic/comic_source.dart';
import 'package:libiko/core/comic/models.dart';
import 'package:libiko/core/sources/source_preferences.dart';
import 'package:libiko/core/sources/source_management_widgets.dart';
import 'package:libiko/core/video/rule_store.dart';
import 'package:libiko/core/video/source_rule.dart';
import 'package:libiko/modules/anime/anime_source_page.dart';
import 'package:libiko/modules/comic/comic_source_page.dart';
import 'package:libiko/modules/comic/comic_providers.dart';
import 'package:libiko/modules/novel/novel_source_page.dart';
import 'package:libiko/modules/novel/novel_providers.dart';
import 'package:libiko/modules/game/game_source_page.dart';
import 'package:libiko/modules/game/game_providers.dart';
import 'package:libiko/modules/game/game_home.dart';
import 'package:libiko/modules/novel/novel_home.dart';

const _comic =
    ComicSource(name: 'Comic', key: 'comic', version: '1', canLoadEp: true);

class _Manager extends ComicSourceManager {
  int loads = 0;
  bool loaded = false;
  bool failLoad = false;
  final gate = Completer<void>();
  @override
  List<ComicSource> get sources => loaded ? [_comic] : [];
  @override
  Future<void> load() async {
    loads++;
    if (failLoad) throw StateError('registry unavailable');
    await gate.future;
    loaded = true;
  }

  @override
  Future<bool> isLogged(ComicSource source) async => true;
  @override
  Future<ComicDetails> loadInfo(ComicSource source, String id) async =>
      ComicDetails(id: id, title: 'Cold detail');
  @override
  Future<ComicEp> loadEp(
          ComicSource source, String comicId, String epId) async =>
      const ComicEp(images: ['https://test/page.jpg']);
}

Map<String, dynamic> _ruleJson(String version) => {
      'name': 'Test rule',
      'version': version,
      'baseURL': 'https://test/',
      'searchURL': 'https://test/search?wd=@keyword',
      'searchList': '//div',
      'searchName': '//a',
      'searchResult': '//a/@href',
      'chapterRoads': '//ul',
      'chapterResult': '//a',
    };

class _Store extends RuleStore {
  final versions = [_ruleJson('1'), _ruleJson('2')];
  @override
  Future<List<SourceRule>> loadBuiltIn() async => [];
  @override
  Future<List<SourceRule>> loadImported() async =>
      [SourceRule.fromJson(versions.last)];
  @override
  Future<RuleMetadata> metadata(String name) async => RuleMetadata(
      version: versions.last['version'] as String,
      updatedAt: DateTime(2026, 10, 18),
      hasPrevious: versions.length > 1);
  @override
  Future<SourceRule> rollback(String name) async {
    versions.removeLast();
    return SourceRule.fromJson(versions.last);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });
  ProviderContainer container(
          {String? snapshot, List<Override> overrides = const []}) =>
      ProviderContainer(overrides: [
        sourcePreferencesRepositoryProvider.overrideWithValue(
            SourcePreferencesRepository(
                read: (_) => snapshot, write: (_, __) async {})),
        ...overrides,
      ]);
  Future<void> mount(
      WidgetTester tester, ProviderContainer container, Widget page) async {
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: MaterialApp(home: page)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'novel source toggles retain management rows and ordering changes active list',
      (tester) async {
    final c = container();
    addTearDown(c.dispose);
    await mount(tester, c, const NovelSourcePage());
    expect(find.byType(SourceManagementTile), findsNWidgets(2));
    expect(find.text('尚无请求记录'), findsNWidgets(2));
    final ids = c.read(novelSourcesProvider).map((s) => s.id).toList();
    await tester.tap(find.byTooltip('下移').first);
    await tester.pumpAndSettle();
    expect(c.read(novelSourcesProvider).map((s) => s.id), ids.reversed);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(c.read(novelSourcesProvider), hasLength(1));
    expect(find.byType(SourceManagementTile), findsNWidgets(2));
    expect(find.text('已禁用'), findsOneWidget);
  });

  testWidgets('game manager lists disabled sources without issuing requests',
      (tester) async {
    final c = container(
        snapshot: jsonEncode({
      'disabled': {
        'game': ['galgamezywz', 'nekogal']
      }
    }));
    addTearDown(c.dispose);
    await mount(tester, c, const GameSourcePage());
    expect(c.read(gameSourcesProvider), isEmpty);
    expect(find.text('已禁用'), findsNWidgets(2));
    expect(find.text('尚无请求记录'), findsNWidgets(2));
    await mount(tester, c, const GameHomePage());
    expect(find.text('所有源已禁用，请在源管理中启用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'novel discovery with all sources disabled does not load the old selected source',
      (tester) async {
    final c = container(
        snapshot: jsonEncode({
      'disabled': {
        'novel': ['linovelib', 'lknovel']
      }
    }));
    addTearDown(c.dispose);
    await mount(tester, c, const Scaffold(body: NovelHomePage()));
    expect(find.text('所有源已禁用，请在源管理中启用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
      'cold comic history loads registry once and reads disabled source explicitly',
      () async {
    final manager = _Manager();
    final c = container(
        snapshot: jsonEncode({
          'disabled': {
            'comic': ['comic']
          }
        }),
        overrides: [comicSourceManagerProvider.overrideWithValue(manager)]);
    addTearDown(c.dispose);
    final details = c.read(comicDetailProvider(('comic', 'book')).future);
    final chapter =
        c.read(comicEpProvider(('comic', 'book', 'chapter')).future);
    final login = c.read(comicLoginProvider('comic').future);
    await Future<void>.delayed(Duration.zero);
    expect(manager.loads, 1);
    manager.gate.complete();
    expect((await details).title, 'Cold detail');
    expect((await chapter).images, hasLength(1));
    expect(await login, true);
    expect(await c.read(comicSourcesProvider.future), isEmpty);
    expect(manager.loads, 1);
  });

  testWidgets(
      'comic management retains import and account actions with disabled source',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final manager = _Manager()..loaded = true;
    manager.gate.complete();
    final c = container(
        snapshot: jsonEncode({
          'disabled': {
            'comic': ['comic']
          }
        }),
        overrides: [comicSourceManagerProvider.overrideWithValue(manager)]);
    addTearDown(c.dispose);
    await mount(tester, c, const ComicSourcePage());
    expect(find.text('Comic'), findsOneWidget);
    expect(find.text('已禁用'), findsOneWidget);
    expect(find.text('尚无请求记录'), findsOneWidget);
    expect(find.text('添加源'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comic registry retry reloads the failed underlying list',
      (tester) async {
    final manager = _Manager()..failLoad = true;
    final c = container(
        overrides: [comicSourceManagerProvider.overrideWithValue(manager)]);
    addTearDown(c.dispose);
    await mount(tester, c, const ComicSourcePage());
    expect(find.text('加载失败'), findsOneWidget);
    manager.failLoad = false;
    manager.gate.complete();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('Comic'), findsOneWidget);
    expect(manager.loads, 2);
  });

  testWidgets(
      'anime source page displays version and rolls back an imported update',
      (tester) async {
    final store = _Store();
    final c =
        container(overrides: [ruleStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    await mount(tester, c, const AnimeSourcePage());
    expect(find.textContaining('规则版本：2'), findsOneWidget);
    await tester.tap(find.text('回退上一版本'));
    await tester.pumpAndSettle();
    expect(find.textContaining('规则版本：1'), findsOneWidget);
    expect((await store.metadata('Test rule')).version, '1');
  });
}
