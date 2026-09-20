import 'dart:convert';
import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/novel/novel_reader_settings.dart';

void main() {
  test('defaults', () {
    const s = NovelReaderSettings();
    expect(s.fontSize, 17);
    expect(s.lineHeight, 1.8);
    expect(s.theme, NovelReaderTheme.auto);
  });

  test('defaults to auto', () {
    expect(const NovelReaderSettings().theme, NovelReaderTheme.auto);
    expect(NovelReaderSettings.fromJson(const {}).theme, NovelReaderTheme.auto);
  });

  test('parses an explicit theme', () {
    expect(NovelReaderSettings.fromJson(const {'theme': 'dark'}).theme,
        NovelReaderTheme.dark);
  });

  test('resolveTheme follows the app for auto', () {
    expect(resolveTheme(NovelReaderTheme.auto, Brightness.dark),
        NovelReaderTheme.dark);
    expect(resolveTheme(NovelReaderTheme.auto, Brightness.light),
        NovelReaderTheme.light);
    expect(resolveTheme(NovelReaderTheme.sepia, Brightness.dark),
        NovelReaderTheme.sepia);
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

  test('unknown theme falls back to auto', () {
    final s = NovelReaderSettings.fromJson(const {'theme': 'weird'});
    expect(s.theme, NovelReaderTheme.auto);
  });
}
