import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/widgets/collapsible_tag_wrap.dart';

const _style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

Widget _host(List<String> tags, double width) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: CollapsibleTagWrap(
              tags: tags,
              labelStyle: _style,
              chipBuilder: (tag) => Container(
                key: ValueKey('chip-$tag'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(tag,
                    style: _style, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('long tag lists collapse to two lines with a toggle',
      (tester) async {
    final tags = List.generate(12, (i) => '标签$i');
    await tester.pumpWidget(_host(tags, 200));
    expect(find.byKey(const ValueKey('tags-toggle')), findsOneWidget);
    final collapsed = tester.widgetList(find.textContaining('标签')).length;
    expect(collapsed, lessThan(tags.length));
    await tester.tap(find.byKey(const ValueKey('tags-toggle')));
    await tester.pumpAndSettle();
    expect(tester.widgetList(find.textContaining('标签')).length, tags.length);
    expect(find.text('收起'), findsOneWidget);
  });

  testWidgets('short tag lists show no toggle', (tester) async {
    await tester.pumpWidget(_host(const ['a', 'b'], 400));
    expect(find.byKey(const ValueKey('tags-toggle')), findsNothing);
  });

  testWidgets('a single very long tag is capped to the available width',
      (tester) async {
    const long = '这是一个非常非常非常非常非常非常长的标签内容';
    await tester.pumpWidget(_host(const [long], 150));
    final chip = tester.getSize(find.byKey(const ValueKey('chip-$long')));
    expect(chip.width, lessThanOrEqualTo(150));
    expect(tester.takeException(), isNull);
  });
}
