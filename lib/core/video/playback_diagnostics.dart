import 'dart:convert';

/// Bounded event trail. URLs, request headers and raw native errors are not
/// accepted; imported source labels are sanitized before sharing too.
class PlaybackDiagnostics {
  PlaybackDiagnostics({DateTime Function()? clock, this.capacity = 40})
      : assert(capacity > 0),
        _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  final int capacity;
  final _entries = <Map<String, Object?>>[];
  void add(String stage,
      {String? source,
      String? line,
      String? episode,
      int? elapsedMs,
      bool? verified,
      int? candidates,
      String? outcome,
      int? positionMs,
      int? durationMs}) {
    _entries.add({
      'time': _clock().toIso8601String(),
      'stage': _safe(stage),
      if (source != null) 'source': _safe(source),
      if (line != null) 'line': _safe(line),
      if (episode != null) 'episode': _safe(episode),
      if (elapsedMs != null) 'elapsedMs': elapsedMs,
      if (verified != null) 'verified': verified,
      if (candidates != null) 'candidates': candidates,
      if (outcome != null) 'outcome': _safe(outcome),
      if (positionMs != null) 'positionMs': positionMs,
      if (durationMs != null) 'durationMs': durationMs,
    });
    while (_entries.length > capacity) {
      _entries.removeAt(0);
    }
  }

  String report() => _entries.map(jsonEncode).join('\n');
  static String _safe(String value) {
    final clean = value
        .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '[地址已隐藏]')
        .replaceAll(
            RegExp(r'authorization\s*[:=]\s*(?:bearer|basic)\s+[^\s,;]+',
                caseSensitive: false),
            'Authorization=[已隐藏]')
        .replaceAllMapped(
            RegExp(
                r'(token|authorization|cookie|signature|access_key|secret|password)\s*[:=]\s*[^\s,;]+',
                caseSensitive: false),
            (match) => '${match[1]}=[已隐藏]')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .trim();
    return clean.length <= 100 ? clean : clean.substring(0, 100);
  }
}
