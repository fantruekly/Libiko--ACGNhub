import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/images/cover_ratio_cache.dart';
import 'package:libiko/core/widgets/ratio_cover.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

Widget _placeholder(BuildContext _) => const Text('ph');
