import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/widgets/button_grid.dart';

void main() {
  testWidgets('lays children out in two equal-width columns', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: TwoColumnButtonGrid(children: [
            for (var i = 0; i < 3; i++)
              SizedBox(height: 40, child: Text('item$i')),
          ]),
        ),
      ),
    ));

    final first = tester.getTopLeft(find.text('item0'));
    final second = tester.getTopLeft(find.text('item1'));
    final third = tester.getTopLeft(find.text('item2'));

    expect(first.dy, second.dy); // same row
    expect(third.dy, greaterThan(first.dy)); // wrapped
    expect(first.dx, lessThan(second.dx));
    expect((second.dx - first.dx), closeTo(155, 0.5)); // (300 - 10) / 2 + 10
  });
}
