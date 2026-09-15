import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_history.dart';
import 'package:acgnhub/core/storage/database.dart';
import 'package:acgnhub/modules/novel/novel_detail_page.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';

class _HistNotifier extends NovelHistoryNotifier {
  @override
  List<NovelHistoryEntry> build() => [
        NovelHistoryEntry(
          sourceKey: 'linovelib',
          novelId: '5340',
          title: '不相容的異種族妻子們',
          chapterId: '334356',
          chapterTitle: '第60話',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      ];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('NovelDetailPage renders title, author and chapters',
      (tester) async {
    const detail = NovelDetail(
      novel: Novel(id: '5340', title: '不相容的異種族妻子們', author: '이만두'),
      volumes: [
        NovelVolume(title: '正文', chapters: [
          NovelChapterRef(id: '334356', title: '第60話 規則（2）'),
        ]),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelDetailProvider(('linovelib', '5340'))
            .overrideWith((ref) async => detail),
      ],
      child: const MaterialApp(
        home: NovelDetailPage(
            sourceKey: 'linovelib', novelId: '5340', title: '不相容的異種族妻子們'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('이만두'), findsOneWidget);
    expect(find.text('正文'), findsOneWidget);
    expect(find.text('第60話 規則（2）'), findsOneWidget);
  });

  testWidgets('favorite toggles and continue-reading shows with history',
      (tester) async {
    const detail = NovelDetail(
      novel: Novel(id: '5340', title: '不相容的異種族妻子們', author: '이만두'),
      volumes: [],
    );
    final container = ProviderContainer(overrides: [
      novelDetailProvider(('linovelib', '5340'))
          .overrideWith((ref) async => detail),
      novelHistoryProvider.overrideWith(_HistNotifier.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: NovelDetailPage(
            sourceKey: 'linovelib', novelId: '5340', title: '不相容的異種族妻子們'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('继续阅读'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('已收藏'), findsOneWidget);
  });

  testWidgets('NovelDetailPage wraps the cover in a Hero', (tester) async {
    const detail = NovelDetail(
      novel: Novel(id: '5340', title: '不相容的異種族妻子們'),
      volumes: [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelDetailProvider(('linovelib', '5340'))
            .overrideWith((ref) async => detail),
      ],
      child: const MaterialApp(
        home: NovelDetailPage(
            sourceKey: 'linovelib', novelId: '5340', title: '不相容的異種族妻子們'),
      ),
    ));
    await tester.pumpAndSettle();
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'novel_linovelib_5340');
  });

  testWidgets('NovelDetailPage shows the cover Hero while loading',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelDetailProvider(('linovelib', '5340'))
            .overrideWith((ref) => Completer<NovelDetail>().future),
      ],
      child: const MaterialApp(
        home: NovelDetailPage(
            sourceKey: 'linovelib', novelId: '5340', title: '不相容的異種族妻子們'),
      ),
    ));
    await tester.pump();

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'novel_linovelib_5340');
  });
}
