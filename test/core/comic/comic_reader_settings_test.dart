import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/comic/comic_reader_settings.dart';
import 'package:acgnhub/core/storage/database.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to continuous vertical', () {
    expect(const ComicReaderSettings().mode,
        ComicReaderMode.continuousVertical);
  });

  test('JSON round-trips the mode', () {
    const settings = ComicReaderSettings(mode: ComicReaderMode.pageHorizontal);
    final restored = ComicReaderSettings.fromJson(settings.toJson());
    expect(restored.mode, ComicReaderMode.pageHorizontal);
  });

  test('an unknown mode falls back to continuous vertical', () {
    final restored = ComicReaderSettings.fromJson({'mode': 'bogus'});
    expect(restored.mode, ComicReaderMode.continuousVertical);
  });

  test('the manager persists and reads the mode', () async {
    await AppDatabase.init();
    final manager = ComicReaderSettingsManager();
    expect(manager.read().mode, ComicReaderMode.continuousVertical);
    await manager.write(
        const ComicReaderSettings(mode: ComicReaderMode.pageHorizontal));
    expect(manager.read().mode, ComicReaderMode.pageHorizontal);
  });

  test('a malformed stored value falls back to the default', () async {
    await AppDatabase.init();
    await AppDatabase().setString('comic_reader_settings', 'not json');
    expect(ComicReaderSettingsManager().read().mode,
        ComicReaderMode.continuousVertical);
  });
}
