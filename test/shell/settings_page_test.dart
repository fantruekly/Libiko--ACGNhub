import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/shell/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('settings page no longer shows the account/login UI',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SettingsPage())));

    expect(find.text('账号'), findsNothing);
    expect(find.text('服务器地址'), findsNothing);
    expect(find.text('登录'), findsNothing);
    expect(find.text('注册'), findsNothing);
    expect(find.text('退出登录'), findsNothing);

    expect(find.text('外观'), findsOneWidget);
    expect(find.text('缓存'), findsOneWidget);
    expect(find.text('关于与更新'), findsOneWidget);
  });
}
