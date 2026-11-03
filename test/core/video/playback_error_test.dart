import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/playback_error.dart';
import 'package:libiko/core/video/stream_resolver.dart';

void main() {
  test('only explicit HTTP statuses skip reparse, not URLs or network errors',
      () {
    for (final text in [
      'HTTP error 403 Forbidden',
      'Server returned 404',
      'status code: 410'
    ]) {
      expect(isDefinitivePlaybackFailure(text), isTrue);
    }
    for (final text in [
      'Failed https://cdn/403.mp4',
      'connection timed out',
      'HTTP 503',
      '404'
    ]) {
      expect(isDefinitivePlaybackFailure(text), isFalse);
    }
  });
  test('resolveFailureMessage includes the source name', () {
    expect(
        resolveFailureMessage('gimy', ResolveFailure.timeout), 'gimy：解析超时，请重试');
    expect(resolveFailureMessage('', ResolveFailure.notFound),
        '未找到可播放地址，源站可能已下架或改版');
    expect(resolveFailureMessage('x', ResolveFailure.network), '网络异常，请检查网络后重试');
  });

  test('playbackErrorLabel classifies 403/404/timeout', () {
    expect(playbackErrorLabel('Failed to open https://x (403 Forbidden)'),
        '被源站拒绝访问');
    expect(playbackErrorLabel('HTTP 404 Not Found'), '播放地址已失效');
    expect(playbackErrorLabel('connection timed out'), '播放超时');
    expect(playbackErrorLabel('Failed to open https://x'), '无法打开播放地址');
  });
}
