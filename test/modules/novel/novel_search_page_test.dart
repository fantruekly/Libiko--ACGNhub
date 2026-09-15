import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_source.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';
import 'package:acgnhub/modules/novel/novel_search.dart';

class _FakeSource extends NovelSource {
  _FakeSource(this.results, {this.delay = Duration.zero, String id = 'fake'})
      : _id = id;
  final List<Novel> results;
  final Duration delay;
  final String _id;
  @override
  String get id => _id;
  @override
  String get name => _id;
  @override
  String get baseUrl => 'https://x';
  @override
  List<NovelBrowseGroup> get browseGroups => const [];
  @override
  Future<NovelHome> home() async => const NovelHome(sections: []);
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async =>
      NovelList(items: const [], page: page, hasMore: false);
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return results;
  }

  @override
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), volumes: []);
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async =>
      const NovelChapter(title: 't', blocks: []);
}

Widget _app(List<Novel> results) => ProviderScope(
      overrides: [
        novelSourceManagerProvider.overrideWithValue(
            NovelSourceManager(sources: [_FakeSource(results)])),
      ],
      child: const MaterialApp(home: NovelSearchPage(initialKeyword: '关键词')),
    );

void main() {
  testWidgets('renders results from the sources', (tester) async {
    await tester.pumpWidget(_app(const [Novel(id: '1', title: '结果书')]));
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
    await tester.pumpWidget(_app(const []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('没有找到轻小说'), findsOneWidget);
  });

  testWidgets('shows fast source results without waiting for a slow source',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSourceManagerProvider.overrideWithValue(NovelSourceManager(
          sources: [
            _FakeSource(const [Novel(id: '1', title: '快源结果')], id: 'fast'),
            _FakeSource(const [Novel(id: '2', title: '慢源结果')],
                id: 'slow', delay: const Duration(seconds: 5)),
          ],
        )),
      ],
      child: const MaterialApp(home: NovelSearchPage(initialKeyword: '关键词')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('快源结果'), findsOneWidget);
    expect(find.text('慢源结果'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('慢源结果'), findsOneWidget);
  });
}
