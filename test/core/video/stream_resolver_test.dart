import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/stream_resolver.dart';

void main() {
  test('accepts a media URL whose path ends with .m3u8 or .mp4', () {
    expect(
      StreamResolver.looksLikeMediaUrl(
          'https://vip15.play-cdn15.com/20230226/41_c8391dc5/index.m3u8'),
      isTrue,
    );
    expect(
      StreamResolver.looksLikeMediaUrl('https://cdn.test/video/1.mp4'),
      isTrue,
    );
    expect(
      StreamResolver.looksLikeMediaUrl('https://cdn.test/v/1.m3u8?token=abc'),
      isTrue,
    );
    expect(
      StreamResolver.looksLikeMediaUrl('https://cdn.test/v/1.mp4#t=10'),
      isTrue,
    );
  });

  test('rejects a player page that merely embeds a media URL in its query', () {
    expect(
      StreamResolver.looksLikeMediaUrl(
          'https://www.bmmdmm.com/hdst/player/artplayer/index.html'
          '?url=https://vip15.play-cdn15.com/20230226/41_c8391dc5/index.m3u8'),
      isFalse,
    );
  });

  test('rejects non-media URLs', () {
    expect(
      StreamResolver.looksLikeMediaUrl('https://www.bmmdmm.com/play/80993-0-0.html'),
      isFalse,
    );
    expect(StreamResolver.looksLikeMediaUrl('https://www.bmmdmm.com/time'), isFalse);
    expect(
      StreamResolver.looksLikeMediaUrl('https://img.test/pic/a.webp'),
      isFalse,
    );
  });
}
