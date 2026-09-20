import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/widgets/tag_chip.dart';

void main() {
  testWidgets('renders the label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TagChip(label: '热血')),
    ));
    expect(find.text('热血'), findsOneWidget);
  });
}
