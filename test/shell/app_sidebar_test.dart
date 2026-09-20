import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/shell/app_sidebar.dart';

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
    final selectedStyle = tester.widget<Text>(find.text('动漫')).style!;
    expect(selectedStyle.fontSize, 13);
    expect(selectedStyle.fontWeight, FontWeight.w600);
    expect(selectedStyle.height, 1.4);
    expect(selectedStyle.letterSpacing, isNull);
    expect(selectedStyle.fontFamily, isNull);
    final idleStyle = tester.widget<Text>(find.text('漫画')).style!;
    expect(idleStyle.fontWeight, FontWeight.w500);

    List<double> lineOpacity() => tester
        .widgetList<Opacity>(find.byKey(const ValueKey('sidebar-line')))
        .map((w) => w.opacity)
        .toList();

    expect(lineOpacity(), [1.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.tap(find.text('漫画'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = lineOpacity();
    expect(mid[0], greaterThan(0.0));
    expect(mid[0], lessThan(1.0));
    expect(mid[1], greaterThan(0.0));
    expect(mid[1], lessThan(1.0));

    await tester.pumpAndSettle();
    expect(lineOpacity(), [0.0, 1.0, 0.0, 0.0, 0.0]);
  });

  testWidgets('hovering an item shows a background', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSidebar(
          selectedIndex: 0,
          onChanged: (_) {},
          onSettingsTap: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    Color? bg(String label) {
      final box = tester.widget<AnimatedContainer>(
          find.byKey(ValueKey('sidebar-bg-$label')));
      return (box.decoration as BoxDecoration?)?.color;
    }

    expect(bg('漫画')?.a ?? 0, 0);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('漫画')));
    await tester.pumpAndSettle();
    expect(bg('漫画')!.a, greaterThan(0));
  });
}
