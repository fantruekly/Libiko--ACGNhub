import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/comic/comic_reader_settings.dart';
import 'package:libiko/core/storage/database.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to page flip', () {
    expect(const ComicReaderSettings().mode, ComicReaderMode.pageHorizontal);
  });

  test('JSON round-trips the mode', () {
    const settings = ComicReaderSettings(mode: ComicReaderMode.pageHorizontal);
    final restored = ComicReaderSettings.fromJson(settings.toJson());
    expect(restored.mode, ComicReaderMode.pageHorizontal);
  });

  test('an unknown mode falls back to page flip', () {
    final restored = ComicReaderSettings.fromJson({'mode': 'bogus'});
    expect(restored.mode, ComicReaderMode.pageHorizontal);
  });

  test('the manager persists and reads the mode', () async {
    await AppDatabase.init();
    final manager = ComicReaderSettingsManager();
    expect(manager.read().mode, ComicReaderMode.pageHorizontal);
    await manager.write(
        const ComicReaderSettings(mode: ComicReaderMode.pageHorizontal));
    expect(manager.read().mode, ComicReaderMode.pageHorizontal);
  });

  test('a malformed stored value falls back to the default', () async {
    await AppDatabase.init();
    await AppDatabase().setString('comic_reader_settings', 'not json');
    expect(ComicReaderSettingsManager().read().mode,
        ComicReaderMode.pageHorizontal);
  });
}
