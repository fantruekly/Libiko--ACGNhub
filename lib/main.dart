import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'core/account/account_service.dart';
import 'core/account/sync_service.dart';
import 'core/platform.dart';
import 'core/storage/database.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'core/ui/app_messenger.dart';
import 'shell/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await AppDatabase.init();

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

class LibikoApp extends ConsumerStatefulWidget {
  const LibikoApp({super.key});

  @override
  ConsumerState<LibikoApp> createState() => _LibikoAppState();
}

class _LibikoAppState extends ConsumerState<LibikoApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libiko',
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(appThemeModeProvider),
      theme: buildAppTheme(),
      darkTheme: buildAppDarkTheme(),
      home: const MainShell(),
    );
  }
}
