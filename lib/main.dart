import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'core/storage/database.dart';
import 'shell/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await AppDatabase.init();
  runApp(const ProviderScope(child: ACGNhubApp()));
}

class ACGNhubApp extends StatelessWidget {
  const ACGNhubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACGNhub',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false),
        sliderTheme: const SliderThemeData(year2023: false, showValueIndicator: ShowValueIndicator.onDrag),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false),
        sliderTheme: const SliderThemeData(year2023: false, showValueIndicator: ShowValueIndicator.onDrag),
      ),
      home: const MainShell(),
    );
  }
}