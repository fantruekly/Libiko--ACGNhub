import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/widgets/slide_switcher.dart';

Widget _app(int index) => MaterialApp(
      home: Scaffold(
        body: SlideSwitcher(
          id: index,
          index: index,
          child: SizedBox.expand(child: Text('内容$index')),
        ),
      ),
    );

void main() {
  testWidgets('slides forward from the right when the index increases',
      (tester) async {
    await tester.pumpWidget(_app(0));
    await tester.pumpWidget(_app(1));
    await tester.pump(const Duration(milliseconds: 50));

    final incoming = tester.widget<SlideTransition>(find.ancestor(
      of: find.text('内容1'),
      matching: find.byType(SlideTransition),
    ));
    expect(incoming.position.value.dx, greaterThan(0));

    await tester.pumpAndSettle();
    expect(find.text('内容1'), findsOneWidget);
    expect(find.text('内容0'), findsNothing);
  });

  testWidgets('slides backward from the left when the index decreases',
      (tester) async {
    await tester.pumpWidget(_app(2));
    await tester.pumpWidget(_app(1));
    await tester.pump(const Duration(milliseconds: 50));

    final incoming = tester.widget<SlideTransition>(find.ancestor(
      of: find.text('内容1'),
      matching: find.byType(SlideTransition),
    ));
    expect(incoming.position.value.dx, lessThan(0));

    await tester.pumpAndSettle();
    expect(find.text('内容1'), findsOneWidget);
    expect(find.text('内容2'), findsNothing);
  });

  testWidgets('does not animate when only the child rebuilds', (tester) async {
    await tester.pumpWidget(_app(1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(1));
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
    final transition =
        tester.widget<SlideTransition>(find.byType(SlideTransition));
    expect(transition.position.value, Offset.zero);
    expect(find.text('内容1'), findsOneWidget);
  });
}
