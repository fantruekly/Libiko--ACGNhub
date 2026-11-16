import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/sources/source_preferences.dart';
import 'package:libiko/core/video/source_priority.dart';

void main() {
  final now = DateTime.utc(2026, 11, 2, 12);
  List<String> ordered(Map<String, SourceHealth> records,
          {SourcePreferences preferences = const SourcePreferences(),
          DateTime? at}) =>
      prioritizeAnimeSources(['slow', 'unknown', 'fast', 'failed'],
          idOf: (id) => id,
          preferences: preferences,
          now: at ?? now,
          health: (id) => records[id] ?? const SourceHealth());

  final records = {
    'slow': SourceHealth(lastPlaybackSuccess: now, lastStartupMs: 5000),
    'fast': SourceHealth(lastPlaybackSuccess: now, lastStartupMs: 1000),
    'failed': SourceHealth(lastPlaybackFailure: now),
  };
  test('real startup success leads, slow failed sources remain eligible', () {
    expect(ordered(records), ['fast', 'slow', 'unknown', 'failed']);
  });
  test('request success alone never counts as playable evidence', () {
    expect(ordered({'failed': SourceHealth(lastSuccess: now)}),
        ['slow', 'unknown', 'fast', 'failed']);
  });
  test('successful starts with missing timing keep a consistent sort order',
      () {
    expect(
        ordered({
          'slow': SourceHealth(lastPlaybackSuccess: now, lastStartupMs: 5000),
          'unknown': SourceHealth(lastPlaybackSuccess: now),
          'fast': SourceHealth(lastPlaybackSuccess: now, lastStartupMs: 1000),
        }),
        ['fast', 'slow', 'unknown', 'failed']);
  });
  test('explicit manual order wins and disabled sources remain excluded', () {
    expect(
        ordered(records,
            preferences: const SourcePreferences(
              order: {
                SourceKind.anime: ['failed', 'unknown', 'slow', 'fast']
              },
              disabled: {
                SourceKind.anime: {'slow'}
              },
            )),
        ['failed', 'unknown', 'fast']);
  });
  test('old success and expired failure return to stable ordinary scheduling',
      () {
    expect(ordered(records, at: now.add(const Duration(days: 8))),
        ['slow', 'unknown', 'fast', 'failed']);
    expect(
        prioritizeAnimeSources(['failed', 'unknown'],
            idOf: (id) => id,
            preferences: const SourcePreferences(),
            health: (id) => records[id] ?? const SourceHealth(),
            now: now.add(const Duration(minutes: 11))),
        ['failed', 'unknown']);
  });
  test('a new failure lowers priority until actual playback recovers', () {
    final history = {
      'fast': SourceHealth(
          lastPlaybackSuccess: now.subtract(const Duration(minutes: 2)),
          lastPlaybackFailure: now)
    };
    expect(ordered(history), ['slow', 'unknown', 'failed', 'fast']);
    history['fast'] = SourceHealth(
        lastPlaybackFailure: now,
        lastPlaybackSuccess: now.add(const Duration(seconds: 1)));
    expect(ordered(history, at: now.add(const Duration(seconds: 2))),
        ['fast', 'slow', 'unknown', 'failed']);
  });
}
