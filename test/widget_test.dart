import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('NavigationBar has 4 destinations', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.live_tv), label: '动漫'),
            NavigationDestination(icon: Icon(Icons.menu_book), label: '漫画'),
            NavigationDestination(icon: Icon(Icons.auto_stories), label: '轻小说'),
            NavigationDestination(icon: Icon(Icons.games), label: '游戏'),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('动漫'), findsOneWidget);
    expect(find.text('漫画'), findsOneWidget);
    expect(find.text('轻小说'), findsOneWidget);
    expect(find.text('游戏'), findsOneWidget);
  });
}