import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_image.dart';
import 'package:libiko/core/comic/comic_reader_settings.dart';
import 'package:libiko/core/comic/comic_source.dart';
import 'package:libiko/core/comic/models.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/modules/comic/comic_providers.dart';
import 'package:libiko/modules/comic/comic_reader_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ContinuousSettings extends ComicReaderSettingsNotifier {
  @override
  ComicReaderSettings build() =>
      const ComicReaderSettings(mode: ComicReaderMode.continuousVertical);
}

class _FakeImageProvider extends ComicImageProvider {
  _FakeImageProvider() : super(ComicSourceManager());
  static final Uint8List _png = Uint8List.fromList(const <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, //
    0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, //
    0x0D, 0x0A, 0x2D, 0xB4, //
    0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);
  @override
  Future<ImageProvider> resolve(
          String sourceKey, String comicId, String chapterId, String url) async =>
      MemoryImage(_png);
  @override
  double? ratioOf(String url) => null;
  @override
  void rememberRatio(String url, double ratio) {}
  @override
  Future<void> prefetch(
      String sourceKey, String comicId, String chapterId, String url) async {}
  @override
  Future<void> prefetchRatios(List<String> urls,
      {String? sourceKey,
      String? comicId,
      String? chapterId,
      int concurrency = 4,
      PrefetchCancelToken? cancelToken}) async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('desktop fits each page to the viewport height', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        comicEpProvider(('s', 'c', 'ch'))
            .overrideWith((ref) async => const ComicEp(images: ['u0', 'u1'])),
        comicDetailProvider(('s', 'c')).overrideWith((ref) async =>
            const ComicDetails(id: 'c', title: 'T', chapters: {'ch': '第1话'})),
        comicImageProvider.overrideWithValue(_FakeImageProvider()),
        comicReaderSettingsProvider.overrideWith(_ContinuousSettings.new),
      ],
      child: const MaterialApp(
        home: ComicReaderPage(sourceKey: 's', comicId: 'c', chapterId: 'ch'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final box = tester.getSize(find.byKey(const ValueKey('page-box-0')));
    expect(box.height, closeTo(800, 1));
    expect(box.width, closeTo(1000, 1));

    final image = tester.widget<Image>(find.descendant(
        of: find.byKey(const ValueKey('page-box-0')),
        matching: find.byType(Image)));
    expect(image.fit, BoxFit.contain);
  });
}
