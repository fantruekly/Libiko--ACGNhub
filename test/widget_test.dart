import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acgnhub/main.dart';

void main() {
  testWidgets('App launches with bottom navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ACGNhubApp()));
    await tester.pumpAndSettle();

    expect(find.text('动漫'), findsWidgets);
    expect(find.text('漫画'), findsWidgets);
    expect(find.text('轻小说'), findsWidgets);
    expect(find.text('游戏'), findsWidgets);
  });
}