import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

import 'html_bridge.dart';

const _defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

class JsEngine {
  JsEngine({
    Dio? dio,
    Map<String, String> Function()? settings,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (_) => true,
            )),
        _settings = settings ?? (() => <String, String>{});

  final FlutterQjs _engine = FlutterQjs(
    stackSize: 1024 * 1024,
    timeout: 5000,
    memoryLimit: 64 * 1024 * 1024,
  );
  final Dio _dio;
  final Map<String, String> Function() _settings;
  final Map<String, dynamic> _cookieJar = {};
  final HtmlBridge _html = HtmlBridge();
  bool _installed = false;
  Future<void> _lock = Future<void>.value();

  void installBridge() {
    if (_installed) return;
    _installed = true;
    _engine.dispatch();
    final setter = _engine.evaluate(
        '(fn) => { globalThis.sendMessage = fn; return true; }') as JSInvokable;
    setter.invoke([_handle]);
    setter.free();
  }

  Future<dynamic> evaluate(String code) {
    final completer = Completer<dynamic>();
    _lock = _lock.then((_) async {
      try {
        completer.complete(await _engine.evaluate(code));
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  dynamic _handle(Map<dynamic, dynamic> map) {
    switch (map['method']) {
      case 'http':
        return _http(map);
      case 'convert':
        return _convert(map);
      case 'html':
        return _htmlOp(map);
      case 'setting':
        return _setting(map);
      case 'cookie':
        return _cookie(map);
      case 'log':
        debugPrint('[comic-source] ${map['message']}');
        return null;
      default:
        throw Exception('Unknown bridge method: ${map['method']}');
    }
  }

  /// Cookies stored for [url]'s host, joined into a single `Cookie` header.
  String? _cookieHeaderFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    final values = <String>[];
    for (final entry in _cookieJar.entries) {
      final key = Uri.tryParse(entry.key.toString());
      if (key == null || key.host != uri.host) continue;
      final value = entry.value?.toString();
      if (value == null || value.isEmpty) continue;
      values.add(value);
    }
    return values.isEmpty ? null : values.join('; ');
  }

  Future<Map<String, dynamic>> _http(Map<dynamic, dynamic> map) async {
    final headers = <String, dynamic>{
      for (final e in (map['headers'] as Map? ?? {}).entries)
        e.key.toString(): e.value
    };
    headers.putIfAbsent('user-agent', () => _defaultUserAgent);
    final cookie = _cookieHeaderFor(map['url'] as String);
    final hasCookie =
        headers.keys.any((k) => k.toLowerCase() == 'cookie');
    if (!hasCookie && cookie != null) headers['cookie'] = cookie;
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
        'body': bytes
            ? response.data as Uint8List
            : (response.data ?? '').toString(),
      };
    } on DioException catch (e) {
      return {'status': 0, 'headers': const {}, 'body': '', 'error': '$e'};
    }
  }

  List<int> _bytes(dynamic data) {
    if (data is List<int>) return data;
    if (data is List) return data.map((e) => (e as num).toInt()).toList();
    if (data is Uint8List) return data;
    throw ArgumentError('expected a byte array, got ${data.runtimeType}');
  }

  dynamic _convert(Map<dynamic, dynamic> map) {
    final type = map['type'] as String;
    final data = map['data']?.toString() ?? '';
    final dataBytes = utf8.encode(data);
    switch (type) {
      case 'utf8':
        return utf8.decode(_bytes(map['data']), allowMalformed: true);
      case 'utf8Encode':
        return utf8.encode(data);
      case 'gbk':
        return gbk.decode(_bytes(map['data']));
      case 'base64Encode':
        return base64.encode(dataBytes);
      case 'base64Decode':
        return base64.decode(data);
      case 'hexEncode':
        return dataBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      case 'hexDecode':
        if (data.length.isOdd) {
          throw FormatException('hexDecode requires an even number of digits');
        }
        return Uint8List.fromList([
          for (var i = 0; i < data.length; i += 2)
            int.parse(data.substring(i, i + 2), radix: 16)
        ]);
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

  static const _settingPrefix = 'source_setting.';

  dynamic _setting(Map<dynamic, dynamic> map) {
    final store = _settings();
    final key = map['key'] as String;
    if (!key.startsWith(_settingPrefix)) {
      throw Exception('setting key out of scope: $key');
    }
    if (map['op'] == 'set') {
      store[key] = map['value']?.toString() ?? '';
      return null;
    }
    return store[key];
  }

  dynamic _cookie(Map<dynamic, dynamic> map) {
    final url = map['url']?.toString() ?? '';
    if (map['op'] == 'set') {
      final value = map['cookies'];
      if (value == null || (value is String && value.isEmpty)) {
        _cookieJar.remove(url);
      } else {
        _cookieJar[url] = value;
      }
      return null;
    }
    return _cookieJar[url];
  }

  void dispose() {
    _html.dispose();
    try {
      _engine.port.close();
      _engine.close();
    } catch (e) {
      debugPrint('[JsEngine] dispose: $e');
    }
  }
}
