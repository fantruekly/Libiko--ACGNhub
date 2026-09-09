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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      home: const MainShell(),
    );
  }
}