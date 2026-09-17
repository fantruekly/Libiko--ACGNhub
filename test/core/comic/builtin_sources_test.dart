import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/builtin_sources.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late Map<String, String> assets;
  late String? marker;

  BuiltinSourceInstaller build() => BuiltinSourceInstaller(
        loadAsset: (path) async {
          final value = assets[path];
          if (value == null) throw StateError('missing asset $path');
          return value;
        },
        directory: () async => dir,
        readMarker: (_) => marker,
        writeMarker: (_, value) async => marker = value,
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('builtin_sources_test');
    marker = null;
    assets = {
      'assets/comic_source/builtin/index.json': jsonEncode({
        'version': '1',
        'sources': [
          {'name': 'A', 'fileName': 'a.js', 'key': 'a', 'version': '1.0.0'},
        ],
      }),
      'assets/comic_source/builtin/a.js': 'class A extends ComicSource {}',
    };
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('installs builtin sources and records the version', () async {
    await build().install();
    final file = File(p.join(dir.path, 'a.js'));
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), 'class A extends ComicSource {}');
    expect(marker, '1');
  });

  test('skips when the version marker matches', () async {
    await build().install();
    assets['assets/comic_source/builtin/a.js'] = 'CHANGED';
    await build().install();
    expect(await File(p.join(dir.path, 'a.js')).readAsString(),
        'class A extends ComicSource {}');
  });

  test('overwrites a builtin file when the version changes', () async {
    await build().install();
    assets['assets/comic_source/builtin/index.json'] = jsonEncode({
      'version': '2',
      'sources': [
        {'name': 'A', 'fileName': 'a.js', 'key': 'a', 'version': '1.0.1'},
      ],
    });
    assets['assets/comic_source/builtin/a.js'] =
        'class A2 extends ComicSource {}';
    await build().install();
    expect(await File(p.join(dir.path, 'a.js')).readAsString(),
        'class A2 extends ComicSource {}');
    expect(marker, '2');
  });

  test('leaves unrelated files alone', () async {
    await File(p.join(dir.path, 'user.js')).writeAsString('user');
    await build().install();
    expect(await File(p.join(dir.path, 'user.js')).readAsString(), 'user');
  });
}
