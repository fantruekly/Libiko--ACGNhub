import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_detail_page.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';

void main() {
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
}
