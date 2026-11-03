import 'dart:convert';

import '../models/work.dart';
import '../storage/database.dart';

/// Local, bounded hints. Manual selections and history resume never consult it.
class LinePreferenceStore {
  static const _key = 'anime_successful_lines_v1';
  final DateTime Function() clock;
  LinePreferenceStore({DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  String _id(Work work, String source) =>
      jsonEncode([work.type.name, work.sourceId, work.id, source]);

  Map<String, dynamic> _read() {
    try {
      final decoded = jsonDecode(AppDatabase().getString(_key) ?? '{}');
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  String? preferred(Work work, String? source) {
    if (source == null) return null;
    final row = _read()[_id(work, source)];
    if (row is! Map || row['at'] is! int || row['line'] is! String) return null;
    final age = clock().millisecondsSinceEpoch - (row['at'] as int);
    return age >= 0 && age <= const Duration(days: 30).inMilliseconds
        ? row['line'] as String
        : null;
  }

  Future<void> record(Work work, String? source, String? line) async {
    if (source == null || source.isEmpty || line == null || line.isEmpty) {
      return;
    }
    final rows = _read();
    final id = _id(work, source);
    rows.remove(id);
    rows[id] = {'line': line, 'at': clock().millisecondsSinceEpoch};
    while (rows.length > 100) {
      rows.remove(rows.keys.first);
    }
    await AppDatabase().setString(_key, jsonEncode(rows));
  }
}

/// A seek jump or a stalled stream cannot establish a successful line.
class LinePlaybackEvidence {
  Duration? _firstAt, _firstPosition, _lastAt, _lastPosition;
  int _advances = 0;
  bool frame = false;
  bool video = false;

  void interrupt() {
    _firstAt = _firstPosition = _lastAt = _lastPosition = null;
    _advances = 0;
  }

  bool progress(Duration position, Duration elapsed) {
    if (!frame || !video || position <= Duration.zero) return false;
    if (_lastPosition != null && position <= _lastPosition!) return false;
    if (_lastAt != null &&
        (elapsed - _lastAt! > const Duration(seconds: 2) ||
            position - _lastPosition! > const Duration(seconds: 2))) {
      _firstAt = null;
      _advances = 0;
    }
    _firstAt ??= elapsed;
    if (_advances == 0) _firstPosition = position;
    _lastAt = elapsed;
    _lastPosition = position;
    _advances++;
    return _advances >= 5 &&
        elapsed - _firstAt! >= const Duration(seconds: 5) &&
        position - _firstPosition! >= const Duration(seconds: 5);
  }
}
