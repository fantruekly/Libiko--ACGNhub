import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

enum NovelReaderTheme { light, sepia, dark }

class NovelReaderSettings {
  final double fontSize;
  final double lineHeight;
  final NovelReaderTheme theme;

  const NovelReaderSettings({
    this.fontSize = 17,
    this.lineHeight = 1.8,
    this.theme = NovelReaderTheme.light,
  });

  NovelReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    NovelReaderTheme? theme,
  }) =>
      NovelReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        theme: theme ?? this.theme,
      );

  factory NovelReaderSettings.fromJson(Map<String, dynamic> json) =>
      NovelReaderSettings(
        fontSize: ((json['fontSize'] as num?)?.toDouble() ?? 17)
            .clamp(12, 28)
            .toDouble(),
        lineHeight: ((json['lineHeight'] as num?)?.toDouble() ?? 1.8)
            .clamp(1.2, 2.6)
            .toDouble(),
        theme: NovelReaderTheme.values.firstWhere(
          (t) => t.name == json['theme'],
          orElse: () => NovelReaderTheme.light,
        ),
      );

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'theme': theme.name,
      };
}

class NovelReaderSettingsManager {
  static const _key = 'novel_reader_settings';

  NovelReaderSettings read() {
    final raw = AppDatabase().getString(_key);
    if (raw == null || raw.isEmpty) return const NovelReaderSettings();
    try {
      return NovelReaderSettings.fromJson(
          json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const NovelReaderSettings();
    }
  }

  Future<void> write(NovelReaderSettings settings) async {
    await AppDatabase().setString(_key, json.encode(settings.toJson()));
  }
}

class NovelReaderSettingsNotifier extends Notifier<NovelReaderSettings> {
  final _manager = NovelReaderSettingsManager();

  @override
  NovelReaderSettings build() => _manager.read();

  Future<void> _update(NovelReaderSettings next) async {
    await _manager.write(next);
    state = next;
  }

  Future<void> setFontSize(double value) =>
      _update(state.copyWith(fontSize: value.clamp(12, 28).toDouble()));

  Future<void> setLineHeight(double value) =>
      _update(state.copyWith(lineHeight: value.clamp(1.2, 2.6).toDouble()));

  Future<void> setTheme(NovelReaderTheme theme) =>
      _update(state.copyWith(theme: theme));
}

final novelReaderSettingsProvider =
    NotifierProvider<NovelReaderSettingsNotifier, NovelReaderSettings>(
        NovelReaderSettingsNotifier.new);
