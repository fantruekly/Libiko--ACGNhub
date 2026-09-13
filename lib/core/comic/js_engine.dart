import 'package:flutter/foundation.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

class JsEngine {
  JsEngine() {
    _engine.dispatch();
  }

  final FlutterQjs _engine = FlutterQjs(stackSize: 1024 * 1024);

  Future<dynamic> evaluate(String code) async => _engine.evaluate(code);

  void dispose() {
    try {
      _engine.port.close();
      _engine.close();
    } catch (e) {
      debugPrint('[JsEngine] dispose: $e');
    }
  }
}
