import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/shell/app_sidebar.dart';

void main() {
  testWidgets('sidebar labels are 13px and the selected line animates',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AppSidebar(
            selectedIndex: selected,
            onChanged: (i) => setState(() => selected = i),
            onSettingsTap: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    for (final label in ['动漫', '漫画', '轻小说', '游戏', '设置']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.widget<Text>(find.text('动漫')).style!.fontSize, 13);

    List<double> lineOpacity() => tester
        .widgetList<Opacity>(find.byKey(const ValueKey('sidebar-line')))
        .map((w) => w.opacity)
        .toList();

    expect(lineOpacity(), [1.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.tap(find.text('漫画'));
    await tester.pumpAndSettle();
    expect(lineOpacity(), [0.0, 1.0, 0.0, 0.0, 0.0]);
  });
}
