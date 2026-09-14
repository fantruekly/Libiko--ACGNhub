import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_home.dart';

void main() {
  testWidgets('NovelCard shows title but not author', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 200,
          child: NovelCard(novel: Novel(id: '1', title: '安达与岛村', author: '入间人间')),
        ),
      ),
    ));
    expect(find.text('安达与岛村'), findsOneWidget);
    expect(find.text('入间人间'), findsNothing);
  });

  testWidgets('NovelCard shows a placeholder when there is no cover',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 200,
          child: NovelCard(novel: Novel(id: '1', title: '安达与岛村')),
        ),
      ),
    ));
    expect(find.text('安'), findsOneWidget);
  });
}
