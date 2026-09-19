import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/maccms.dart';
import 'package:libiko/core/video/stream_resolver.dart';

class _FakeMacCmsResolver extends MacCmsResolver {
  _FakeMacCmsResolver(this.candidate);
  final MediaCandidate? candidate;

  @override
  Future<MediaCandidate?> resolve(
    String playPageUrl, {
    String? userAgent,
    String? referer,
    Duration timeout = const Duration(seconds: 15),
  }) async =>
      candidate;
}

void main() {
  test('returns the MacCMS candidate without starting a headless browser',
      () async {
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(
          const MediaCandidate('https://cdn.test/x/index.m3u8')),
    );
    final result = await resolver.resolve('https://page/play');
    expect(result?.url, 'https://cdn.test/x/index.m3u8');
  });
}
