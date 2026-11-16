import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/shell/settings_page.dart';
import 'package:libiko/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('settings page no longer shows the account/login UI',
      (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsPage())));

    expect(find.text('账号'), findsNothing);
    expect(find.text('服务器地址'), findsNothing);
    expect(find.text('登录'), findsNothing);
    expect(find.text('注册'), findsNothing);
    expect(find.text('退出登录'), findsNothing);

    expect(find.text('外观'), findsOneWidget);
    expect(find.text('缓存'), findsOneWidget);
    expect(find.text('关于与更新'), findsOneWidget);
  });

  testWidgets('settings groups remain usable at 320px with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: buildAppDarkTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!),
            home: const SettingsPage())));
    await tester.pumpAndSettle();
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('自动检查更新'), 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
