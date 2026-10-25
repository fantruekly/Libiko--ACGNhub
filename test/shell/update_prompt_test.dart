import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/services/update_controller.dart';
import 'package:libiko/core/services/update_service.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/core/ui/update_dialog.dart';
import 'package:libiko/shell/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _release = UpdateInfo(
    version: '2.0.0', notes: '修复播放和阅读体验', url: 'https://github.com/release');

class _Service extends UpdateService {
  Future<UpdateInfo?> Function() response = () async => _release;
  @override
  Future<UpdateInfo?> check(String currentVersion) => response();
}

void main() {
  late _Service service;
  late UpdateController controller;
  UpdateController createController() => UpdateController(
      service: service,
      loadVersion: () async => '1.0.0',
      read: () => null,
      write: (_) async {});
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
    service = _Service();
  });

  testWidgets(
      'manual Settings check shows skipped release even with automatic checks off',
      (tester) async {
    controller = createController();
    await controller.setAutomatic(false);
    await controller.skipVersion('2.0.0');
    await tester.pumpWidget(ProviderScope(
        overrides: [updateControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: SettingsPage())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ListTile, '检查更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 v2.0.0'), findsOneWidget);
    expect(find.text('当前版本 v1.0.0'), findsOneWidget);
    expect(find.text('修复播放和阅读体验'), findsOneWidget);
    await tester.tap(find.text('跳过此版本'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(controller.skippedVersion, '2.0.0');
  });

  testWidgets(
      'failed check explains the error and retry can open release details',
      (tester) async {
    controller = createController();
    service.response = () async => throw const UpdateCheckException(
        UpdateCheckFailure.timeout, '连接超时，请检查网络后重试');
    await tester.pumpWidget(ProviderScope(
        overrides: [updateControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: SettingsPage())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ListTile, '检查更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('连接超时，请检查网络后重试'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    service.response = () async => _release;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 v2.0.0'), findsOneWidget);
  });

  testWidgets('failed browser launch retains dialog and exposes a copyable URL',
      (tester) async {
    controller = createController();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showUpdateDialog(
                        context, _release, controller,
                        openUrl: (_) async => false),
                    child: const Text('打开'))))));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('前往发布页'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data,
        _release.url);
    expect(find.text('无法打开浏览器，可复制下方链接后手动打开'), findsOneWidget);
    controller.dispose();
  });
}
