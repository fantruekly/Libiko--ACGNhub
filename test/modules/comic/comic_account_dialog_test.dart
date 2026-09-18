import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_source.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/core/theme/app_theme.dart';
import 'package:libiko/modules/comic/comic_account_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = ComicSource(
  name: '测试源',
  key: 'test',
  version: '1.0.0',
  hasLogin: true,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('account fields defer to the theme border', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: ComicAccountDialog(source: _source),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    for (final field in fields) {
      expect(field.decoration!.border, isNull);
    }
  });
}
