import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/playback_diagnostics.dart';

void main() {
  test('diagnostics retain bounded stage timings and validation results', () {
    final log = PlaybackDiagnostics(
        capacity: 2, clock: () => DateTime.utc(2026, 11, 2));
    log.add('old');
    log.add('解析完成', elapsedMs: 1234, verified: false, candidates: 2);
    log.add('开始播放',
        source: 'rule:test',
        line: 'road:1',
        episode: 'episode:2',
        positionMs: 3000);
    final entries = log
        .report()
        .split('\n')
        .map((line) => jsonDecode(line) as Map)
        .toList();
    expect(entries, hasLength(2));
    expect(entries.first['stage'], '解析完成');
    expect(entries.first['elapsedMs'], 1234);
    expect(entries.first['verified'], false);
    expect(entries.first['candidates'], 2);
    expect(entries.last['positionMs'], 3000);
  });
  test('shareable diagnostics strip URLs, credentials and control characters',
      () {
    final log = PlaybackDiagnostics();
    log.add('解析完成\n',
        source: 'rule:https://cdn.test/video.mp4?token=media-secret',
        line: 'Cookie=session-secret',
        episode: 'Authorization: Bearer auth-secret',
        outcome: 'signature=signed-secret');
    final report = log.report();
    for (final secret in [
      'https://',
      'media-secret',
      'session-secret',
      'auth-secret',
      'signed-secret'
    ]) {
      expect(report, isNot(contains(secret)));
    }
    expect(jsonDecode(report)['stage'], '解析完成');
  });
}
