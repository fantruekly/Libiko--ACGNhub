import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/storage/database.dart';
import 'shell/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init();
  runApp(const ProviderScope(child: ACGNhubApp()));
}

class ACGNhubApp extends StatelessWidget {
  static const _accent = Color(0xFF007AFF);

  const ACGNhubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACGNhub',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Microsoft YaHei',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.light,
          primary: _accent,
          surface: const Color(0xFFFFFFFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF1C1C1E),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
            height: 1.4,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _accent,
            side: const BorderSide(color: _accent, width: 1.5),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _accent),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFE8F0FE),
          labelStyle: const TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.zero,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _accent,
          linearTrackColor: Color(0xFFE5E5EA),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE5E5EA), thickness: 0.5),
      ),
      home: const MainShell(),
    );
  }
}