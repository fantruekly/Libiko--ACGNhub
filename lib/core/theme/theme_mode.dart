import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

class AppThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'app_theme_mode';

  @override
  ThemeMode build() => _fromString(AppDatabase().getString(_key));

  Future<void> set(ThemeMode mode) async {
    await AppDatabase().setString(_key, _toString(mode));
    state = mode;
  }

  static ThemeMode _fromString(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _toString(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

final appThemeModeProvider =
    NotifierProvider<AppThemeModeNotifier, ThemeMode>(AppThemeModeNotifier.new);
