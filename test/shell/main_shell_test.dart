import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/modules/game/game_search.dart';
import 'package:acgnhub/shell/app_sidebar.dart';
import 'package:acgnhub/shell/main_shell.dart';

void main() {
  testWidgets('switching modules cross-fades while keeping every page mounted',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: MainShell()),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    List<double> targetOpacity() => [
          for (var i = 0; i < 4; i++)
            tester
                .widget<AnimatedOpacity>(find.byKey(ValueKey('module-page-$i')))
                .opacity,
        ];

    double renderedOpacity(int i) => tester
        .widget<FadeTransition>(find
            .descendant(
                of: find.byKey(ValueKey('module-page-$i')),
                matching: find.byType(FadeTransition))
            .first)
        .opacity
        .value;

    for (var i = 0; i < 4; i++) {
      final animated = tester
          .widget<AnimatedOpacity>(find.byKey(ValueKey('module-page-$i')));
      expect(animated.duration, const Duration(milliseconds: 250));
      expect(animated.curve, Curves.easeInOut);
    }
    expect(targetOpacity(), [1.0, 0.0, 0.0, 0.0]);

    await tester.tap(find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('漫画'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));
    expect(renderedOpacity(0), greaterThan(0.0));
    expect(renderedOpacity(0), lessThan(1.0));
    expect(renderedOpacity(1), greaterThan(0.0));
    expect(renderedOpacity(1), lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 300));
    expect(renderedOpacity(0), 0.0);
    expect(renderedOpacity(1), 1.0);
    expect(targetOpacity(), [0.0, 1.0, 0.0, 0.0]);
  });

  testWidgets('game tab exposes the search entry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: MainShell()),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('游戏'),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final searchButton = find.byWidgetPredicate((w) =>
        w is IconButton &&
        w.icon is Icon &&
        (w.icon as Icon).icon == Icons.search_rounded);
    expect(searchButton, findsOneWidget);

    await tester.tap(searchButton);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(GameSearchPage), findsOneWidget);
  });
}
