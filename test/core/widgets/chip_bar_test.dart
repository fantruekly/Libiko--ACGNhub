import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/widgets/chip_bar.dart';

const _pillKey = ValueKey('chip-bar-pill');

Widget _app(int index, {ValueChanged<int>? onSelected}) => MaterialApp(
      home: Scaffold(
        body: ChipBar(
          labels: const ['推荐', '排行', '分类'],
          selectedIndex: index,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('renders all labels', (tester) async {
    await tester.pumpWidget(_app(0));
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('排行'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
  });

  testWidgets('tapping a chip reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(_app(0, onSelected: (i) => tapped = i));
    await tester.tap(find.text('分类'));
    expect(tapped, 2);
  });

  testWidgets('highlight slides to the newly selected chip', (tester) async {
    await tester.pumpWidget(_app(0));
    await tester.pumpAndSettle();
    final start = tester.getTopLeft(find.byKey(_pillKey)).dx;

    await tester.pumpWidget(_app(2));
    await tester.pump(const Duration(milliseconds: 40));
    final mid = tester.getTopLeft(find.byKey(_pillKey)).dx;

    await tester.pumpAndSettle();
    final end = tester.getTopLeft(find.byKey(_pillKey)).dx;

    expect(start, lessThan(mid));
    expect(mid, lessThan(end));
  });

  testWidgets('changing the labels jumps instead of animating', (tester) async {
    Widget app(List<String> labels, int index) => MaterialApp(
          home: Scaffold(
            body: ChipBar(
              labels: labels,
              selectedIndex: index,
              onSelected: (_) {},
            ),
          ),
        );

    await tester.pumpWidget(app(const ['推荐', '排行', '分类'], 0));
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(const ['全部', '连载', '完结'], 2));
    final atStart = tester.getTopLeft(find.byKey(_pillKey)).dx;
    await tester.pumpAndSettle();
    final atEnd = tester.getTopLeft(find.byKey(_pillKey)).dx;
    expect(atStart, atEnd);
  });
}
