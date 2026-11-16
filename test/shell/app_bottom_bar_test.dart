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

  testWidgets('one capsule moves continuously between selected items',
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

    final capsule = find.byKey(const ValueKey('bar-selection'));
    expect(capsule, findsOneWidget);
    final start = tester.getCenter(find.text('动漫')).dx;
    final destination = tester.getCenter(find.text('游戏')).dx;
    expect(tester.getCenter(capsule).dx, closeTo(start, 0.01));
    await tester.tap(find.text('游戏'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final inFlight = tester.getCenter(capsule).dx;
    expect(inFlight, greaterThan(start));
    expect(inFlight, lessThan(destination));
    await tester.tap(find.text('漫画'));
    await tester.pump();
    expect(tester.getCenter(capsule).dx, closeTo(inFlight, 0.01));
    await tester.pumpAndSettle();
    expect(tester.getCenter(capsule).dx,
        closeTo(tester.getCenter(find.text('漫画')).dx, 0.01));
  });

  testWidgets('320px bar supports enlarged text and reduced motion',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
                builder: (context, setState) => AppBottomBar(
                    selectedIndex: selected,
                    onChanged: (i) => setState(() => selected = i))))));
    await tester.tap(find.text('轻小说'));
    await tester.pump();
    expect(selected, 2);
    expect(tester.takeException(), isNull);
    expect(tester.getCenter(find.byKey(const ValueKey('bar-selection'))).dx,
        closeTo(tester.getCenter(find.text('轻小说')).dx, 0.01));
  });
}
