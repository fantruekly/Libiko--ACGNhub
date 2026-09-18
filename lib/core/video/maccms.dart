import 'dart:convert';

/// A MacCMS play-page player config: the (possibly encrypted) stream URL and
/// its `encrypt` scheme.
class MacCmsPlayer {
  final String url;
  final int encrypt;

  const MacCmsPlayer({required this.url, required this.encrypt});
}

/// Reads `player_aaaa` / `player_data` from [html]. Returns null when neither
/// is present or the JSON is malformed.
MacCmsPlayer? parseMacCmsPlayer(String html) {
  for (final marker in const ['player_aaaa=', 'player_data=']) {
    final object = _extractObject(html, marker);
    if (object == null) continue;
    final url = object['url'];
    if (url is! String || url.isEmpty) continue;
    final rawEncrypt = object['encrypt'];
    final encrypt =
        rawEncrypt is int ? rawEncrypt : int.tryParse('$rawEncrypt') ?? 0;
    return MacCmsPlayer(url: url, encrypt: encrypt);
  }
  return null;
}

/// Decrypts a MacCMS `url`: 0 = plain, 1 = URL-decoded, 2 = base64 then
/// URL-decoded. Returns null for an unsupported scheme or malformed input.
String? decryptMacCmsUrl(String raw, int encrypt) {
  try {
    switch (encrypt) {
      case 0:
        return raw;
      case 1:
        return Uri.decodeComponent(raw);
      case 2:
        final normalized = raw.replaceAll('-', '+').replaceAll('_', '/');
        final padded = normalized + '=' * ((4 - normalized.length % 4) % 4);
        return Uri.decodeComponent(utf8.decode(base64.decode(padded)));
      default:
        return null;
    }
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _extractObject(String html, String marker) {
  final at = html.indexOf(marker);
  if (at < 0) return null;
  final start = html.indexOf('{', at);
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < html.length; i++) {
    final char = html[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        try {
          final decoded = json.decode(html.substring(start, i + 1));
          return decoded is Map<String, dynamic> ? decoded : null;
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null;
}
