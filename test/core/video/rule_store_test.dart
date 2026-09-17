import 'dart:io';

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

void main() {
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
    expect(files, hasLength(8));
    expect(
      files.map((f) => p.basename(f.path)).toList(),
      [
        '7sefun.json',
        'DM84.json',
        'MXdm.json',
        'akianime.json',
        'baimao.json',
        'gugu3.json',
        'moonci.json',
        'xfdmneo.json',
      ],
    );
    for (final file in files) {
      final rule = SourceRule.fromJsonString(await file.readAsString());
      expect(rule.name, isNotEmpty, reason: file.path);
      expect(rule.searchUrl, contains('@keyword'), reason: file.path);
    }
  });
}
