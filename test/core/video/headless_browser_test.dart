import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/headless_browser_android.dart';
import 'package:libiko/core/video/headless_browser_windows.dart';

void main() {
  test('accepts a media URL whose path ends with .m3u8 or .mp4', () {
    expect(
      looksLikeMediaUrl(
          'https://vip15.play-cdn15.com/20230226/41_c8391dc5/index.m3u8'),
      isTrue,
    );
    expect(looksLikeMediaUrl('https://cdn.test/video/1.mp4'), isTrue);
    expect(looksLikeMediaUrl('https://cdn.test/v/1.m3u8?token=abc'), isTrue);
    expect(looksLikeMediaUrl('https://cdn.test/v/1.mp4#t=10'), isTrue);
  });

  test('rejects a player page that merely embeds a media URL in its query', () {
    expect(
      looksLikeMediaUrl(
          'https://www.bmmdmm.com/hdst/player/artplayer/index.html'
          '?url=https://vip15.play-cdn15.com/20230226/41_c8391dc5/index.m3u8'),
      isFalse,
    );
  });

  test('rejects non-media URLs', () {
    expect(looksLikeMediaUrl('https://www.bmmdmm.com/play/80993-0-0.html'),
        isFalse);
    expect(looksLikeMediaUrl('https://www.bmmdmm.com/time'), isFalse);
    expect(looksLikeMediaUrl('https://img.test/pic/a.webp'), isFalse);
  });

  test('factory returns the Windows implementation on desktop', () {
    expect(createHeadlessBrowser(desktop: true), isA<WindowsHeadlessBrowser>());
  });

  test('factory returns a usable Android implementation on mobile', () async {
    final browser = createHeadlessBrowser(desktop: false);
    expect(browser, isA<AndroidHeadlessBrowser>());
    expect(await browser.eval('1 + 1'), isNull);
    await browser.load('about:blank');
    await browser.dispose();
  });

  test('accepts an extension-less HLS URL reported with a streaming MIME type',
      () {
    expect(
      looksLikeMediaResponse('https://cdn.test/hls/index?sign=abc',
          'application/vnd.apple.mpegurl'),
      isTrue,
    );
    expect(looksLikeMediaResponse('https://cdn.test/x', 'application/x-mpegURL'),
        isTrue);
  });

  test('still accepts media URLs and rejects plain responses', () {
    expect(looksLikeMediaResponse('https://cdn.test/v/1.m3u8', ''), isTrue);
    expect(
        looksLikeMediaResponse('https://cdn.test/page.html', 'text/html'), isFalse);
    expect(looksLikeMediaResponse('https://cdn.test/time', ''), isFalse);
  });
}
