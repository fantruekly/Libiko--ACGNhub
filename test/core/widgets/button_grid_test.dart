import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/widgets/button_grid.dart';

void main() {
  testWidgets('mobile keeps two equal columns', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: ButtonGrid(
            desktop: false,
            children: [
              for (var i = 0; i < 3; i++)
                SizedBox(height: 40, child: Text('item$i')),
            ],
          ),
        ),
      ),
    ));
    final first = tester.getTopLeft(find.text('item0'));
    final second = tester.getTopLeft(find.text('item1'));
    final third = tester.getTopLeft(find.text('item2'));
    expect(first.dy, second.dy);
    expect(third.dy, greaterThan(first.dy));
    expect(second.dx - first.dx, closeTo(155, 0.5));
  });

  testWidgets('desktop fits fixed-width buttons and centres the block',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1000,
          child: ButtonGrid(
            desktop: true,
            children: [
              for (var i = 0; i < 6; i++)
                SizedBox(height: 40, child: Text('d$i')),
            ],
          ),
        ),
      ),
    ));
    final first = tester.getTopLeft(find.text('d0'));
    final second = tester.getTopLeft(find.text('d1'));
    final fifth = tester.getTopLeft(find.text('d4'));
    expect(second.dx - first.dx, closeTo(215, 0.5));
    expect(fifth.dy, greaterThan(first.dy)); // 4 per row -> d4 wraps
    // 4 columns * 205 + 3 * 10 = 850; (1000 - 850) / 2 = 75
    expect(first.dx, closeTo(75, 0.5));
    // last row (d4, d5) left-aligns with the first row
    expect(fifth.dx, closeTo(first.dx, 0.5));
  });
}
