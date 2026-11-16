import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import 'headless_browser.dart';

/// Mirrors the public cloud player protocol; never executes remote scripts.
class MgnacgAdapter {
  static bool supports(String page) {
    final uri = Uri.tryParse(page);
    return uri?.scheme == 'https' &&
        uri?.host == 'www.mgnacg.com' &&
        uri!.path.startsWith('/bangumi/');
  }

  static String? parserUrl(String source, String encrypted) {
    const paths = {
      '2_': '',
      '5_': 'yp2.php',
      '6_': 'yp3.php',
      '4_': 'ccxl.php',
    };
    if (!paths.containsKey(source) ||
        encrypted.length > 8192 ||
        !RegExp(r'^[a-zA-Z0-9%+/=_-]+$').hasMatch(encrypted)) {
      return null;
    }
    return 'https://play.mknacg.top:8585/cloudplay/${paths[source]}?url=$encrypted';
  }

  /// Public setting.js derives the AES key from two per-response meta IDs.
  /// An empty result means the parser supplied no resource, not a media URL.
  static String? mediaFromParser(String html) {
    try {
      String? viewport, charset;
      for (final match
          in RegExp(r'<meta\b[^>]*>', caseSensitive: false).allMatches(html)) {
        final attributes = <String, String>{};
        for (final a in RegExp(r'''([\w-]+)\s*=\s*["']([^"']*)["']''')
            .allMatches(match[0]!)) {
          attributes[a[1]!.toLowerCase()] = a[2]!;
        }
        final id = attributes['id'];
        if (id == null || !id.startsWith('now_')) continue;
        if (attributes['name'] == 'viewport') viewport = id.substring(4);
        if (attributes['charset']?.toLowerCase() == 'utf-8') {
          charset = id.substring(4);
        }
      }
      if (viewport == null ||
          charset == null ||
          charset.length != 10 ||
          viewport.length != 10 ||
          charset.split('').toSet().length != 10 ||
          !RegExp(r'^\d{10}$').hasMatch(charset)) {
        return null;
      }
      final sorted = List<int>.generate(10, (i) => i)
        ..sort((a, b) => charset![a].compareTo(charset[b]));
      final seed = sorted.map((i) => viewport![i]).join();
      final digest = md5.convert(utf8.encode('${seed}Mknacg123321')).toString();
      final encrypted =
          RegExp(r'''["']url["']\s*:\s*["']([a-zA-Z0-9+/=]+)["']''')
              .firstMatch(html)?[1];
      if (encrypted == null || encrypted.length > 32768) return null;
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
      cipher.init(
          false,
          PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV(
                  KeyParameter(
                      Uint8List.fromList(utf8.encode(digest.substring(16)))),
                  Uint8List.fromList(utf8.encode(digest.substring(0, 16)))),
              null));
      final value =
          utf8.decode(cipher.process(base64.decode(encrypted))).trim();
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !['https', 'http'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          !looksLikeMediaUrl(value)) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }
}
