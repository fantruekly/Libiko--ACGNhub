import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/ui/app_messenger.dart';

void main() {
  testWidgets('showAppMessage surfaces a SnackBar on the global messenger',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: appMessengerKey,
      home: const Scaffold(body: SizedBox()),
    ));
    showAppMessage('hello from a source');
    await tester.pump();
    expect(find.text('hello from a source'), findsOneWidget);
  });
}
