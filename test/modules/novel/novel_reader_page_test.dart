import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_history.dart';
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
            .overrideWith((ref) async => const NovelChapter(
                title: '第60話',
                blocks: [NovelText('第一段。'), NovelText('第二段。')])),
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

  testWidgets('tapping 下一章 loads the next chapter', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelChapterProvider(('linovelib', '1', 'c1')).overrideWith((ref) async =>
            const NovelChapter(title: '第一章', blocks: [NovelText('甲段')])),
        novelChapterProvider(('linovelib', '1', 'c2')).overrideWith((ref) async =>
            const NovelChapter(title: '第二章', blocks: [NovelText('乙段')])),
        novelDetailProvider(('linovelib', '1')).overrideWith((ref) async =>
            const NovelDetail(novel: Novel(id: '1', title: '书'), volumes: [
              NovelVolume(title: '正文', chapters: [
                NovelChapterRef(id: 'c1', title: '第一章'),
                NovelChapterRef(id: 'c2', title: '第二章'),
              ]),
            ])),
      ],
      child: const MaterialApp(
        home: NovelReaderPage(
            sourceKey: 'linovelib',
            novelId: '1',
            chapterId: 'c1',
            title: '书'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('甲段'), findsOneWidget);
    await tester.tap(find.text('下一章'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('乙段'), findsOneWidget);
  });

  testWidgets('opening a chapter records reading history', (tester) async {
    final container = ProviderContainer(overrides: [
      novelChapterProvider(('linovelib', '1', 'c1')).overrideWith((ref) async =>
          const NovelChapter(title: '第一章', blocks: [NovelText('甲段')])),
      novelDetailProvider(('linovelib', '1')).overrideWith((ref) async =>
          const NovelDetail(novel: Novel(id: '1', title: '书'), volumes: [])),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: NovelReaderPage(
            sourceKey: 'linovelib',
            novelId: '1',
            chapterId: 'c1',
            title: '书',
            cover: 'cover.jpg'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    final history = container.read(novelHistoryProvider);
    expect(history, hasLength(1));
    expect(history.first.novelId, '1');
    expect(history.first.chapterId, 'c1');
    expect(history.first.chapterTitle, '第一章');
    expect(history.first.cover, 'cover.jpg');
  });
}
