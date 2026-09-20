import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/headless_browser_inappwebview.dart';

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

  test('extracts a media URL embedded in a query parameter', () {
    expect(
      mediaUrlFromQuery('https://bf.sbbzy.com/a/'
          '?url=https://cdn.yzzy33-play.com/20260116/4703/index.m3u8'
          '&jctype=normal&next=//gimy.tv/ep-247676-1-2.html'),
      'https://cdn.yzzy33-play.com/20260116/4703/index.m3u8',
    );
  });

  test('skips a relative query value and returns the absolute media URL', () {
    expect(
      mediaUrlFromQuery('https://proxy/a/'
          '?poster=/img/ep1.mp4&url=https://cdn.test/x/index.m3u8'),
      'https://cdn.test/x/index.m3u8',
    );
  });

  test('extracts a protocol-relative embedded media URL', () {
    expect(
      mediaUrlFromQuery('https://proxy/a/?url=//cdn.test/x/index.m3u8'),
      'https://cdn.test/x/index.m3u8',
    );
  });

  test('decodes a percent-encoded embedded media URL', () {
    expect(
      mediaUrlFromQuery(
          'https://proxy/a/?url=https%3A%2F%2Fcdn.test%2Fx%2Findex.m3u8'),
      'https://cdn.test/x/index.m3u8',
    );
  });

  test('returns null when no query value is a media URL', () {
    expect(
        mediaUrlFromQuery('https://proxy/a/?url=https://x/page.html'), isNull);
    expect(mediaUrlFromQuery('https://cdn.test/plain'), isNull);
  });

  test('factory returns the in-app-webview implementation', () async {
    final browser = createHeadlessBrowser();
    expect(browser, isA<InAppWebViewHeadlessBrowser>());
    expect(await browser.eval('1 + 1'), isNull);
    await expectLater(
      browser.load('about:blank'),
      throwsA(isA<HeadlessLoadException>()),
    );
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
