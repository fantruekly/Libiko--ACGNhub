import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/account/account_api.dart';

/// A Dio adapter that records the last request and returns a canned response.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode, this.body);
  final int statusCode;
  final String body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AccountApi _api(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  dio.httpClientAdapter = adapter;
  return AccountApi('http://127.0.0.1:8080/', dio: dio);
}

void main() {
  test('login posts to /api/auth/login and parses the session', () async {
    final adapter = _FakeAdapter(
      200,
      jsonEncode({
        'token': 't1',
        'refreshToken': 'r1',
        'user': {'id': 1, 'username': 'alice'},
      }),
    );
    final session = await _api(adapter).login('alice', 'secret1');

    expect(session.token, 't1');
    expect(session.refreshToken, 'r1');
    expect(session.user.username, 'alice');
    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.uri.toString(), 'http://127.0.0.1:8080/api/auth/login');
    expect(adapter.last!.data, {'username': 'alice', 'password': 'secret1'});
  });

  test('me sends the bearer token and parses the user', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'id': 2, 'username': 'bob'}));
    final user = await _api(adapter).me('tok');

    expect(user.id, 2);
    expect(user.username, 'bob');
    expect(adapter.last!.uri.path, '/api/me');
    expect(adapter.last!.headers['authorization'], 'Bearer tok');
  });

  test('refresh returns the new access token', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'token': 't2'}));
    expect(await _api(adapter).refresh('r1'), 't2');
    expect(adapter.last!.uri.path, '/api/auth/refresh');
  });

  test('a non-2xx response becomes an AccountException with the backend code',
      () async {
    final adapter = _FakeAdapter(
      409,
      jsonEncode({'error': 'conflict', 'message': 'Username already taken'}),
    );
    await expectLater(
      _api(adapter).register('alice', 'secret1'),
      throwsA(isA<AccountException>()
          .having((e) => e.statusCode, 'statusCode', 409)
          .having((e) => e.code, 'code', 'conflict')
          .having((e) => e.message, 'message', 'Username already taken')),
    );
  });

  test('a connection failure becomes a network AccountException', () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true));
    dio.httpClientAdapter = _ThrowingAdapter();
    final api = AccountApi('http://127.0.0.1:8080', dio: dio);

    await expectLater(
      api.login('alice', 'secret1'),
      throwsA(isA<AccountException>().having((e) => e.code, 'code', 'network')),
    );
  });

  test('sync parses the page and sends sinceSeq', () async {
    final adapter = _FakeAdapter(
      200,
      jsonEncode({
        'follows': [
          {'work': {'id': 'w1'}, 'updatedAt': 5, 'deleted': false}
        ],
        'history': [
          {
            'work': {'id': 'w1'},
            'episodeTitle': '第3集',
            'episodeIndex': 2,
            'watchedAt': 9,
            'updatedAt': 9,
            'deleted': false,
          }
        ],
        'nextSeq': 4,
      }),
    );
    final page = await _api(adapter).sync('tok', 3);

    expect(page.nextSeq, 4);
    expect(page.follows.single.work['id'], 'w1');
    expect(page.history.single.episodeTitle, '第3集');
    expect(adapter.last!.uri.queryParameters['sinceSeq'], '3');
    expect(adapter.last!.headers['authorization'], 'Bearer tok');
  });

  test('putFollow posts the work and updatedAt', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'work': {}, 'updatedAt': 5}));
    await _api(adapter).putFollow('tok', {'id': 'w1'}, 5);
    expect(adapter.last!.method, 'PUT');
    expect(adapter.last!.uri.path, '/api/follows');
    expect(adapter.last!.data, {'work': {'id': 'w1'}, 'updatedAt': 5});
  });

  test('deleteFollow sends workId and updatedAt as a query parameter', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'workId': 'w1'}));
    await _api(adapter).deleteFollow('tok', 'w1', 7);
    expect(adapter.last!.method, 'DELETE');
    expect(adapter.last!.uri.path, '/api/follows/w1');
    expect(adapter.last!.uri.queryParameters['updatedAt'], '7');
  });

  test('putHistory posts the episode fields', () async {
    final adapter = _FakeAdapter(200, jsonEncode({}));
    await _api(adapter).putHistory('tok', {'id': 'w1'}, '第3集', 2, 9, 9);
    expect(adapter.last!.uri.path, '/api/history');
    expect(adapter.last!.data, {
      'work': {'id': 'w1'},
      'episodeTitle': '第3集',
      'episodeIndex': 2,
      'watchedAt': 9,
      'updatedAt': 9,
    });
  });

  test('clearHistory deletes with updatedAt', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'deleted': 2}));
    await _api(adapter).clearHistory('tok', 11);
    expect(adapter.last!.method, 'DELETE');
    expect(adapter.last!.uri.path, '/api/history');
    expect(adapter.last!.uri.queryParameters['updatedAt'], '11');
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    throw DioException.connectionError(
        requestOptions: options, reason: 'refused');
  }

  @override
  void close({bool force = false}) {}
}
