import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/html_bridge.dart';

const _html = '''
<html><body>
  <div id="main" class="a b">
    <a class="item" href="/1">One</a>
    <a class="item" href="/2">Two</a>
    <span data-x="y">Text</span>
  </div>
</body></html>''';

void main() {
  late HtmlBridge bridge;
  setUp(() => bridge = HtmlBridge());
  tearDown(() => bridge.dispose());

  test('querySelector / text / attr / attributes', () {
    final doc = bridge.parse(_html);
    final main = bridge.querySelector(doc, '#main')!;
    expect(bridge.text(main), contains('One'));
    expect(bridge.attr(main, 'class'), 'a b');
    expect(bridge.attributes(main)['id'], 'main');

    final a = bridge.querySelector(doc, 'a.item')!;
    expect(bridge.text(a), 'One');
    expect(bridge.attr(a, 'href'), '/1');
    expect(bridge.attr(a, 'data-missing'), isNull);
  });

  test('querySelectorAll returns every match in order', () {
    final doc = bridge.parse(_html);
    final links = bridge.querySelectorAll(doc, 'a.item');
    expect(links, hasLength(2));
    expect(bridge.text(links[0]), 'One');
    expect(bridge.text(links[1]), 'Two');
  });

  test('getElementById and innerHtml/outerHtml', () {
    final doc = bridge.parse(_html);
    final main = bridge.getElementById(doc, 'main')!;
    expect(bridge.innerHtml(main), contains('<a'));
    expect(bridge.outerHtml(main), contains('id="main"'));
  });

  test('unknown selectors return null / empty', () {
    final doc = bridge.parse(_html);
    expect(bridge.querySelector(doc, '.nope'), isNull);
    expect(bridge.querySelectorAll(doc, '.nope'), isEmpty);
    expect(bridge.getElementById(doc, 'nope'), isNull);
  });

  test('free removes a handle and unknown handles are null', () {
    final doc = bridge.parse(_html);
    final a = bridge.querySelector(doc, 'a.item')!;
    bridge.free(a);
    expect(bridge.text(a), '');
    expect(bridge.text(999999), '');
  });

  test('the FIFO eviction drops the oldest handles beyond capacity', () {
    final handles = <int>[];
    for (var i = 0; i < 70; i++) {
      handles.add(bridge.parse('<p>$i</p>'));
    }
    // The very first document handle must have been evicted.
    expect(bridge.text(handles.first), '');
    expect(bridge.text(handles.last), '69');
  });
}
