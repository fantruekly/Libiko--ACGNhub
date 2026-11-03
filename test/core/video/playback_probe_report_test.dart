import 'package:flutter_test/flutter_test.dart';
import '../../../tool/playback_probe_report.dart';

void main() {
  test('sampling prefers the exact work over a different season', () {
    expect(selectProbeTitle('葬送的芙莉莲', ['葬送的芙莉莲 第二季', '葬送的芙莉莲']), 1);
  });
  test('continuous real progress needs both wall time and repeated advancement',
      () {
    final evidence = PlaybackObservation();
    for (var second = 1; second <= 12; second++) {
      evidence.record(Duration(seconds: second), Duration(seconds: second));
    }
    expect(evidence.stableAt(const Duration(seconds: 12)), isTrue);
    expect(evidence.toJson(const Duration(seconds: 12))['progressEvents'], 12);
  });

  test('a seek jump or stalled clock cannot satisfy sustained playback', () {
    final jump = PlaybackObservation();
    jump.record(const Duration(seconds: 1), Duration.zero);
    jump.record(const Duration(minutes: 5), const Duration(seconds: 1));
    expect(jump.stableAt(const Duration(seconds: 11)), isFalse);
    final stall = PlaybackObservation();
    for (var second = 1; second <= 6; second++) {
      stall.record(Duration(seconds: second), Duration(seconds: second));
    }
    stall.record(const Duration(seconds: 11), const Duration(seconds: 12));
    expect(stall.stableAt(const Duration(seconds: 12)), isFalse);
  });

  test('report redacts signed URLs and bearer credentials', () {
    expect(redactProbeText('Failed https://cdn/video?token=secret Bearer key'),
        'Failed [URL] [TOKEN]');
  });

  test('markdown separates unavailable samples from verified playback', () {
    final text = playbackAuditMarkdown({
      'startedAt': '2026-11-02',
      'status': 'completed',
      'observeSeconds': 10,
      'samples': [
        {
          'source': '源',
          'keyword': '词',
          'title': '名|称\n第二行',
          'status': 'resolve_failed',
          'failureStage': 'resolve',
          'lineResults': [
            {
              'line': '主线',
              'status': 'resolve_failed',
              'resolveFailure': 'timeout'
            },
            {'line': '备用', 'status': 'passed'},
          ],
        }
      ],
    });
    expect(text, contains('名／称 第二行'));
    expect(text, contains('解析失败'));
    expect(text, contains('至少连续观察 10 秒'));
    expect(text, contains('主线 | 解析失败 | timeout'));
    expect(text, contains('备用 | 通过 | —'));
  });
}
