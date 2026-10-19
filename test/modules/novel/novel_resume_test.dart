import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/novel/models.dart';
import 'package:libiko/core/novel/novel_history.dart';
import 'package:libiko/core/novel/novel_reader_settings.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/modules/novel/novel_providers.dart';
import 'package:libiko/modules/novel/novel_reader_page.dart';

NovelChapter chapter() => NovelChapter(title: '长篇章节', blocks: [
      for (var i = 0; i < 30; i++)
        NovelText(
            '这是第 $i 段。${List.generate(15, (j) => '第$j句描述故事中的人物与场景。').join()}'),
    ]);

ProviderContainer container() => ProviderContainer(overrides: [
      novelChapterProvider(('s', 'n', 'c'))
          .overrideWith((ref) async => chapter()),
      novelDetailProvider(('s', 'n')).overrideWith((ref) async =>
          const NovelDetail(novel: Novel(id: 'n', title: '书名'), volumes: [])),
    ]);

Future<void> mount(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
          home: NovelReaderPage(
              sourceKey: 's', novelId: 'n', chapterId: 'c', title: '书名'))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('scroll followed by immediate exit persists the final position',
      (tester) async {
    final scope = container();
    await mount(tester, scope);
    final scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent * 0.6);
    await tester.pump();
    await unmount(tester);
    final saved = NovelHistoryManager().forNovel('s', 'n')!;
    expect(saved.scrollFraction, closeTo(0.6, 0.02));
    expect(saved.blockIndex, greaterThan(0));
    expect(saved.anchorText, isNotEmpty);
    scope.dispose();
    await tester.pump();
  });

  testWidgets('reopening restores the passage and changing font preserves it',
      (tester) async {
    final scope = container();
    await mount(tester, scope);
    var scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent * 0.5);
    await tester.pump();
    await unmount(tester);
    final saved = NovelHistoryManager().forNovel('s', 'n')!;
    await mount(tester, scope);
    scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(scroll.offset, greaterThan(0));
    final restored = NovelHistoryManager().forNovel('s', 'n')!;
    expect(restored.blockIndex, saved.blockIndex);
    expect(
        (restored.characterOffset - saved.characterOffset).abs(), lessThan(25));
    await scope.read(novelReaderSettingsProvider.notifier).setFontSize(24);
    await tester.pump();
    await tester.pump();
    final resized = NovelHistoryManager().forNovel('s', 'n')!;
    expect(resized.blockIndex, saved.blockIndex);
    expect(
        (resized.characterOffset - saved.characterOffset).abs(), lessThan(35));
    await unmount(tester);
    scope.dispose();
    await tester.pump();
  });

  testWidgets('backgrounding flushes position without waiting for the throttle',
      (tester) async {
    final scope = container();
    await mount(tester, scope);
    final scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent * 0.3);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(NovelHistoryManager().forNovel('s', 'n')!.scrollFraction,
        closeTo(0.3, 0.02));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await unmount(tester);
    scope.dispose();
    await tester.pump();
  });
}
