import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/modules/anime/anime_search.dart';
import 'package:libiko/modules/comic/comic_search.dart';
import 'package:libiko/modules/game/game_search.dart';
import 'package:libiko/modules/novel/novel_search.dart';

void main() {
  final pages = <String, Widget>{
    'anime': const AnimeSearchPage(),
    'comic': const ComicSearchPage(),
    'novel': const NovelSearchPage(),
    'game': const GameSearchPage(),
  };

  for (final entry in pages.entries) {
    testWidgets(
        '${entry.key} search enables only usable input and keeps focus after clearing',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: entry.value),
      ));
      await tester.pump();

      FilledButton submit() =>
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, '搜索'));
      expect(submit().onPressed, isNull);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(submit().onPressed, isNull);
      await tester.enterText(find.byType(TextField), '示例关键词');
      await tester.pump();
      expect(submit().onPressed, isNotNull);
      await tester.tap(find.byTooltip('清空输入'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue);
      expect(submit().onPressed, isNull);
    });
  }
}
