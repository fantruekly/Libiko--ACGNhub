import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/images/cover_ratio_cache.dart';
import 'package:libiko/core/widgets/ratio_cover.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FlakyImageProvider extends ImageProvider<_FlakyImageProvider> {
  int loadCount = 0;

  @override
  Future<_FlakyImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_FlakyImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
      _FlakyImageProvider key, ImageDecoderCallback decode) {
    loadCount++;
    final completer = Completer<ImageInfo>();
    if (loadCount == 1) {
      completer.completeError(Exception('first load fails'));
    } else {
      completer.complete(ImageInfo(image: _onePixel()));
    }
    return OneFrameImageStreamCompleter(completer.future);
  }

  @override
  bool operator ==(Object other) =>
      other is _FlakyImageProvider && other.hashCode == hashCode;

  @override
  int get hashCode => 1;
}

ui.Image _onePixel() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0xFF000000));
  return recorder.endRecording().toImageSync(1, 1);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('desktop mode adds no AspectRatio (the grid sizes it)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(
        width: 200,
        height: 300,
        child: RatioCover(
          url: null,
          enabled: false,
          placeholderBuilder: _placeholder,
        ),
      ),
    ));
    expect(find.byType(AspectRatio), findsNothing);
    expect(find.text('ph'), findsOneWidget);
  });

  testWidgets('mobile mode uses the cached ratio', (tester) async {
    final cache = CoverRatioCache();
    await cache.remember('https://x/a.jpg', 0.5);
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 200,
        child: RatioCover(
          url: 'https://x/a.jpg',
          enabled: true,
          cache: cache,
          placeholderBuilder: _placeholder,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final ar = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ar.aspectRatio, 0.5);
  });

  testWidgets('mobile mode falls back before the ratio is known',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 200,
        child: RatioCover(
          url: 'https://unknown.example/none.jpg',
          enabled: true,
          cache: CoverRatioCache(),
          fallbackRatio: 0.75,
          placeholderBuilder: _placeholder,
        ),
      ),
    ));
    await tester.pump();
    final ar = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ar.aspectRatio, 0.75);
  });

  testWidgets('decodes at the laid-out width times the device pixel ratio',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: RatioCover(
              url: 'https://example.test/a.jpg',
              enabled: false,
              placeholderBuilder: _placeholder,
            ),
          ),
        ),
      ),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as CachedNetworkImageProvider;
    final raw = (300 * tester.view.devicePixelRatio).clamp(200, 1600).round();
    final expected = (((raw + 127) ~/ 128) * 128).clamp(200, 1600);
    expect(provider.maxWidth, expected);
  });

  testWidgets('a reused element picks up a new url', (tester) async {
    final cache = CoverRatioCache();
    await cache.remember('https://x/a.jpg', 0.5);
    await cache.remember('https://x/b.jpg', 1.5);
    Widget build(String url) => MaterialApp(
          home: SizedBox(
            width: 200,
            child: RatioCover(
              url: url,
              enabled: true,
              cache: cache,
              placeholderBuilder: _placeholder,
            ),
          ),
        );
    await tester.pumpWidget(build('https://x/a.jpg'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 0.5);
    await tester.pumpWidget(build('https://x/b.jpg'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 1.5);
  });

  testWidgets('retries a failed cover load and then shows the image',
      (tester) async {
    final provider = _FlakyImageProvider();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 150,
          child: RatioCover(
            url: 'https://x/cover.jpg',
            enabled: false,
            placeholderBuilder: (_) => const Text('placeholder'),
            providerBuilder: (url, width, headers) => provider,
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('placeholder'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(provider.loadCount, greaterThanOrEqualTo(2));
    expect(find.text('placeholder'), findsNothing);
  });
}

Widget _placeholder(BuildContext _) => const Text('ph');
