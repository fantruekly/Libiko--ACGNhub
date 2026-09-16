import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/novel/models.dart';
import 'package:libiko/modules/novel/novel_home.dart';

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

  testWidgets('NovelCard wraps the cover in a Hero when heroTag is given',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 200,
          child: NovelCard(
              novel: Novel(id: '1', title: '安达与岛村'),
              heroTag: 'novel_linovelib_1'),
        ),
      ),
    ));
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'novel_linovelib_1');
  });

  testWidgets('NovelCard has no Hero without a heroTag', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 200,
          child: NovelCard(novel: Novel(id: '1', title: '安达与岛村')),
        ),
      ),
    ));
    expect(find.byType(Hero), findsNothing);
  });
}
