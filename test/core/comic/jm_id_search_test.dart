import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('jm.js contains the numeric id search branch', () {
    final script = File('assets/comic_source/builtin/jm.js').readAsStringSync();
    expect(script.contains('loadComicById'), isTrue,
        reason: 'numeric-id search helper is missing');
    expect(script.contains(r'/^jm\d+$/i'), isTrue,
        reason: 'jm<number> prefix detection is missing');
  });
}
