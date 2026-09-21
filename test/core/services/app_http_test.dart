import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/services/app_http.dart';

void main() {
  test('exposes one shared client with a keep-alive io adapter', () {
    final client = AppHttp.client;

    expect(client.httpClientAdapter, isA<IOHttpClientAdapter>());
    expect(client.options.connectTimeout, const Duration(seconds: 15));
    expect(client.options.receiveTimeout, const Duration(seconds: 20));
    expect(client.options.validateStatus(400), isTrue);
  });
}
