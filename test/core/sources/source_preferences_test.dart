import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libiko/core/sources/source_preferences.dart';
import 'package:libiko/core/sources/managed_sources.dart';
import 'package:libiko/core/video/video_source.dart';
import 'package:libiko/core/video/cancellation.dart';
import 'package:libiko/modules/novel/novel_providers.dart';
import 'package:libiko/modules/game/game_providers.dart';

class _Video implements VideoSource {
  @override
  String get id => 'video';
  @override
  String get name => 'Video';
  @override
  String get baseUrl => 'https://test/';
  Object? error;
  @override
  Future<List<VideoItem>> search(String keyword,
      {CancellationToken? cancel}) async {
    if (error != null) throw error!;
    return [];
  }

  @override
  Future<List<VideoEpisode>> episodes(String detailUrl,
      {CancellationToken? cancel}) async {
    if (error != null) throw error!;
    return [];
  }
}

void main() {
  test(
      'ordering is stable for new sources and disabled sources remain manageable',
      () {
    const config = SourcePreferences(disabled: {
      SourceKind.game: {'b'}
    }, order: {
      SourceKind.game: ['b', 'a', 'removed']
    });
    expect(config.apply(SourceKind.game, ['c', 'a', 'b', 'd'], (v) => v),
        ['a', 'c', 'd']);
    expect(
        config.apply(SourceKind.game, ['c', 'a', 'b', 'd'], (v) => v,
            includeDisabled: true),
        ['b', 'a', 'c', 'd']);
  });

  test(
      'serialized updates preserve toggles, ordering and type isolation across reload',
      () async {
    final data = <String, String>{};
    final repo = SourcePreferencesRepository(
        read: (k) => data[k],
        write: (k, v) async {
          data[k] = v;
        });
    final config = SourcePreferencesNotifier(repo);
    await Future.wait([
      config.setEnabled(SourceKind.anime, 'shared', false),
      config.setEnabled(SourceKind.novel, 'novel', false),
      config.setOrder(SourceKind.game, ['b', 'a']),
    ]);
    final restored = repo.load();
    expect(restored.enabled(SourceKind.anime, 'shared'), false);
    expect(restored.enabled(SourceKind.game, 'shared'), true);
    expect(restored.enabled(SourceKind.novel, 'novel'), false);
    expect(restored.order[SourceKind.game], ['b', 'a']);
    await config.move(SourceKind.game, ['b', 'a'], 'a', -1);
    expect(repo.load().order[SourceKind.game], ['a', 'b']);
    config.dispose();
  });

  test('failed persistence does not publish an unsaved source setting',
      () async {
    final repo = SourcePreferencesRepository(
        read: (_) => null,
        write: (_, __) async => throw StateError('disk failure'));
    final config = SourcePreferencesNotifier(repo);
    await expectLater(
        config.setEnabled(SourceKind.anime, 'a', false), throwsStateError);
    expect(config.state.enabled(SourceKind.anime, 'a'), true);
    config.dispose();
  });

  test(
      'backup restores preferences only and validates before replacing settings',
      () async {
    final data = <String, String>{};
    final repo = SourcePreferencesRepository(
        read: (k) => data[k],
        write: (k, v) async {
          data[k] = v;
        });
    await repo.restoreSnapshot({
      'version': 1,
      'disabled': {
        'comic': ['x']
      },
      'order': {
        'novel': ['a', 'b']
      }
    });
    final original = Map.of(data);
    expect(
        () => repo.restoreSnapshot({
              'disabled': {
                'comic': [1]
              }
            }),
        throwsFormatException);
    expect(data, original);
    expect(repo.exportSnapshot().keys,
        unorderedEquals(['version', 'disabled', 'order']));
  });

  test('health records genuine outcomes and never stores raw error secrets',
      () async {
    final data = <String, String>{};
    var now = DateTime.utc(2026, 10, 18);
    final repo = SourceHealthRepository(
        read: (k) => data[k],
        write: (k, v) async {
          data[k] = v;
        },
        clock: () => now);
    expect(repo.health(SourceKind.anime, 'a').lastSuccess, isNull);
    await repo.track(SourceKind.anime, 'a', () async => <String>[]);
    now = now.add(const Duration(minutes: 1));
    await expectLater(
        repo.track(SourceKind.anime, 'a',
            () async => throw TimeoutException('https://secret/?token=123')),
        throwsA(isA<TimeoutException>()));
    await repo.flush();
    final record = repo.health(SourceKind.anime, 'a');
    expect(record.lastSuccess, DateTime.utc(2026, 10, 18));
    expect(record.lastFailure, now);
    expect(record.failure, SourceFailureKind.timeout);
    expect(record.mostRecentSucceeded, false);
    expect(data.values.join(), isNot(contains('secret')));
    final fresh =
        SourceHealthRepository(read: (k) => data[k], write: (_, __) async {});
    expect(
        fresh.health(SourceKind.anime, 'a').failure, SourceFailureKind.timeout);
    expect(fresh.health(SourceKind.comic, 'a').lastFailure, isNull);
    repo.dispose();
    fresh.dispose();
  });

  test('cancellation is not recorded as source failure', () async {
    final repo =
        SourceHealthRepository(read: (_) => null, write: (_, __) async {});
    await repo.track(SourceKind.game, 'a', () async => 1,
        cancelled: () => true);
    await expectLater(
        repo.track(
            SourceKind.game,
            'a',
            () async => throw DioException(
                requestOptions: RequestOptions(path: '/'),
                type: DioExceptionType.cancel)),
        throwsA(isA<DioException>()));
    expect(repo.health(SourceKind.game, 'a').lastSuccess, isNull);
    expect(repo.health(SourceKind.game, 'a').lastFailure, isNull);
    repo.dispose();
  });

  test(
      'video adapter tracks searches and episode failures without changing source results',
      () async {
    final repo =
        SourceHealthRepository(read: (_) => null, write: (_, __) async {});
    final raw = _Video();
    final source = ManagedVideoSource(raw, repo);
    expect(await source.search('q'), isEmpty);
    expect(repo.health(SourceKind.anime, source.id).lastSuccess, isNotNull);
    raw.error = const FormatException('bad content');
    await expectLater(source.episodes('/detail'), throwsFormatException);
    expect(repo.health(SourceKind.anime, source.id).failure,
        SourceFailureKind.parsing);
    repo.dispose();
  });

  test(
      'built-in managers retain history access while list providers apply preferences',
      () async {
    final repo = SourcePreferencesRepository(
        read: (_) => jsonEncode({
              'disabled': {
                'novel': ['linovelib'],
                'game': ['galgamezywz']
              },
              'order': {
                'novel': ['lknovel', 'linovelib']
              },
            }),
        write: (_, __) async {});
    final container = ProviderContainer(overrides: [
      sourcePreferencesRepositoryProvider.overrideWithValue(repo)
    ]);
    expect(container.read(novelSourcesProvider).map((s) => s.id), ['lknovel']);
    expect(container.read(novelSourceManagerProvider).byId('linovelib'),
        isNotNull);
    expect(container.read(gameSourcesProvider).map((s) => s.id), ['nekogal']);
    expect(container.read(gameSourceManagerProvider).byId('galgamezywz'),
        isNotNull);
    container.dispose();
  });
}
