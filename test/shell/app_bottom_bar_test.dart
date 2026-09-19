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

    Color? capsuleColor(String label) {
      final container = tester.widget<Container>(
          find.byKey(ValueKey('bar-capsule-$label')));
      return (container.decoration as BoxDecoration?)?.color;
    }

    expect(capsuleColor('动漫'), isNot(Colors.transparent));
    expect(capsuleColor('漫画'), Colors.transparent);

    await tester.tap(find.text('漫画'));
    await tester.pumpAndSettle();
    expect(capsuleColor('漫画'), isNot(Colors.transparent));
    expect(capsuleColor('动漫'), Colors.transparent);
  });
}
