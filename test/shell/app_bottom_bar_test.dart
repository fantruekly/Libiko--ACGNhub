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

  testWidgets('the selected item grows an animated capsule', (tester) async {
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

    double width(String label) =>
        tester.getSize(find.byKey(ValueKey('bar-capsule-$label'))).width;

    expect(width('动漫'), closeTo(64, 0.5));
    expect(width('漫画'), closeTo(32, 0.5));

    await tester.tap(find.text('漫画'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(width('漫画'), greaterThan(32));
    expect(width('漫画'), lessThan(64));

    await tester.pumpAndSettle();
    expect(width('漫画'), closeTo(64, 0.5));
    expect(width('动漫'), closeTo(32, 0.5));
  });
}
