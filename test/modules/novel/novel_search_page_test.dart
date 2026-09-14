import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';
import 'package:acgnhub/modules/novel/novel_search.dart';

void main() {
  testWidgets('renders results from the provider', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSearchProvider('关键词').overrideWith((ref) async => const [
              NovelSearchResult(
                  novel: Novel(id: '1', title: '结果书'), sourceKey: 'lknovel'),
            ]),
      ],
      child: const MaterialApp(home: NovelSearchPage(initialKeyword: '关键词')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('结果书'), findsOneWidget);
  });

  testWidgets('shows a prompt before searching', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: NovelSearchPage()),
    ));
    expect(find.text('输入关键词搜索轻小说'), findsOneWidget);
  });

  testWidgets('shows empty message when there are no results', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSearchProvider('关键词').overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: NovelSearchPage(initialKeyword: '关键词')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('没有找到轻小说'), findsOneWidget);
  });
}
