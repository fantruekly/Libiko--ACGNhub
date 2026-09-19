import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/headless_browser.dart';

void main() {
  test('keeps only Referer/User-Agent/Origin with canonical names', () {
    final headers = playerHeadersFrom({
      'referer': 'https://bf.sbbzy.com/',
      'USER-AGENT': 'UA/1.0',
      'Origin': 'https://bf.sbbzy.com',
      'Accept': '*/*',
      'Cookie': 'x=1',
    });
    expect(headers, {
      'Referer': 'https://bf.sbbzy.com/',
      'User-Agent': 'UA/1.0',
      'Origin': 'https://bf.sbbzy.com',
    });
  });

  test('drops empty values and returns empty when nothing matches', () {
    expect(playerHeadersFrom({'referer': ''}), isEmpty);
    expect(playerHeadersFrom({'Accept': '*/*'}), isEmpty);
  });

  test('MediaCandidate defaults to empty headers', () {
    const candidate = MediaCandidate('https://x/y.m3u8');
    expect(candidate.headers, isEmpty);
  });
}
