import 'dart:async';
import 'package:flutter/services.dart';
import 'package:libiko/core/video/webview_scraper.dart';
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
  test('a local Windows engine failure does not penalize a remote source',
      () async {
    final repo =
        SourceHealthRepository(read: (_) => null, write: (_, __) async {});
    final raw = _Video()..error = PlatformException(code: 'webview_runtime');
    final source = ManagedVideoSource(raw, repo);
    await expectLater(source.search('q'), throwsA(isA<PlatformException>()));
    expect(repo.health(SourceKind.anime, source.id).lastFailure, isNull);
    raw.error =
        PlatformException(code: '0', message: 'Native view is unavailable');
    await expectLater(source.search('q'), throwsA(isA<PlatformException>()));
    expect(repo.health(SourceKind.anime, source.id).lastFailure, isNull);
    await expectLater(
        source.episodes('/detail'), throwsA(isA<PlatformException>()));
    expect(repo.health(SourceKind.anime, source.id).lastFailure, isNull);
    repo.dispose();
  });
  test('playback outcomes persist separately from source request health',
      () async {
    final data = <String, String>{};
    var now = DateTime.utc(2026, 11, 2);
    final repo = SourceHealthRepository(
        read: (key) => data[key],
        write: (key, value) async => data[key] = value,
        clock: () => now);
    await repo.track(SourceKind.anime, 'a', () async => 'result');
    final requestAt = repo.health(SourceKind.anime, 'a').lastSuccess;
    final requestMs = repo.health(SourceKind.anime, 'a').lastRequestMs;
    now = now.add(const Duration(minutes: 1));
    repo.recordPlayback('a',
        success: true, startup: const Duration(milliseconds: 1450));
    final playedAt = now;
    now = now.add(const Duration(minutes: 1));
    repo.recordPlayback('a',
        success: false, startup: const Duration(seconds: 30));
    await repo.flush();
    final fresh = SourceHealthRepository(
        read: (key) => data[key], write: (_, __) async {});
    final health = fresh.health(SourceKind.anime, 'a');
    expect(health.lastSuccess, requestAt);
    expect(health.lastFailure, isNull);
    expect(health.lastRequestMs, requestMs);
    expect(health.playbackSuccesses, 1);
    expect(health.playbackFailures, 1);
    expect(health.lastPlaybackSuccess, playedAt);
    expect(health.lastPlaybackFailure, now);
    expect(health.lastStartupMs, 1450);
    expect(fresh.health(SourceKind.comic, 'a').playbackSuccesses, 0);
    expect(fresh.health(SourceKind.anime, 'other').playbackFailures, 0);
    repo.dispose();
    fresh.dispose();
  });

  test('later source requests preserve playback history', () async {
    final repo =
        SourceHealthRepository(read: (_) => null, write: (_, __) async {});
    repo.recordPlayback('a',
        success: true, startup: const Duration(milliseconds: 700));
    await expectLater(
        repo.track(SourceKind.anime, 'a',
            () async => throw TimeoutException('private-url')),
        throwsA(isA<TimeoutException>()));
    await repo.track(SourceKind.anime, 'a', () async => []);
    final health = repo.health(SourceKind.anime, 'a');
    expect(health.lastRequestMs, isNonNegative);
    expect(health.playbackSuccesses, 1);
    expect(health.playbackFailures, 0);
    expect(health.lastStartupMs, 700);
    expect(health.lastPlaybackSuccess, isNotNull);
    repo.dispose();
  });

  test('old or malformed statistics do not discard valid request history', () {
    final timestamp = DateTime.utc(2026, 11, 2).toIso8601String();
    final old = SourceHealth.fromJson({'success': timestamp});
    expect(old.lastSuccess, DateTime.utc(2026, 11, 2));
    expect(old.playbackSuccesses, 0);
    expect(old.lastStartupMs, isNull);
    final bad = SourceHealth.fromJson({
      'success': timestamp,
      'playbackSuccesses': -1,
      'playbackFailures': '3',
      'lastRequestMs': 1.5,
      'lastStartupMs': -10,
      'lastPlaybackSuccess': [],
      'lastPlaybackFailure': 'invalid',
    });
    expect(bad.lastSuccess, old.lastSuccess);
    expect(bad.playbackSuccesses, 0);
    expect(bad.playbackFailures, 0);
    expect(bad.lastRequestMs, isNull);
    expect(bad.lastStartupMs, isNull);
    expect(bad.lastPlaybackSuccess, isNull);
    expect(bad.lastPlaybackFailure, isNull);
  });

  test('cancelled and queue-busy requests leave timing and playback unchanged',
      () async {
    final repo =
        SourceHealthRepository(read: (_) => null, write: (_, __) async {});
    await repo.track(SourceKind.anime, 'a', () async => []);
    repo.recordPlayback('a', success: false);
    final before = repo.health(SourceKind.anime, 'a');
    await repo.track(SourceKind.anime, 'a', () async => [],
        cancelled: () => true);
    await expectLater(
        repo.track(SourceKind.anime, 'a',
            () async => throw const SourceQueueTimeoutException(),
            ignoreFailure: (error) => error is SourceQueueTimeoutException),
        throwsA(isA<SourceQueueTimeoutException>()));
    expect(identical(repo.health(SourceKind.anime, 'a'), before), isTrue);
    repo.dispose();
  });

  test('playback alone does not imply a successful search request', () {
    final repo =
        SourceHealthRepository(read: (_) => null, write: (_, __) async {});
    repo.recordPlayback('a',
        success: true, startup: const Duration(milliseconds: -1));
    final health = repo.health(SourceKind.anime, 'a');
    expect(health.lastSuccess, isNull);
    expect(health.lastRequestMs, isNull);
    expect(health.lastStartupMs, isNull);
    expect(health.playbackSuccesses, 1);
    repo.recordPlayback(' ', success: true);
    expect(repo.health(SourceKind.anime, ' ').playbackSuccesses, 0);
    repo.dispose();
  });

  test('a new untimed startup clears the previous startup timing', () {
    final repo =
        SourceHealthRepository(read: (_) => null, write: (_, __) async {});
    repo.recordPlayback('a',
        success: true, startup: const Duration(seconds: 2));
    repo.recordPlayback('a', success: true);
    expect(repo.health(SourceKind.anime, 'a').lastStartupMs, isNull);
    repo.dispose();
  });

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

  test('browser queue congestion does not mark a video source unhealthy',
      () async {
    final repo =
        SourceHealthRepository(read: (_) => null, write: (_, __) async {});
    final raw = _Video()..error = const SourceQueueTimeoutException();
    final source = ManagedVideoSource(raw, repo);
    await expectLater(source.episodes('/detail'),
        throwsA(isA<SourceQueueTimeoutException>()));
    expect(repo.health(SourceKind.anime, source.id).lastFailure, isNull);
    expect(repo.health(SourceKind.anime, source.id).lastSuccess, isNull);
    raw.error = const FormatException('bad rule');
    await expectLater(source.episodes('/detail'), throwsFormatException);
    expect(repo.health(SourceKind.anime, source.id).failure,
        SourceFailureKind.parsing);
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
