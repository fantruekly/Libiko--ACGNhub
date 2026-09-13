# Comic JS Source Engine Implementation Plan (C1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Load, manage and execute Venera-style `.js` comic sources, exposing search / explore / detail / chapter-images to Dart.

**Architecture:** A `JsEngine` (QuickJS via `flutter_qjs`) injects a global `sendMessage` and dispatches `http` / `convert` / `html` / `setting` / `log`. A bundled `assets/comic_source/init.js` re-implements Venera's JS API shape on top of it. `ComicSourceManager` scans/imports/updates sources and maps their JS results into Dart models.

**Tech Stack:** Flutter 3.35, Dart 3, `flutter_qjs` (QuickJS), `dio`, `html`, `crypto`, `fast_gbk`.

## Global Constraints

- **Task 1 is a go/no-go spike.** If `flutter_qjs` cannot build for Windows, or JS cannot be evaluated, STOP and report — do not invent a workaround.
- `sendMessage` is the single Dart↔JS bridge entry point; every bridge call goes through it.
- The JS API library is **re-implemented to match Venera's API shape** — never copy Venera's GPL `init.js`.
- `http` uses its own `Dio` with 15 s timeouts and `validateStatus: (_) => true`, injecting a default browser UA when the JS did not set one.
- HTML DOM lives in Dart behind integer handles with an LRU of capacity 64; the JS side only holds handles.
- A source that fails to parse/evaluate is skipped with a `debugPrint` — never crash the manager.
- Comic code lives in `lib/core/comic/`; assets in `assets/comic_source/`.
- Commit after every task. Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed.

---

### Task 1: Spike — `flutter_qjs` on Windows

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/comic/js_engine.dart`
- Test: `test/core/comic/js_engine_smoke_test.dart`

**Interfaces:**
- Produces: `class JsEngine { JsEngine(); Future<dynamic> evaluate(String code); void dispose(); }` (Task 3 extends it).

- [ ] **Step 1: Add the dependencies**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter pub add flutter_qjs crypto fast_gbk`
Expected: `Got dependencies!` (if `flutter_qjs` or `fast_gbk` cannot resolve, STOP and report — this is the spike's answer).

- [ ] **Step 2: Write the smoke test**

Create `test/core/comic/js_engine_smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/js_engine.dart';

void main() {
  test('evaluates a trivial script', () async {
    final engine = JsEngine();
    addTearDown(engine.dispose);
    expect(await engine.evaluate('1 + 1'), 2);
    expect(await engine.evaluate('"a" + "b"'), 'ab');
  });
}
```

- [ ] **Step 3: Run the smoke test**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/js_engine_smoke_test.dart`
Expected: PASS. **If the QuickJS native library is unavailable under `flutter test`**, record that fact and use the app-level probe below instead — do not fake it.

Fallback probe (only if the test cannot load the native lib): create `.superpowers/sdd/js_probe.dart` that runs the same two assertions and prints the results, then run `flutter run -d windows -t .superpowers/sdd/js_probe.dart` and record the output.

- [ ] **Step 4: Create a minimal `lib/core/comic/js_engine.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

class JsEngine {
  JsEngine() {
    _engine.dispatch();
  }

  final FlutterQjs _engine = FlutterQjs(stackSize: 1024 * 1024);

  Future<dynamic> evaluate(String code) => _engine.evaluate(code);

  void dispose() {
    try {
      _engine.port.close();
      _engine.close();
    } catch (e) {
      debugPrint('[JsEngine] dispose: $e');
    }
  }
}
```

- [ ] **Step 5: Verify the Windows build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → `Built build\windows\x64\runner\Debug\acgnhub.exe`
**This is the spike's verdict.** If the build fails, STOP and report the exact error so the human can choose a fallback engine.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/comic/js_engine.dart test/core/comic/js_engine_smoke_test.dart
git commit -m "feat(comic): add flutter_qjs and a minimal JS engine (spike)"
```

---

### Task 2: HTML DOM bridge

**Files:**
- Create: `lib/core/comic/html_bridge.dart`
- Test: `test/core/comic/html_bridge_test.dart`

**Interfaces:**
- Produces: `class HtmlBridge` with `int parse(String html)`, `int? querySelector(int handle, String selector)`, `List<int> querySelectorAll(int handle, String selector)`, `int? getElementById(int handle, String id)`, `String text(int handle)`, `String innerHtml(int handle)`, `String outerHtml(int handle)`, `Map<String, String> attributes(int handle)`, `String? attr(int handle, String name)`, `void free(int handle)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/comic/html_bridge_test.dart`:

```dart
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

  test('the LRU evicts the oldest handles beyond capacity', () {
    final doc = bridge.parse(_html);
    final handles = <int>[];
    for (var i = 0; i < 70; i++) {
      handles.add(bridge.parse('<p>$i</p>'));
    }
    // The very first document handle must have been evicted.
    expect(bridge.text(handles.first), '');
    expect(bridge.text(handles.last), '69');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/html_bridge_test.dart`
Expected: FAIL — `html_bridge.dart` not found.

- [ ] **Step 3: Create `lib/core/comic/html_bridge.dart`**

```dart
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

  String text(int handle) => _get(handle)?.text.trim() ?? '';

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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/html_bridge_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/comic/html_bridge.dart test/core/comic/html_bridge_test.dart
git commit -m "feat(comic): add the HTML DOM bridge"
```

---

### Task 3: `JsEngine` bridge — `http` / `convert` / `setting` / `log`

**Files:**
- Modify: `lib/core/comic/js_engine.dart`
- Test: `test/core/comic/js_engine_bridge_test.dart`

**Interfaces:**
- Consumes: `HtmlBridge` (Task 2).
- Produces: `JsEngine({Dio? dio, Map<String, String> Function()? settings})` with `Future<dynamic> evaluate(String)`, `void installBridge()`, `void dispose()`; the JS global `sendMessage({method, ...})` handling `http`/`convert`/`html`/`setting`/`log`.

- [ ] **Step 1: Write the failing test**

Create `test/core/comic/js_engine_bridge_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/js_engine.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode, this.body);
  final int statusCode;
  final String body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(body, statusCode, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

JsEngine _engine(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  dio.httpClientAdapter = adapter;
  return JsEngine(dio: dio)..installBridge();
}

void main() {
  test('http returns status/headers/body and sends the URL and headers', () async {
    final adapter = _FakeAdapter(200, '{"ok":true}');
    final engine = _engine(adapter);
    addTearDown(engine.dispose);

    final result = await engine.evaluate('''
      (async () => {
        const r = await sendMessage({method:'http', method2:'GET',
          url:'https://example.test/a', headers:{'X-A':'1'}, data:null, bytes:false});
        return r.status + '|' + r.body;
      })()
    ''');

    expect(result, '200|{"ok":true}');
    expect(adapter.last!.uri.toString(), 'https://example.test/a');
    expect(adapter.last!.headers['X-A'], '1');
    expect(adapter.last!.headers['user-agent'], isNotNull);
  });

  test('convert base64/md5/sha256/hex', () async {
    final engine = _engine(_FakeAdapter(200, '{}'));
    addTearDown(engine.dispose);

    expect(
        await engine.evaluate(
            "sendMessage({method:'convert', type:'base64Encode', data:'hi'})"),
        'aGk=');
    expect(
        await engine.evaluate(
            "sendMessage({method:'convert', type:'hexEncode', data:'AB'})"),
        '4142');
    expect(
        await engine.evaluate(
            "sendMessage({method:'convert', type:'md5', data:'abc'})"),
        '900150983cd24fb0d6963f7d28e17f72');
    expect(
        await engine.evaluate(
            "sendMessage({method:'convert', type:'sha256', data:'abc'})"),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  test('html ops go through sendMessage', () async {
    final engine = _engine(_FakeAdapter(200, '{}'));
    addTearDown(engine.dispose);

    final result = await engine.evaluate('''
      (() => {
        const doc = sendMessage({method:'html', op:'parse', html:'<div id="x"><a href="/1">Hi</a></div>'});
        const a = sendMessage({method:'html', op:'querySelector', handle:doc, selector:'a'});
        return sendMessage({method:'html', op:'text', handle:a}) + '|' +
               sendMessage({method:'html', op:'attr', handle:a, name:'href'});
      })()
    ''');

    expect(result, 'Hi|/1');
  });

  test('setting get/set round-trips through the injected store', () async {
    final store = <String, String>{};
    final engine = JsEngine(
      dio: Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = _FakeAdapter(200, '{}'),
      settings: () => store,
    )..installBridge();
    addTearDown(engine.dispose);

    await engine.evaluate("sendMessage({method:'setting', op:'set', key:'k', value:'v'})");
    expect(store['k'], 'v');
    expect(
        await engine.evaluate("sendMessage({method:'setting', op:'get', key:'k'})"),
        'v');
  });

  test('an unknown method throws a JS error', () async {
    final engine = _engine(_FakeAdapter(200, '{}'));
    addTearDown(engine.dispose);
    await expectLater(
      engine.evaluate("sendMessage({method:'nope'})"),
      throwsA(anything),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/js_engine_bridge_test.dart`
Expected: FAIL — `JsEngine({Dio?, settings})` / `installBridge` undefined.

- [ ] **Step 3: Extend `lib/core/comic/js_engine.dart`**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:fast_gbk/fast_gbk.dart';

import 'html_bridge.dart';

const _defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

class JsEngine {
  JsEngine({Dio? dio, Map<String, String> Function()? settings})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (_) => true,
            )),
        _settings = settings ?? (() => <String, String>{});

  final FlutterQjs _engine = FlutterQjs(stackSize: 1024 * 1024);
  final Dio _dio;
  final Map<String, String> Function() _settings;
  final HtmlBridge _html = HtmlBridge();
  JSInvokable? _sendMessage;

  void installBridge() {
    _engine.dispatch();
    final install = _engine.evaluate(
        "(fn) => { globalThis.sendMessage = fn; return true; }");
    // evaluate returns a Future; the bridge is installed asynchronously.
    install.then((setter) async {
      final invokable = JSInvokable(_handle);
      _sendMessage = invokable;
      await (setter as JSInvokable).invoke([invokable]);
      (setter as JSRef).free();
    });
  }

  Future<dynamic> evaluate(String code) => _engine.evaluate(code);

  dynamic _handle(List<dynamic> args, dynamic thisVal) {
    final map = (args.first as Map).cast<dynamic, dynamic>();
    switch (map['method']) {
      case 'http':
        return _http(map);
      case 'convert':
        return _convert(map);
      case 'html':
        return _htmlOp(map);
      case 'setting':
        return _setting(map);
      case 'log':
        debugPrint('[comic-source] ${map['message']}');
        return null;
      default:
        throw Exception('Unknown bridge method: ${map['method']}');
    }
  }

  Future<Map<String, dynamic>> _http(Map<dynamic, dynamic> map) async {
    final headers = <String, dynamic>{
      for (final e in (map['headers'] as Map? ?? {}).entries)
        e.key.toString(): e.value
    };
    headers.putIfAbsent('user-agent', () => _defaultUserAgent);
    final bytes = map['bytes'] == true;
    try {
      final response = await _dio.request(
        map['url'] as String,
        data: map['data'],
        options: Options(
          method: (map['method2'] ?? 'GET').toString(),
          headers: headers,
          responseType: bytes ? ResponseType.bytes : ResponseType.plain,
          extra: (map['extra'] as Map?)?.cast<String, dynamic>(),
        ),
      );
      return {
        'status': response.statusCode ?? 0,
        'headers': {
          for (final e in response.headers.map.entries)
            e.key: e.value.join(','),
        },
        'body': bytes ? response.data as Uint8List : response.data.toString(),
      };
    } on DioException catch (e) {
      return {'status': 0, 'headers': const {}, 'body': '', 'error': '$e'};
    }
  }

  dynamic _convert(Map<dynamic, dynamic> map) {
    final type = map['type'] as String;
    final data = map['data']?.toString() ?? '';
    final dataBytes = utf8.encode(data);
    switch (type) {
      case 'utf8':
        return utf8.decode(map['data'] as List<int>, allowMalformed: true);
      case 'utf8Encode':
        return utf8.encode(data);
      case 'gbk':
        return gbk.decode(map['data'] as List<int>);
      case 'base64Encode':
        return base64.encode(dataBytes);
      case 'base64Decode':
        return base64.decode(data);
      case 'hexEncode':
        return dataBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      case 'hexDecode':
        return [
          for (var i = 0; i + 1 < data.length; i += 2)
            int.parse(data.substring(i, i + 2), radix: 16)
        ];
      case 'md5':
        return md5.convert(dataBytes).toString();
      case 'sha1':
        return sha1.convert(dataBytes).toString();
      case 'sha256':
        return sha256.convert(dataBytes).toString();
      case 'hmac':
        return Hmac(sha256, utf8.encode(map['key']?.toString() ?? ''))
            .convert(dataBytes)
            .toString();
      default:
        throw Exception('Unknown convert type: $type');
    }
  }

  dynamic _htmlOp(Map<dynamic, dynamic> map) {
    final op = map['op'] as String;
    final handle = (map['handle'] as num?)?.toInt() ?? 0;
    switch (op) {
      case 'parse':
        return _html.parse(map['html'] as String? ?? '');
      case 'querySelector':
        return _html.querySelector(handle, map['selector'] as String);
      case 'querySelectorAll':
        return _html.querySelectorAll(handle, map['selector'] as String);
      case 'getElementById':
        return _html.getElementById(handle, map['id'] as String);
      case 'text':
        return _html.text(handle);
      case 'innerHtml':
        return _html.innerHtml(handle);
      case 'outerHtml':
        return _html.outerHtml(handle);
      case 'attributes':
        return _html.attributes(handle);
      case 'attr':
        return _html.attr(handle, map['name'] as String);
      case 'free':
        _html.free(handle);
        return null;
      default:
        throw Exception('Unknown html op: $op');
    }
  }

  dynamic _setting(Map<dynamic, dynamic> map) {
    final store = _settings();
    final key = map['key'] as String;
    if (map['op'] == 'set') {
      store[key] = map['value']?.toString() ?? '';
      return null;
    }
    return store[key];
  }

  void dispose() {
    _html.dispose();
    try {
      _sendMessage?.free();
      _engine.port.close();
      _engine.close();
    } catch (e) {
      debugPrint('[JsEngine] dispose: $e');
    }
  }
}
```

Notes for the implementer:
- `JSInvokable` / `JSRef` come from `flutter_qjs`; the exact way to install a global Dart function is documented in that package's README ("Use Dart Function" / "pass a function to JSInvokable arguments"). If the API differs in the resolved version, adapt `installBridge` and the `_sendMessage` handling to the package's actual API and say so in the report — the requirement is only that JS can call `sendMessage({...})` and get the dispatched result back.
- **AES (`aesEcb`/`aesCbc`) is deferred out of C1.** The spec's `Convert` list includes it but this plan does not implement it, so do NOT add `encrypt`/`pointycastle`; if a source needs AES it will fail loudly and that is the documented scope limit.

- [ ] **Step 4: Verify**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/js_engine_bridge_test.dart` → PASS (5 tests)
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/comic/js_engine.dart test/core/comic/js_engine_bridge_test.dart
git commit -m "feat(comic): add the JS engine bridge (http/convert/html/setting/log)"
```

---

### Task 4: JS API library + Dart models

**Files:**
- Create: `assets/comic_source/init.js`
- Create: `lib/core/comic/models.dart`
- Modify: `pubspec.yaml` (declare `assets/comic_source/`)
- Test: `test/core/comic/models_test.dart`

**Interfaces:**
- Produces: `class Comic {id,title,subtitle,cover,tags,description}` with `fromJs(Map)`; `class ComicDetails {id,title,subtitle,cover,tags,description,chapters,recommendIds}` with `fromJs(Map)`; `class ComicEp {images}` with `fromJs(Map)`; `class ImageLoadingConfig {url,method,data,headers}` with `fromJs(Map)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/comic/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/models.dart';

void main() {
  test('Comic.fromJs maps the source result', () {
    final comic = Comic.fromJs({
      'id': '1',
      'title': 'T',
      'subtitle': 'S',
      'cover': 'c.jpg',
      'tags': ['a', 'b'],
      'description': 'D',
    });
    expect(comic.id, '1');
    expect(comic.title, 'T');
    expect(comic.subtitle, 'S');
    expect(comic.cover, 'c.jpg');
    expect(comic.tags, ['a', 'b']);
    expect(comic.description, 'D');
  });

  test('Comic.fromJs tolerates missing optional fields', () {
    final comic = Comic.fromJs({'id': '1', 'title': 'T'});
    expect(comic.subtitle, isNull);
    expect(comic.tags, isEmpty);
    expect(comic.cover, isNull);
  });

  test('ComicDetails.fromJs maps chapters and recommend', () {
    final details = ComicDetails.fromJs({
      'id': '1',
      'title': 'T',
      'chapters': {'c1': '第1话', 'c2': '第2话'},
      'recommend': ['x', 'y'],
    });
    expect(details.chapters, {'c1': '第1话', 'c2': '第2话'});
    expect(details.recommendIds, ['x', 'y']);
  });

  test('ComicEp.fromJs maps the image list', () {
    final ep = ComicEp.fromJs({'images': ['u1', 'u2']});
    expect(ep.images, ['u1', 'u2']);
  });

  test('ImageLoadingConfig.fromJs maps headers', () {
    final config = ImageLoadingConfig.fromJs({
      'url': 'u',
      'headers': {'referer': 'r'},
      'method': 'GET',
    });
    expect(config.url, 'u');
    expect(config.headers, {'referer': 'r'});
    expect(config.method, 'GET');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/models_test.dart`
Expected: FAIL — `models.dart` not found.

- [ ] **Step 3: Create `lib/core/comic/models.dart`**

```dart
class Comic {
  final String id;
  final String title;
  final String? subtitle;
  final String? cover;
  final List<String> tags;
  final String? description;

  const Comic({
    required this.id,
    required this.title,
    this.subtitle,
    this.cover,
    this.tags = const [],
    this.description,
  });

  factory Comic.fromJs(Map<dynamic, dynamic> json) => Comic(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString(),
        cover: json['cover']?.toString(),
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        description: json['description']?.toString(),
      );
}

class ComicDetails {
  final String id;
  final String title;
  final String? subtitle;
  final String? cover;
  final List<String> tags;
  final String? description;
  final Map<String, String> chapters;
  final List<String> recommendIds;

  const ComicDetails({
    required this.id,
    required this.title,
    this.subtitle,
    this.cover,
    this.tags = const [],
    this.description,
    this.chapters = const {},
    this.recommendIds = const [],
  });

  factory ComicDetails.fromJs(Map<dynamic, dynamic> json) => ComicDetails(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString(),
        cover: json['cover']?.toString(),
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        description: json['description']?.toString(),
        chapters: (json['chapters'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            const {},
        recommendIds:
            (json['recommend'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
      );
}

class ComicEp {
  final List<String> images;
  const ComicEp({required this.images});

  factory ComicEp.fromJs(Map<dynamic, dynamic> json) => ComicEp(
        images:
            (json['images'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
      );
}

class ImageLoadingConfig {
  final String? url;
  final String? method;
  final dynamic data;
  final Map<String, String>? headers;

  const ImageLoadingConfig({this.url, this.method, this.data, this.headers});

  factory ImageLoadingConfig.fromJs(Map<dynamic, dynamic> json) =>
      ImageLoadingConfig(
        url: json['url']?.toString(),
        method: json['method']?.toString(),
        data: json['data'],
        headers: (json['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      );
}
```

- [ ] **Step 4: Create `assets/comic_source/init.js`**

A re-implementation of Venera's API shape (do not copy Venera's file). It must define `ComicSource`, `Comic`, `ComicDetails`, `Network`, `Convert`, `HtmlDocument`/`HtmlNode`, and install them on `globalThis`:

```javascript
// ACGNhub comic-source JS API. Re-implements the Venera API shape on top of the
// Dart `sendMessage` bridge.
(function () {
  const call = (obj) => sendMessage(obj);

  class Comic {
    constructor({ id, title, subtitle, cover, tags, description } = {}) {
      this.id = id || ''; this.title = title || '';
      this.subtitle = subtitle; this.cover = cover;
      this.tags = tags || []; this.description = description;
    }
  }

  class ComicDetails {
    constructor(o = {}) {
      this.id = o.id || ''; this.title = o.title || '';
      this.subtitle = o.subtitle; this.cover = o.cover;
      this.tags = o.tags || []; this.description = o.description;
      this.chapters = o.chapters || {}; this.thumbnails = o.thumbnails || [];
      this.recommend = o.recommend || []; this.stars = o.stars;
    }
  }

  class Network {
    static sendRequest(method, url, headers, data, extra, bytes) {
      const r = call({ method: 'http', method2: method, url: url,
        headers: headers || {}, data: data, extra: extra, bytes: !!bytes });
      if (r.error) throw new Error(r.error);
      return r;
    }
    static get(url, headers) { return Network.sendRequest('GET', url, headers); }
    static post(url, data, headers) {
      return Network.sendRequest('POST', url, headers, data);
    }
    static fetchBytes(method, url, headers, data) {
      return Network.sendRequest(method, url, headers, data, null, true).body;
    }
  }

  class Convert {
    static utf8(bytes) { return call({ method: 'convert', type: 'utf8', data: bytes }); }
    static utf8Encode(s) { return call({ method: 'convert', type: 'utf8Encode', data: s }); }
    static gbk(bytes) { return call({ method: 'convert', type: 'gbk', data: bytes }); }
    static base64Encode(s) { return call({ method: 'convert', type: 'base64Encode', data: s }); }
    static base64Decode(s) { return call({ method: 'convert', type: 'base64Decode', data: s }); }
    static hexEncode(s) { return call({ method: 'convert', type: 'hexEncode', data: s }); }
    static hexDecode(s) { return call({ method: 'convert', type: 'hexDecode', data: s }); }
    static md5(s) { return call({ method: 'convert', type: 'md5', data: s }); }
    static sha1(s) { return call({ method: 'convert', type: 'sha1', data: s }); }
    static sha256(s) { return call({ method: 'convert', type: 'sha256', data: s }); }
    static hmac(data, key) { return call({ method: 'convert', type: 'hmac', data: data, key: key }); }
  }

  function wrap(handle) {
    return handle === null || handle === undefined ? null : new HtmlNode(handle);
  }

  class HtmlNode {
    constructor(handle) { this._h = handle; }
    querySelector(sel) { return wrap(call({ method: 'html', op: 'querySelector', handle: this._h, selector: sel })); }
    querySelectorAll(sel) { return (call({ method: 'html', op: 'querySelectorAll', handle: this._h, selector: sel }) || []).map(wrap); }
    getElementById(id) { return wrap(call({ method: 'html', op: 'getElementById', handle: this._h, id: id })); }
    get text() { return call({ method: 'html', op: 'text', handle: this._h }); }
    get innerHtml() { return call({ method: 'html', op: 'innerHtml', handle: this._h }); }
    get outerHtml() { return call({ method: 'html', op: 'outerHtml', handle: this._h }); }
    get attributes() { return call({ method: 'html', op: 'attributes', handle: this._h }); }
    attr(name) { return call({ method: 'html', op: 'attr', handle: this._h, name: name }); }
  }

  class HtmlDocument extends HtmlNode {
    constructor(html) { super(call({ method: 'html', op: 'parse', html: html })); }
  }

  class ComicSource {
    constructor() {
      this.name = ''; this.key = ''; this.version = ''; this.url = '';
    }
    loadSetting(key) { return call({ method: 'setting', op: 'get', key: this.key + '.' + key }); }
    saveSetting(key, value) { return call({ method: 'setting', op: 'set', key: this.key + '.' + key, value: value }); }
  }

  globalThis.ComicSource = ComicSource;
  globalThis.Comic = Comic;
  globalThis.ComicDetails = ComicDetails;
  globalThis.Network = Network;
  globalThis.Convert = Convert;
  globalThis.HtmlDocument = HtmlDocument;
  globalThis.HtmlNode = HtmlNode;
  globalThis.comicSourceBridgeReady = true;
})();
```

- [ ] **Step 5: Declare the asset and run the tests**

In `pubspec.yaml`, add `- assets/comic_source/` under `flutter: assets:`.

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter pub get`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/models_test.dart` → PASS (5 tests)
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add assets/comic_source/init.js lib/core/comic/models.dart pubspec.yaml test/core/comic/models_test.dart
git commit -m "feat(comic): add the JS API library and Dart models"
```

---

### Task 5: `ComicSource` + `ComicSourceManager`

**Files:**
- Create: `lib/core/comic/comic_source.dart`
- Test: `test/core/comic/comic_source_test.dart`

**Interfaces:**
- Consumes: `JsEngine` (Task 3), `models.dart` (Task 4).
- Produces: `class ComicSource {name,key,version,url,fileName,description,canSearch,canExplore,canLoadInfo,canLoadEp,canOnImageLoad}`; `class ComicSourceManager { Future<void> load(); List<ComicSource> get sources; Future<ComicSource> importFromUrl(String url); Future<ComicSource> importFromFile(String path); Future<ComicSource> refresh(ComicSource); Future<void> remove(ComicSource); Future<List<Comic>> search(ComicSource, String keyword, {int page}); Future<List<Comic>> explore(ComicSource, int index, {int page}); Future<ComicDetails> loadInfo(ComicSource, String id); Future<ComicEp> loadEp(ComicSource, String comicId, String epId); Future<ImageLoadingConfig> onImageLoad(ComicSource, String url, String comicId, String epId); }`.

- [ ] **Step 1: Write the failing test**

Create `test/core/comic/comic_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/comic_source.dart';

const _validSource = '''
class TestSource extends ComicSource {
  name = "测试源";
  key = "test_source";
  version = "1.0.0";
  search = { load: (keyword, options, page) => ({ comics: [], maxPage: 1 }) };
  comic = { loadInfo: (id) => new ComicDetails({ id: id, title: "T" }) };
}
''';

void main() {
  test('parses name/key/version and capability flags', () {
    final source = ComicSource.parseForTest(_validSource);
    expect(source.name, '测试源');
    expect(source.key, 'test_source');
    expect(source.version, '1.0.0');
    expect(source.canSearch, isTrue);
    expect(source.canLoadInfo, isTrue);
    expect(source.canExplore, isFalse);
    expect(source.canLoadEp, isFalse);
  });

  test('a malformed source throws a FormatException', () {
    expect(() => ComicSource.parseForTest('var x = 1;'),
        throwsA(isA<FormatException>()));
  });

  test('a missing required field throws a FormatException', () {
    expect(
        () => ComicSource.parseForTest(
            'class S extends ComicSource { name = "x"; }'),
        throwsA(isA<FormatException>()));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_source_test.dart`
Expected: FAIL — `comic_source.dart` not found.

- [ ] **Step 3: Create `lib/core/comic/comic_source.dart`**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'js_engine.dart';
import 'models.dart';

class ComicSource {
  final String name;
  final String key;
  final String version;
  final String url;
  final String fileName;
  final String? description;
  final bool canSearch;
  final bool canExplore;
  final bool canLoadInfo;
  final bool canLoadEp;
  final bool canOnImageLoad;

  const ComicSource({
    required this.name,
    required this.key,
    required this.version,
    this.url = '',
    this.fileName = '',
    this.description,
    this.canSearch = false,
    this.canExplore = false,
    this.canLoadInfo = false,
    this.canLoadEp = false,
    this.canOnImageLoad = false,
  });

  static final _classRe = RegExp(r'class\s+\w+\s+extends\s+ComicSource');

  /// Parses source metadata from the script text. `flags` come from evaluating
  /// the script; the pure part (name/key/version) is testable on its own.
  static ComicSource fromMetadata(
    Map<dynamic, dynamic> meta, {
    String fileName = '',
    String url = '',
  }) {
    String req(String k) {
      final v = meta[k]?.toString();
      if (v == null || v.trim().isEmpty) {
        throw FormatException('comic source is missing "$k"');
      }
      return v.trim();
    }

    return ComicSource(
      name: req('name'),
      key: req('key'),
      version: req('version'),
      url: meta['url']?.toString() ?? url,
      fileName: fileName,
      description: meta['description']?.toString(),
      canSearch: meta['search'] == true,
      canExplore: meta['explore'] == true,
      canLoadInfo: meta['loadInfo'] == true,
      canLoadEp: meta['loadEp'] == true,
      canOnImageLoad: meta['onImageLoad'] == true,
    );
  }

  /// Pure text check used by the parser tests and before evaluation.
  static void assertLooksLikeSource(String script) {
    if (!_classRe.hasMatch(script)) {
      throw const FormatException('not a ComicSource script');
    }
  }

  @visibleForTesting
  static ComicSource parseForTest(String script) {
    assertLooksLikeSource(script);
    // Minimal metadata extraction without a JS engine (test-only): pull the
    // string fields and the capability keys with regexes.
    String? str(String field) =>
        RegExp('$field\\s*=\\s*"([^"]*)"').firstMatch(script)?.group(1);
    final name = str('name');
    final key = str('key');
    final version = str('version');
    if (name == null || key == null || version == null) {
      throw const FormatException('missing name/key/version');
    }
    return ComicSource(
      name: name,
      key: key,
      version: version,
      url: str('url') ?? '',
      canSearch: RegExp(r'search\s*=\s*\{').hasMatch(script),
      canExplore: RegExp(r'explore\s*=\s*\[').hasMatch(script),
      canLoadInfo: RegExp(r'loadInfo\s*:').hasMatch(script),
      canLoadEp: RegExp(r'loadEp\s*:').hasMatch(script),
      canOnImageLoad: RegExp(r'onImageLoad\s*:').hasMatch(script),
    );
  }
}

class ComicSourceManager {
  ComicSourceManager({JsEngine? engine, Dio? dio})
      : _engine = engine ?? JsEngine(),
        _dio = dio ?? Dio();

  final JsEngine _engine;
  final Dio _dio;
  final List<ComicSource> _sources = [];
  final Map<String, String> _sourceDirs = {};

  List<ComicSource> get sources => List.unmodifiable(_sources);

  Future<Directory> _dir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'comic_source'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> load() async {
    _sources.clear();
    final lib = await rootBundle.loadString('assets/comic_source/init.js');
    await _engine.evaluate(lib);
    final dir = await _dir();
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.js')) continue;
      try {
        final source = await _evaluateSource(
            await entity.readAsString(), p.basename(entity.path));
        _sources.add(source);
      } catch (e) {
        debugPrint('[ComicSourceManager] skipped ${entity.path}: $e');
      }
    }
  }

  Future<ComicSource> _evaluateSource(String script, String fileName) async {
    ComicSource.assertLooksLikeSource(script);
    await _engine.evaluate(script);
    final meta = await _engine.evaluate('''
      (() => {
        const cls = Object.values(globalThis).find(
          (v) => typeof v === 'function' && v.prototype instanceof ComicSource);
        if (!cls) return null;
        const s = new cls();
        return { name: s.name, key: s.key, version: s.version, url: s.url,
                 search: !!s.search, explore: !!s.explore,
                 loadInfo: !!(s.comic && s.comic.loadInfo),
                 loadEp: !!(s.comic && s.comic.loadEp),
                 onImageLoad: !!(s.comic && s.comic.onImageLoad) };
      })()
    ''');
    if (meta is! Map) throw const FormatException('source metadata missing');
    return ComicSource.fromMetadata(meta, fileName: fileName);
  }

  Future<ComicSource> importFromUrl(String url) async {
    final response = await _dio.get<String>(url,
        options: Options(responseType: ResponseType.plain));
    final script = response.data ?? '';
    final name = Uri.parse(url).pathSegments.last;
    ComicSource.assertLooksLikeSource(script);
    final dir = await _dir();
    final file = File(p.join(dir.path, name));
    await file.writeAsString(script);
    final source = await _evaluateSource(script, name);
    _sources.add(source);
    return source;
  }

  Future<ComicSource> importFromFile(String path) async {
    final script = await File(path).readAsString();
    final dir = await _dir();
    final name = p.basename(path);
    await File(p.join(dir.path, name)).writeAsString(script);
    final source = await _evaluateSource(script, name);
    _sources.add(source);
    return source;
  }

  Future<void> remove(ComicSource source) async {
    final dir = await _dir();
    final file = File(p.join(dir.path, source.fileName));
    if (await file.exists()) await file.delete();
    _sources.removeWhere((s) => s.key == source.key);
  }

  Future<List<Comic>> search(ComicSource source, String keyword,
      {int page = 1}) async {
    if (!source.canSearch) return const [];
    final result = await _engine.evaluate('''
      (() => {
        const cls = Object.values(globalThis).find(
          (v) => typeof v === 'function' && v.prototype instanceof ComicSource);
        const s = new cls();
        return s.search.load(${jsonEncode(keyword)}, {}, $page);
      })()
    ''');
    return _comicsFrom(result);
  }

  Future<List<Comic>> explore(ComicSource source, int index,
      {int page = 1}) async {
    if (!source.canExplore) return const [];
    final result = await _engine.evaluate('''
      (() => {
        const cls = Object.values(globalThis).find(
          (v) => typeof v === 'function' && v.prototype instanceof ComicSource);
        const s = new cls();
        return s.explore[$index].load($page);
      })()
    ''');
    return _comicsFrom(result);
  }

  Future<ComicDetails> loadInfo(ComicSource source, String id) async {
    final result = await _engine.evaluate('''
      (() => {
        const cls = Object.values(globalThis).find(
          (v) => typeof v === 'function' && v.prototype instanceof ComicSource);
        const s = new cls();
        return s.comic.loadInfo(${jsonEncode(id)});
      })()
    ''');
    if (result is! Map) {
      throw StateError('loadInfo returned ${result.runtimeType}');
    }
    return ComicDetails.fromJs(result);
  }

  Future<ComicEp> loadEp(
      ComicSource source, String comicId, String epId) async {
    final result = await _engine.evaluate('''
      (() => {
        const cls = Object.values(globalThis).find(
          (v) => typeof v === 'function' && v.prototype instanceof ComicSource);
        const s = new cls();
        return s.comic.loadEp(${jsonEncode(comicId)}, ${jsonEncode(epId)});
      })()
    ''');
    if (result is! Map) throw StateError('loadEp returned ${result.runtimeType}');
    return ComicEp.fromJs(result);
  }

  Future<ImageLoadingConfig> onImageLoad(
      ComicSource source, String url, String comicId, String epId) async {
    if (!source.canOnImageLoad) return ImageLoadingConfig(url: url);
    final result = await _engine.evaluate('''
      (() => {
        const cls = Object.values(globalThis).find(
          (v) => typeof v === 'function' && v.prototype instanceof ComicSource);
        const s = new cls();
        return s.comic.onImageLoad(${jsonEncode(url)}, ${jsonEncode(comicId)}, ${jsonEncode(epId)});
      })()
    ''');
    if (result is! Map) return ImageLoadingConfig(url: url);
    return ImageLoadingConfig.fromJs(result);
  }

  List<Comic> _comicsFrom(dynamic result) {
    if (result is! Map) return const [];
    final comics = result['comics'];
    if (comics is! List) return const [];
    return comics
        .whereType<Map>()
        .map((e) => Comic.fromJs(e.cast<dynamic, dynamic>()))
        .toList();
  }

  void dispose() => _engine.dispose();
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_source_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/comic/comic_source.dart test/core/comic/comic_source_test.dart
git commit -m "feat(comic): add ComicSource and ComicSourceManager"
```

---

### Task 6: End-to-end test source

**Files:**
- Create: `assets/comic_source/test_source.js`
- Test: `test/core/comic/comic_source_e2e_test.dart`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Create the fixture source**

Create `assets/comic_source/test_source.js`:

```javascript
// A self-contained test source: every "request" is answered from an inline
// HTML string, so the e2e test needs no network.
class AcgnhubTestSource extends ComicSource {
  name = "TestSource";
  key = "acgnhub_test";
  version = "1.0.0";

  search = {
    load: (keyword, options, page) => {
      const doc = new HtmlDocument(
        '<ul><li><a href="/c/1" title="' + keyword + ' One</a></li>' +
        '<li><a href="/c/2">' + keyword + ' Two</a></li></ul>');
      const comics = doc.querySelectorAll('a').map(
        (a) => new Comic({ id: a.attr('href'), title: a.text }));
      return { comics: comics, maxPage: 1 };
    },
  };

  comic = {
    loadInfo: (id) => new ComicDetails({
      id: id,
      title: 'Test ' + id,
      chapters: { 'ep1': '第1话', 'ep2': '第2话' },
    }),
    loadEp: (comicId, epId) => ({ images: ['http://img/1.jpg', 'http://img/2.jpg'] }),
    onImageLoad: (url) => ({ url: url, headers: { 'referer': 'http://test/' } }),
  };
}
```

- [ ] **Step 2: Write the failing test**

Create `test/core/comic/comic_source_e2e_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:acgnhub/core/comic/comic_source.dart';
import 'package:acgnhub/core/comic/js_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JsEngine engine;

  setUp(() async {
    engine = JsEngine();
    final lib = await rootBundle.loadString('assets/comic_source/init.js');
    await engine.evaluate(lib);
    final src = await rootBundle.loadString('assets/comic_source/test_source.js');
    await engine.evaluate(src);
  });
  tearDown(() => engine.dispose());

  Future<dynamic> call(String body) => engine.evaluate(body);

  test('search maps comics', () async {
    final result = await call('''
      (() => {
        const cls = Object.values(globalThis).find(
          (v) => typeof v === 'function' && v.prototype instanceof ComicSource);
        return new cls().search.load('海贼', {}, 1);
      })()
    ''');
    final comics = (result as Map)['comics'] as List;
    expect(comics, hasLength(2));
    expect(comics.first['id'], '/c/1');
    expect(comics.first['title'], '海贼 One');
  });

  test('loadInfo maps chapters and loadEp maps images', () async {
    final info = await call('''
      (() => {
        const cls = Object.values(globalThis).find(
          (v) => typeof v === 'function' && v.prototype instanceof ComicSource);
        const s = new cls();
        return s.comic.loadInfo('/c/1');
      })()
    ''');
    final details = ComicDetails.fromJs(info as Map);
    expect(details.chapters, {'ep1': '第1话', 'ep2': '第2话'});

    final ep = await call('''
      (() => {
        const cls = Object.values(globalThis).find(
          (v) => typeof v === 'function' && v.prototype instanceof ComicSource);
        return new cls().comic.loadEp('/c/1', 'ep1');
      })()
    ''');
    expect(ComicEp.fromJs(ep as Map).images, hasLength(2));
  });

  test('onImageLoad returns headers', () async {
    final config = await call('''
      (() => {
        const cls = Object.values(globalThis).find(
          (v) => typeof v === 'function' && v.prototype instanceof ComicSource);
        return new cls().comic.onImageLoad('http://img/1.jpg', '/c/1', 'ep1');
      })()
    ''');
    expect(ImageLoadingConfig.fromJs(config as Map).headers,
        {'referer': 'http://test/'});
  });
}
```

- [ ] **Step 3: Run the test to verify it fails, then passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_source_e2e_test.dart`
Expected first: FAIL (fixture missing). After adding the fixture (Step 1) and any needed `init.js` fixes: PASS (3 tests). If the JS API library needs adjustment to make this pass, adjust it and say so in the report.

- [ ] **Step 4: Analyze and run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.

- [ ] **Step 5: Commit**

```bash
git add assets/comic_source/test_source.js test/core/comic/comic_source_e2e_test.dart
git commit -m "test(comic): add an end-to-end JS source fixture and test"
```

---

### Task 7: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → `Built build\windows\x64\runner\Debug\acgnhub.exe`

- [ ] **Step 2: Real-source sanity check (manual)**

Download one real Venera comic source `.js` from `https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/index.json` (pick an entry with a `url`), save it under `<app support>/comic_source/`, and run a probe that calls `ComicSourceManager.load()` + `search` for a known title, printing the source count and the first result. Record the outcome — a real source may need JS API features C1 does not implement; that is expected and should be reported, not "fixed" by adding features.

- [ ] **Step 3: Record the results**

Write the observed output into the task report.

---

## Self-Review

- **Spec coverage:** §3 files → Tasks 1–5; §4 JS API library → Task 4; §5 bridge → Task 3; §6 models → Task 4; §7 manager → Task 5; §8 error handling → Tasks 3, 5; §9 testing → Tasks 1–3, 6, 7.
- **Placeholders:** none — every step has complete code or an exact command.
- **Type consistency:** `JsEngine({dio, settings})`/`evaluate`/`installBridge`/`dispose`; `HtmlBridge` ops; `Comic`/`ComicDetails`/`ComicEp`/`ImageLoadingConfig` `fromJs`; `ComicSource`/`ComicSourceManager` methods; `assets/comic_source/init.js` + `test_source.js` — used consistently across tasks.
