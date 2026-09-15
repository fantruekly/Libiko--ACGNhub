import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/shell/main_shell.dart';

void main() {
  testWidgets('switching modules cross-fades while keeping every page mounted',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: MainShell()),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    List<double> pageOpacity() => [
          for (var i = 0; i < 4; i++)
            tester
                .widget<AnimatedOpacity>(find.byKey(ValueKey('module-page-$i')))
                .opacity,
        ];

    expect(pageOpacity(), [1.0, 0.0, 0.0, 0.0]);

    await tester.tap(find.text('漫画'));
    await tester.pump();
    expect(pageOpacity(), [0.0, 1.0, 0.0, 0.0]);
  });
}
