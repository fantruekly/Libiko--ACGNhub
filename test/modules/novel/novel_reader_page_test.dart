import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/storage/database.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';
import 'package:acgnhub/modules/novel/novel_reader_page.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('NovelReaderPage renders the chapter title and paragraphs',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelChapterProvider(('linovelib', '5340', '334356'))
            .overrideWith((ref) async =>
                const NovelChapter(title: '第60話', content: '第一段。\n\n第二段。')),
        // Avoid a real network call from the reader's chapter list lookup.
        novelDetailProvider(('linovelib', '5340')).overrideWith((ref) async =>
            const NovelDetail(
                novel: Novel(id: '5340', title: '书名'), volumes: [])),
      ],
      child: const MaterialApp(
        home: NovelReaderPage(
            sourceKey: 'linovelib',
            novelId: '5340',
            chapterId: '334356',
            title: '书名'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('第60話'), findsOneWidget);
    expect(find.text('第一段。'), findsOneWidget);
    expect(find.text('第二段。'), findsOneWidget);
  });
}
