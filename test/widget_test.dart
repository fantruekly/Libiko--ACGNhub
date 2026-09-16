import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/main.dart';

void main() {
  testWidgets('App launches with sidebar navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: LibikoApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('动漫'), findsWidgets);
    expect(find.text('漫画'), findsWidgets);
    expect(find.text('轻小说'), findsWidgets);
    expect(find.text('游戏'), findsWidgets);
  });
}
