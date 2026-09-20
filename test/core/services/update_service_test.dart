import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/services/update_service.dart';

void main() {
  test('isNewerVersion compares semver', () {
    expect(UpdateService.isNewerVersion('1.0.0', '1.0.1'), isTrue);
    expect(UpdateService.isNewerVersion('1.0.0', '1.1.0'), isTrue);
    expect(UpdateService.isNewerVersion('1.0.0', '2.0.0'), isTrue);
    expect(UpdateService.isNewerVersion('1.0.0', 'v1.0.1'), isTrue);
    expect(UpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
    expect(UpdateService.isNewerVersion('1.2.0', '1.1.9'), isFalse);
    expect(UpdateService.isNewerVersion('1.0.0', 'abc'), isFalse);
  });

  test('check returns an UpdateInfo for a newer release', () async {
    final dio = Dio()..httpClientAdapter = _JsonAdapter({
          'tag_name': 'v0.2.0',
          'body': '更新说明',
          'html_url': 'https://example.com/release',
        });
    final info = await UpdateService(dio: dio).check('0.1.0');
    expect(info?.version, '0.2.0');
    expect(info?.notes, '更新说明');
    expect(info?.url, 'https://example.com/release');
  });

  test('check returns null when already latest', () async {
    final dio = Dio()..httpClientAdapter = _JsonAdapter({'tag_name': 'v0.1.0'});
    expect(await UpdateService(dio: dio).check('0.1.0'), isNull);
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.json);
  final Map<String, dynamic> json;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      const JsonEncoder().convert(json),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
