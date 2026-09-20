import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/core/theme/theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  test('defaults to system and persists changes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(appThemeModeProvider), ThemeMode.system);

    await container.read(appThemeModeProvider.notifier).set(ThemeMode.dark);
    expect(container.read(appThemeModeProvider), ThemeMode.dark);

    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    expect(container2.read(appThemeModeProvider), ThemeMode.dark);
  });
}
