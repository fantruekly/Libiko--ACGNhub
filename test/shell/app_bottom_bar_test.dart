import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/shell/app_bottom_bar.dart';

void main() {
  testWidgets('renders the four module labels and reports taps',
      (tester) async {
    var tapped = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar:
            AppBottomBar(selectedIndex: 0, onChanged: (i) => tapped = i),
      ),
    ));
    for (final label in ['动漫', '漫画', '轻小说', '游戏']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('游戏'));
    expect(tapped, 3);
  });

  testWidgets('the selected item shows a capsule around icon and label',
      (tester) async {
    var index = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: StatefulBuilder(
          builder: (context, setState) => AppBottomBar(
            selectedIndex: index,
            onChanged: (i) => setState(() => index = i),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    double capsuleAlpha(String label) {
      final container = tester.widget<Container>(
          find.byKey(ValueKey('bar-capsule-$label')));
      return (container.decoration as BoxDecoration?)?.color?.a ?? 0;
    }

    expect(capsuleAlpha('动漫'), 1.0);
    expect(capsuleAlpha('漫画'), 0.0);

    await tester.tap(find.text('漫画'));
    await tester.pumpAndSettle();
    expect(capsuleAlpha('漫画'), 1.0);
    expect(capsuleAlpha('动漫'), 0.0);
  });

  testWidgets('the capsule fades in without a dark pass-through',
      (tester) async {
    var index = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: StatefulBuilder(
          builder: (context, setState) => AppBottomBar(
            selectedIndex: index,
            onChanged: (i) => setState(() => index = i),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final cs =
        Theme.of(tester.element(find.byType(AppBottomBar))).colorScheme;
    await tester.tap(find.text('漫画'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    final container = tester.widget<Container>(
        find.byKey(const ValueKey('bar-capsule-漫画')));
    final color = (container.decoration as BoxDecoration).color!;
    expect(color.r, closeTo(cs.secondaryContainer.r, 0.01));
    expect(color.g, closeTo(cs.secondaryContainer.g, 0.01));
    expect(color.b, closeTo(cs.secondaryContainer.b, 0.01));
    expect(color.a, greaterThan(0));
    expect(color.a, lessThan(1));
  });
}
