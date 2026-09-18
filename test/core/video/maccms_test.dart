import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/maccms.dart';

const _encrypted =
    'JTY4JTc0JTc0JTcwJTczJTNBJTJGJTJGJTZEJTYxJTZGJTM2JTJFJTZBJTc4JTY0JTc1JTZFJTcyJTc1JTY5JTJFJTc0JTZGJTcwJTJGJTY0JTJGJTY2JTY5JTZDJTY1JTJGJTM1JTYyJTY0JTY2JTY2JTMzJTMxJTYyJTMzJTMwJTY0JTYzJTMwJTMyJTM0JTM3JTMzJTYxJTY2JTMwJTY0JTMxJTMyJTY0JTY2JTYxJTM5JTM4JTM5JTMzJTMwJTM0JTJGJTI1JTQ1JTM3JTI1JTQxJTQzJTI1JTQxJTQzJTMwJTMxJTI1JTQ1JTM5JTI1JTM5JTQyJTI1JTM4JTM2JTJFJTZEJTcwJTM0';
const _decoded =
    'https://mao6.jxdunrui.top/d/file/5bdff31b30dc02473af0d12dfa989304/%E7%AC%AC01%E9%9B%86.mp4';

void main() {
  test('parses player_aaaa with a nested vod_data object', () {
    final html = '<script>var player_aaaa={"encrypt":2,'
        '"vod_data":{"vod_name":"x","nested":{"a":1}},'
        '"url":"$_encrypted"};</script>';
    final player = parseMacCmsPlayer(html);
    expect(player, isNotNull);
    expect(player!.encrypt, 2);
    expect(player.url, _encrypted);
  });

  test('parses player_data with encrypt 0', () {
    final html = '<script>var player_data={"encrypt":0,'
        '"url":"https://cdn.test/x/index.m3u8"};</script>';
    final player = parseMacCmsPlayer(html);
    expect(player?.encrypt, 0);
    expect(player?.url, 'https://cdn.test/x/index.m3u8');
  });

  test('returns null without a player config or with malformed JSON', () {
    expect(parseMacCmsPlayer('<html>none</html>'), isNull);
    expect(parseMacCmsPlayer('var player_aaaa={oops};'), isNull);
  });

  test('decrypts encrypt 0, 1 and 2', () {
    expect(decryptMacCmsUrl('https://x/a.m3u8', 0), 'https://x/a.m3u8');
    expect(decryptMacCmsUrl('%68%74%74%70%73', 1), 'https');
    expect(decryptMacCmsUrl(_encrypted, 2), _decoded);
  });

  test('returns null for unsupported encryption or bad base64', () {
    expect(decryptMacCmsUrl('x', 3), isNull);
    expect(decryptMacCmsUrl('!!!not-base64!!!', 2), isNull);
  });

  test('decrypts URL-safe base64 with padding', () {
    final standard = base64.encode(utf8.encode('~~~'));
    expect(standard, contains('+'));
    final urlSafe = standard.replaceAll('+', '-').replaceAll('/', '_');
    expect(decryptMacCmsUrl(urlSafe, 2), '~~~');

    final padded = base64.encode(utf8.encode('~~~~'));
    expect(padded, endsWith('=='));
    expect(decryptMacCmsUrl(padded.replaceAll('=', ''), 2), '~~~~');
  });
}
