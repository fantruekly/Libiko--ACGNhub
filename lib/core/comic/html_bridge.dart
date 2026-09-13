import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Holds parsed HTML nodes behind integer handles so a JS source can query the
/// DOM through the `sendMessage` bridge without shipping a JS HTML parser.
class HtmlBridge {
  static const _capacity = 64;

  final Map<int, dom.Node> _nodes = {};
  final List<int> _order = [];
  int _next = 1;

  int _store(dom.Node node) {
    final handle = _next++;
    _nodes[handle] = node;
    _order.add(handle);
    while (_order.length > _capacity) {
      final evicted = _order.removeAt(0);
      _nodes.remove(evicted);
    }
    return handle;
  }

  dom.Node? _get(int handle) => _nodes[handle];

  int parse(String html) => _store(html_parser.parse(html));

  int? querySelector(int handle, String selector) {
    final node = _get(handle);
    if (node == null) return null;
    final found = node is dom.Document
        ? node.querySelector(selector)
        : (node as dom.Element).querySelector(selector);
    return found == null ? null : _store(found);
  }

  List<int> querySelectorAll(int handle, String selector) {
    final node = _get(handle);
    if (node == null) return const [];
    final found = node is dom.Document
        ? node.querySelectorAll(selector)
        : (node as dom.Element).querySelectorAll(selector);
    return found.map(_store).toList();
  }

  int? getElementById(int handle, String id) {
    final node = _get(handle);
    if (node == null) return null;
    final found = node is dom.Document
        ? node.getElementById(id)
        : (node as dom.Element).querySelector('#$id');
    return found == null ? null : _store(found);
  }

  String text(int handle) {
    final node = _get(handle);
    if (node is dom.Document) return node.body?.text.trim() ?? '';
    return node?.text?.trim() ?? '';
  }

  String innerHtml(int handle) {
    final node = _get(handle);
    if (node is dom.Element) return node.innerHtml;
    if (node is dom.Document) return node.body?.innerHtml ?? '';
    return '';
  }

  String outerHtml(int handle) {
    final node = _get(handle);
    return node is dom.Element ? node.outerHtml : '';
  }

  Map<String, String> attributes(int handle) {
    final node = _get(handle);
    if (node is! dom.Element) return const {};
    return Map<String, String>.from(node.attributes
        .map((k, v) => MapEntry(k.toString(), v.toString())));
  }

  String? attr(int handle, String name) {
    final node = _get(handle);
    if (node is! dom.Element) return null;
    return node.attributes[name];
  }

  void free(int handle) {
    _nodes.remove(handle);
    _order.remove(handle);
  }

  void dispose() {
    _nodes.clear();
    _order.clear();
  }
}
