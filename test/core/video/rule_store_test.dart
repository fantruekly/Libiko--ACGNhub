import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/rule_store.dart';
import 'package:acgnhub/core/video/source_rule.dart';

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

  test('bundled 7sefun rule parses from disk', () async {
    final raw = await File('assets/source_rules/7sefun.json').readAsString();
    final rule = SourceRule.fromJsonString(raw);
    expect(rule.name, '七色番');
    expect(rule.searchUrl, contains('@keyword'));
  });
}
