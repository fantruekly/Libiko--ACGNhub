import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/storage/database.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:libiko/core/video/rule_store.dart';
import 'package:libiko/core/video/source_rule.dart';

SourceRule _rule(String name) => SourceRule(
      name: name,
      baseUrl: 'https://$name.test/',
      searchUrl: 'https://$name.test/s?wd=@keyword',
      searchList: '//div',
      searchName: '//div[2]',
      searchResult: '//a',
      chapterRoads: '//div',
      chapterResult: '//a',
    );

SourceRule _ruleWith(String name, String baseUrl) => SourceRule(
      name: name,
      baseUrl: baseUrl,
      searchUrl: 'https://$name.test/s?wd=@keyword',
      searchList: '//div',
      searchName: '//div[2]',
      searchResult: '//a',
      chapterRoads: '//div',
      chapterResult: '//a',
    );

Map<String, dynamic> _json(String name, {String version = '1'}) => {
      'name': name,
      'version': version,
      'baseURL': 'https://test/$version/',
      'searchURL': 'https://test/search?wd=@keyword',
      'searchList': '//div',
      'searchName': '//a',
      'searchResult': '//a/@href',
      'chapterRoads': '//ul',
      'chapterResult': '//a',
    };

class _Bundle extends CachingAssetBundle {
  _Bundle(this.assets);
  final Map<String, String> assets;
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final name in assets.keys)
          name: [
            {'asset': name}
          ],
      })!;
    }
    final value = assets[key];
    if (value == null) throw StateError('missing asset $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late RuleStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
    dir = await Directory.systemTemp.createTemp('acgnhub_rule_test_');
    store = RuleStore(directory: dir, bundle: _Bundle({}));
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('binary AssetManifest API loads rules and preserves local update time',
      () async {
    var now = DateTime.utc(2026, 10, 18);
    final bundle = _Bundle(
        {'assets/source_rules/test.json': jsonEncode(_json('bundled'))});
    final store = RuleStore(directory: dir, bundle: bundle, clock: () => now);
    expect((await store.loadBuiltIn()).single.name, 'bundled');
    final first = await store.metadata('bundled');
    expect(first.version, '1');
    expect(first.updatedAt, now);
    now = now.add(const Duration(days: 1));
    await store.loadBuiltIn();
    expect((await store.metadata('bundled')).updatedAt, first.updatedAt);
  });

  test('imports keep previous version and rollback swaps complete valid rules',
      () async {
    await store.importJson(jsonEncode(_json('x', version: '1')));
    expect((await store.metadata('x')).hasPrevious, false);
    await store.importJson(jsonEncode(_json('x', version: '2')));
    expect((await store.metadata('x')).version, '2');
    expect((await store.metadata('x')).hasPrevious, true);
    await store.rollback('x');
    expect((await store.metadata('x')).version, '1');
    expect((await store.loadImported()).single.baseUrl, 'https://test/1/');
    await store.rollback('x');
    expect((await store.metadata('x')).version, '2');
    expect(dir.listSync().where((f) => f.path.contains('.tmp.')), isEmpty);
  });

  test('first override of a built-in rule can roll back to the shipped rule',
      () async {
    final bundle = _Bundle(
        {'assets/source_rules/test.json': jsonEncode(_json('bundled'))});
    final store = RuleStore(directory: dir, bundle: bundle);
    await store.importJson(jsonEncode(_json('bundled', version: '2')));
    expect((await store.metadata('bundled')).hasPrevious, true);
    await store.rollback('bundled');
    expect((await store.metadata('bundled')).version, '1');
  });

  test('invalid import cannot alter current rule or its rollback', () async {
    await store.importJson(jsonEncode(_json('x')));
    await store.importJson(jsonEncode(_json('x', version: '2')));
    expect(() => store.importJson('{"name":"x"}'), throwsFormatException);
    expect((await store.metadata('x')).version, '2');
    await store.rollback('x');
    expect((await store.metadata('x')).version, '1');
  });

  test(
      'concurrent same-name imports serialize and export only the current rules',
      () async {
    await Future.wait([
      for (final v in ['1', '2', '3'])
        store.importJson(jsonEncode(_json('x', version: v)))
    ]);
    expect((await store.metadata('x')).version, '3');
    expect((await store.exportImportedRules()).single['version'], '3');
    await store.rollback('x');
    expect((await store.metadata('x')).version, '2');
    await store.remove('x');
    expect(await store.loadImported(), isEmpty);
    expect(dir.listSync(), isEmpty);
  });

  test(
      'backup restore validates whole payload before merging and retains other rules',
      () async {
    await store.importJson(jsonEncode(_json('keep')));
    expect(
        () => store.restoreImports([
              _json('new'),
              {'name': 'bad'}
            ]),
        throwsFormatException);
    expect((await store.loadImported()).map((r) => r.name), ['keep']);
    await store.restoreImports([_json('new')]);
    expect((await store.loadImported()).map((r) => r.name),
        unorderedEquals(['keep', 'new']));
  });

  test(
      'names that collide when sanitized remain separate and cannot escape rule directory',
      () async {
    await store.importJson(jsonEncode(_json('../a/b')));
    await store.importJson(jsonEncode(_json('..\\a\\b')));
    expect(await store.loadImported(), hasLength(2));
    expect(dir.listSync().every((f) => p.dirname(f.path) == dir.path), true);
  });

  test('mergeRules dedupes by name and imported wins', () {
    final merged = RuleStore.mergeRules(
      [_rule('a'), _rule('b')],
      [_ruleWith('b', 'https://b-imported.test/'), _rule('c')],
    );
    expect(merged.map((r) => r.name).toSet(), {'a', 'b', 'c'});
    expect(
      merged.firstWhere((r) => r.name == 'b').baseUrl,
      'https://b-imported.test/',
    );
  });

  test('every bundled rule parses from disk', () async {
    final dir = Directory('assets/source_rules');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(5));
    expect(
      files.map((f) => p.basename(f.path)).toList(),
      [
        '7sefun.json',
        'moonci.json',
        'sorani.json',
        'xfdmneo.json',
        'xfdmnext.json',
      ],
    );
    for (final file in files) {
      final rule = SourceRule.fromJsonString(await file.readAsString());
      expect(rule.name, isNotEmpty, reason: file.path);
      if (rule.searchMode == 'api') {
        expect(rule.searchApiConfig, isNotNull, reason: file.path);
      } else {
        expect(rule.searchUrl, contains('@keyword'), reason: file.path);
      }
    }
  });
}
