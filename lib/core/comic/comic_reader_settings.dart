import 'dart:convert';

import '../storage/database.dart';

enum ComicReaderMode { continuousVertical, pageHorizontal }

class ComicReaderSettings {
  final ComicReaderMode mode;

  const ComicReaderSettings({this.mode = ComicReaderMode.continuousVertical});

  factory ComicReaderSettings.fromJson(Map<String, dynamic> json) =>
      ComicReaderSettings(
        mode: ComicReaderMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => ComicReaderMode.continuousVertical,
        ),
      );

  Map<String, dynamic> toJson() => {'mode': mode.name};

  ComicReaderSettings copyWith({ComicReaderMode? mode}) =>
      ComicReaderSettings(mode: mode ?? this.mode);
}

class ComicReaderSettingsManager {
  static const _key = 'comic_reader_settings';

  ComicReaderSettings read() {
    final raw = AppDatabase().getString(_key);
    if (raw == null || raw.isEmpty) return const ComicReaderSettings();
    try {
      return ComicReaderSettings.fromJson(
          json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ComicReaderSettings();
    }
  }

  Future<void> write(ComicReaderSettings settings) =>
      AppDatabase().setString(_key, json.encode(settings.toJson()));
}
