import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_source.dart';
import 'package:libiko/core/comic/models.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/modules/comic/comic_detail_page.dart';
import 'package:libiko/modules/comic/comic_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = ComicSource(name: 'X', key: 'x', version: '1.0.0');
const _longTag = '这是一个非常非常非常非常非常非常长的标签内容';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('over-long tags are ellipsized to a single line', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        comicSourcesProvider.overrideWith((ref) async => [_source]),
        comicLoginProvider('x').overrideWith((ref) async => false),
        comicDetailProvider(('x', '1')).overrideWith((ref) async =>
            const ComicDetails(id: '1', title: '有内容', tags: [_longTag])),
      ],
      child: const MaterialApp(
        home: ComicDetailPage(sourceKey: 'x', comicId: '1', title: '测试漫画'),
      ),
    ));
    await tester.pumpAndSettle();

    final tag = tester.widget<Text>(find.text(_longTag));
    expect(tag.maxLines, 1);
    expect(tag.overflow, TextOverflow.ellipsis);
  });
}
