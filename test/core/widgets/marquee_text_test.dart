import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/widgets/marquee_text.dart';

void main() {
  testWidgets('short text renders without scrolling', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 200, child: MarqueeText(text: '短标题')),
        ),
      ),
    ));
    expect(find.text('短标题'), findsOneWidget);
    expect(
      find.descendant(
          of: find.byType(MarqueeText), matching: find.byType(MouseRegion)),
      findsNothing,
    );
  });

  testWidgets('long text scrolls while hovered', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 80,
            child: MarqueeText(text: '这是一个非常非常非常长的章节名字需要滚动显示完整'),
          ),
        ),
      ),
    ));
    expect(
      find.descendant(
          of: find.byType(MarqueeText), matching: find.byType(MouseRegion)),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.descendant(
              of: find.byType(MarqueeText), matching: find.byType(Text)))
          .width,
      greaterThan(80),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(MarqueeText)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final transform = tester.widget<Transform>(find.descendant(
      of: find.byType(MarqueeText),
      matching: find.byType(Transform),
    ));
    expect(transform.transform.getTranslation().x, lessThan(0));
  });
}
