import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/shell/settings_page.dart';

void main() {
  testWidgets('settings page no longer shows the account/login UI',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('账号'), findsNothing);
    expect(find.text('服务器地址'), findsNothing);
    expect(find.text('登录'), findsNothing);
    expect(find.text('注册'), findsNothing);
    expect(find.text('退出登录'), findsNothing);

    expect(find.text('缓存'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
  });
}
