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
    testWidgets('${entry.key} search field has no focus border and is collapsed',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: entry.value),
      ));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      final decoration = field.decoration!;
      expect(decoration.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.errorBorder, InputBorder.none);
      expect(decoration.focusedErrorBorder, InputBorder.none);
      expect(decoration.isCollapsed, isTrue);
      expect(decoration.filled, isFalse);
    });
  }
}
