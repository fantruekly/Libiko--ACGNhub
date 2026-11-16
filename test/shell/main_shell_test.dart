import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/modules/game/game_search.dart';
import 'package:libiko/modules/game/game_providers.dart';
import 'package:libiko/shell/app_sidebar.dart';
import 'package:libiko/shell/main_shell.dart';
import 'package:libiko/shell/app_bottom_bar.dart';
import 'package:libiko/core/storage/database.dart';

void main() {
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'),
            (call) async => call.method == 'isMaximized' ? false : null);
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });
  testWidgets(
      'switching modules cross-fades while keeping visited pages mounted',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: MainShell()),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    double targetOpacity(int i) => tester
        .widget<AnimatedOpacity>(find.byKey(ValueKey('module-page-$i')))
        .opacity;

    double renderedOpacity(int i) => tester
        .widget<FadeTransition>(find
            .descendant(
                of: find.byKey(ValueKey('module-page-$i')),
                matching: find.byType(FadeTransition))
            .first)
        .opacity
        .value;

    final first = tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('module-page-0')));
    expect(first.duration, const Duration(milliseconds: 250));
    expect(first.curve, Curves.easeInOut);
    expect(targetOpacity(0), 1.0);
    for (var i = 1; i < 4; i++) {
      expect(find.byKey(ValueKey('module-page-$i')), findsNothing);
    }

    await tester.tap(find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('漫画'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));
    expect(renderedOpacity(0), greaterThan(0.0));
    expect(renderedOpacity(0), lessThan(1.0));
    expect(renderedOpacity(1), 1.0);

    await tester.pump(const Duration(milliseconds: 300));
    expect(renderedOpacity(0), 0.0);
    expect(renderedOpacity(1), 1.0);
    expect(targetOpacity(0), 0.0);
    expect(targetOpacity(1), 1.0);

    await tester.tap(find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('动漫'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));
    expect(renderedOpacity(0), greaterThan(0.0));
    expect(renderedOpacity(0), lessThan(1.0));
    expect(renderedOpacity(1), greaterThan(0.0));
    expect(renderedOpacity(1), lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 300));
    expect(renderedOpacity(0), 1.0);
    expect(renderedOpacity(1), 0.0);

    expect(find.byKey(const ValueKey('module-page-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-page-1')), findsOneWidget);
    for (var i = 2; i < 4; i++) {
      expect(find.byKey(ValueKey('module-page-$i')), findsNothing);
    }
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

  testWidgets('desktop navigation can be collapsed and restored',
      (tester) async {
    await tester
        .pumpWidget(const ProviderScope(child: MaterialApp(home: MainShell())));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(find.byKey(const ValueKey('sidebar-panel'))).width,
        AppSidebar.width);
    await tester.tap(find.byKey(const ValueKey('sidebar-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        tester.getSize(find.byKey(const ValueKey('sidebar-panel'))).width, 0);
    await tester.tap(find.byKey(const ValueKey('sidebar-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(find.byKey(const ValueKey('sidebar-panel'))).width,
        AppSidebar.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px layout switches to bottom navigation without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
        overrides: [gameSourcesProvider.overrideWithValue([])],
        child: const MaterialApp(home: MainShell())));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppSidebar), findsNothing);
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.descendant(
        of: find.byType(AppBottomBar), matching: find.text('游戏')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('module-page-3')), findsOneWidget);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
