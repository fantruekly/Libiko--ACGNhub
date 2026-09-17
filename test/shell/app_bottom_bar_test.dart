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
}
