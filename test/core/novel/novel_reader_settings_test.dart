import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/novel_reader_settings.dart';

void main() {
  test('defaults', () {
    const s = NovelReaderSettings();
    expect(s.fontSize, 17);
    expect(s.lineHeight, 1.8);
    expect(s.theme, NovelReaderTheme.light);
  });

  test('copyWith changes one field', () {
    const s = NovelReaderSettings();
    final s2 = s.copyWith(fontSize: 22, theme: NovelReaderTheme.dark);
    expect(s2.fontSize, 22);
    expect(s2.theme, NovelReaderTheme.dark);
    expect(s2.lineHeight, 1.8);
  });

  test('round-trips through JSON and clamps out-of-range values', () {
    final decoded = NovelReaderSettings.fromJson(
      json.decode(json.encode(const NovelReaderSettings(fontSize: 22).toJson()))
          as Map<String, dynamic>,
    );
    expect(decoded.fontSize, 22);

    final clamped = NovelReaderSettings.fromJson(const {
      'fontSize': 99,
      'lineHeight': 0.1,
      'theme': 'sepia',
    });
    expect(clamped.fontSize, 28);
    expect(clamped.lineHeight, 1.2);
    expect(clamped.theme, NovelReaderTheme.sepia);
  });

  test('unknown theme falls back to light', () {
    final s = NovelReaderSettings.fromJson(const {'theme': 'weird'});
    expect(s.theme, NovelReaderTheme.light);
  });
}
