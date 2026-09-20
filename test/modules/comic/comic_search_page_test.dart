import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_source.dart';
import 'package:libiko/core/comic/models.dart';
import 'package:libiko/core/widgets/chip_bar.dart';
import 'package:libiko/modules/comic/comic_providers.dart';
import 'package:libiko/modules/comic/comic_search.dart';

class _FakeManager extends ComicSourceManager {
  _FakeManager(this._results);
  final Map<String, List<Comic>> _results;

  @override
  Future<List<Comic>> search(ComicSource source, String keyword,
      {int page = 1}) async {
    return _results[source.key] ?? const [];
  }
}

Widget _app() => ProviderScope(
      overrides: [
        comicSourceManagerProvider.overrideWithValue(_FakeManager({
          'a': [const Comic(id: 'a1', title: 'A漫画')],
          'b': [const Comic(id: 'b1', title: 'B漫画')],
        })),
        comicSourcesProvider.overrideWith((ref) async => [
              ComicSource(
                  name: '源A', key: 'a', version: '1.0.0', canSearch: true),
              ComicSource(
                  name: '源B', key: 'b', version: '1.0.0', canSearch: true),
            ]),
      ],
      child: const MaterialApp(home: ComicSearchPage(initialKeyword: '测试')),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('aggregate search groups results by source', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);

    expect(find.text('A漫画'), findsOneWidget);
    expect(find.text('B漫画'), findsOneWidget);
    // 源名同时出现在 chip 和分组标题上
    expect(find.text('源A'), findsNWidgets(2));
    expect(find.text('源B'), findsNWidgets(2));
  });

  testWidgets('selecting a source shows only that source', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);

    await tester.tap(find.descendant(
        of: find.byType(ChipBar), matching: find.text('源B')));
    await _settle(tester);

    expect(find.text('B漫画'), findsOneWidget);
    expect(find.text('A漫画'), findsNothing);
    // 单源模式不显示分组标题，源名只剩 chip
    expect(find.text('源B'), findsOneWidget);
  });
}
