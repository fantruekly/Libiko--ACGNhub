import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/main.dart';
import 'package:libiko/core/services/update_controller.dart';
import 'package:libiko/core/services/update_service.dart';

class _UpdateService extends UpdateService {
  @override
  Future<UpdateInfo?> check(String currentVersion) async => const UpdateInfo(
      version: '2.0.0', notes: '启动更新提示测试', url: 'https://github.com/release');
}

void main() {
  testWidgets('App launches with sidebar navigation', (tester) async {
    SharedPreferences.setMockInitialValues({
      'updates.preferences.v1': '{"automatic":false}',
    });
    await AppDatabase.init();

    await tester.pumpWidget(const ProviderScope(child: LibikoApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('动漫'), findsWidgets);
    expect(find.text('漫画'), findsWidgets);
    expect(find.text('轻小说'), findsWidgets);
    expect(find.text('游戏'), findsWidgets);
  });

  testWidgets(
      'startup notice opens shared update details through the app navigator',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
    final updates = UpdateController(
        service: _UpdateService(),
        loadVersion: () async => '1.0.0',
        read: () => null,
        write: (_) async {});
    await tester.pumpWidget(ProviderScope(overrides: [
      updateControllerProvider.overrideWith((ref) => updates),
    ], child: const LibikoApp()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('发现新版本 v2.0.0'), findsOneWidget);
    await tester.tap(find.text('查看'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('启动更新提示测试'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
  });
}
