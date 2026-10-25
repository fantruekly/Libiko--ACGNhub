import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'core/account/account_service.dart';
import 'core/account/sync_service.dart';
import 'core/platform.dart';
import 'core/services/update_controller.dart';
import 'core/storage/database.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'core/ui/app_messenger.dart';
import 'core/ui/update_dialog.dart';
import 'shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  try {
    await AppDatabase.init();
  } catch (error, stack) {
    debugPrint('[Storage] startup failed: $error\n$stack');
    if (isDesktop) {
      await windowManager.ensureInitialized();
      await windowManager
          .waitUntilReadyToShow(const WindowOptions(title: 'Libiko'), () async {
        await windowManager.show();
      });
    }
    runApp(_StorageRecoveryApp(onRetry: main));
    return;
  }

  final container = ProviderContainer();
  unawaited(container
      .read(accountProvider.notifier)
      .load()
      .then((_) => container.read(syncProvider).sync()));

  if (isDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(960, 640),
      center: true,
      title: 'Libiko',
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(UncontrolledProviderScope(
      container: container, child: const LibikoApp()));
}

class _StorageRecoveryApp extends StatelessWidget {
  const _StorageRecoveryApp({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => MaterialApp(
          home: Scaffold(
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage_rounded, size: 40),
                    const SizedBox(height: 16),
                    const Text('本地资料暂时无法打开'),
                    const SizedBox(height: 8),
                    const Text('原数据未清除，请检查磁盘空间后重试。'),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: onRetry, child: const Text('重试')),
                  ],
                ))),
      ));
}

class LibikoApp extends ConsumerStatefulWidget {
  const LibikoApp({super.key});

  @override
  ConsumerState<LibikoApp> createState() => _LibikoAppState();
}

class _LibikoAppState extends ConsumerState<LibikoApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    try {
      final controller = ref.read(updateControllerProvider);
      final result = await controller.check();
      if (!mounted ||
          result != UpdateCheckResult.available ||
          !controller.automatic) {
        return;
      }
      final update = controller.update!;
      appMessengerKey.currentState?.showSnackBar(SnackBar(
        duration: const Duration(seconds: 12),
        showCloseIcon: true,
        content: Text('发现新版本 v${update.version}'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            final context = _navigatorKey.currentState?.overlay?.context;
            if (context != null) {
              unawaited(showUpdateDialog(context, update, controller));
            }
          },
        ),
      ));
    } catch (_) {
      // Silent: an update check must not disturb startup.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libiko',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(appThemeModeProvider),
      theme: buildAppTheme(),
      darkTheme: buildAppDarkTheme(),
      home: const MainShell(),
    );
  }
}
