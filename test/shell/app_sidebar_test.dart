import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/shell/app_sidebar.dart';

void main() {
  testWidgets('sidebar uses horizontal labels and moves the selected capsule',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: StatefulBuilder(
        builder: (context, setState) => AppSidebar(
          selectedIndex: selected,
          onChanged: (i) => setState(() => selected = i),
          onRecentTap: () {},
          onSettingsTap: () {},
        ),
      )),
    ));
    await tester.pumpAndSettle();
    for (final label in ['动漫', '漫画', '轻小说', '游戏', '最近记录', '设置']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.getSize(find.byType(AppSidebar)).width, 164);
    final selectedStyle = tester.widget<Text>(find.text('动漫')).style!;
    expect(selectedStyle.fontSize, 13);
    expect(selectedStyle.fontWeight, FontWeight.w600);
    expect(selectedStyle.height, 1.4);
    expect(tester.getCenter(find.text('动漫')).dy,
        closeTo(tester.getCenter(find.byIcon(Icons.live_tv_rounded)).dy, 1));
    Color background(String label) => (tester
            .widget<AnimatedContainer>(
                find.byKey(ValueKey('sidebar-bg-$label')))
            .decoration as BoxDecoration)
        .color!;
    expect(background('动漫').a, 1);
    expect(background('漫画').a, 0);
    await tester.tap(find.text('漫画'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(background('动漫').a, 0);
    expect(background('漫画').a, 1);
    expect(tester.widget<Text>(find.text('漫画')).style!.fontWeight,
        FontWeight.w600);
  });

  testWidgets('hovering an item shows a background', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AppSidebar(
      selectedIndex: 0,
      onChanged: (_) {},
      onSettingsTap: () {},
    ))));
    await tester.pumpAndSettle();
    Color? bg(String label) => (tester
            .widget<AnimatedContainer>(
                find.byKey(ValueKey('sidebar-bg-$label')))
            .decoration as BoxDecoration)
        .color;
    expect(bg('漫画')?.a ?? 0, 0);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('漫画')));
    await tester.pumpAndSettle();
    expect(bg('漫画')!.a, greaterThan(0));
  });

  testWidgets('sidebar supports keyboard activation and reduced motion',
      (tester) async {
    var tapped = -1;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: Scaffold(
            body: AppSidebar(
                selectedIndex: 0,
                onChanged: (i) => tapped = i,
                onSettingsTap: () {}))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tapped, 0);
    expect(
        tester
            .widget<AnimatedContainer>(
                find.byKey(const ValueKey('sidebar-bg-动漫')))
            .duration,
        Duration.zero);
  });
}
