import 'dart:convert';

import 'package:libiko_server/src/api.dart';
import 'package:libiko_server/src/auth.dart';
import 'package:libiko_server/src/database.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late Api api;

  setUp(() {
    db = Database.open(':memory:');
    api = Api(db, Auth('test-secret'));
  });
  tearDown(() => db.dispose());

  Future<Response> call(String method, String path,
      {Object? body, String? token}) {
    return Future.value(api.handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {
        if (body != null) 'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      },
    )));
  }

  Future<Map<String, dynamic>> jsonOf(Response res) async =>
      jsonDecode(await res.readAsString()) as Map<String, dynamic>;

  test('register returns tokens and the user', () async {
    final res = await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'});
    expect(res.statusCode, 201);
    final json = await jsonOf(res);
    expect(json['user'], {'id': 1, 'username': 'alice'});
    expect(json['token'], isA<String>());
    expect(json['refreshToken'], isA<String>());
  });

  test('register rejects a duplicate username with 409', () async {
    await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'});
    final res = await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'});
    expect(res.statusCode, 409);
    expect((await jsonOf(res))['error'], 'conflict');
  });

  test('register validates username and password with 400', () async {
    final short = await call('POST', '/api/auth/register',
        body: {'username': 'ab', 'password': 'secret1'});
    expect(short.statusCode, 400);
    final badChars = await call('POST', '/api/auth/register',
        body: {'username': 'a b', 'password': 'secret1'});
    expect(badChars.statusCode, 400);
    final shortPw = await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': '123'});
    expect(shortPw.statusCode, 400);
  });

  test('register rejects a password longer than 72 bytes with 400', () async {
    final res = await call('POST', '/api/auth/register',
        body: {
          'username': 'alice',
          'password': List.filled(25, '中').join(),
        });
    expect(res.statusCode, 400);
    expect((await jsonOf(res))['error'], 'bad_request');
  });

  test('login succeeds and rejects a wrong password', () async {
    await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'});
    final ok = await call('POST', '/api/auth/login',
        body: {'username': 'alice', 'password': 'secret1'});
    expect(ok.statusCode, 200);
    final bad = await call('POST', '/api/auth/login',
        body: {'username': 'alice', 'password': 'nope'});
    expect(bad.statusCode, 401);
  });

  test('refresh issues a new access token', () async {
    final reg = await jsonOf(await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'}));
    final res = await call('POST', '/api/auth/refresh',
        body: {'refreshToken': reg['refreshToken']});
    expect(res.statusCode, 200);
    final token = (await jsonOf(res))['token'] as String;
    expect(api.auth.verifyToken(token), 1);
  });

  test('protected routes reject a missing or invalid token', () async {
    expect((await call('GET', '/api/me')).statusCode, 401);
    expect((await call('GET', '/api/me', token: 'garbage')).statusCode, 401);
  });

  test('me returns the current user', () async {
    final reg = await jsonOf(await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'}));
    final res = await call('GET', '/api/me', token: reg['token'] as String);
    expect(res.statusCode, 200);
    expect(await jsonOf(res), {'id': 1, 'username': 'alice'});
  });

  Future<String> registerToken(String username) async {
    final json = await jsonOf(await call('POST', '/api/auth/register',
        body: {'username': username, 'password': 'secret1'}));
    return json['token'] as String;
  }

  test('follows: put, list, delete', () async {
    final token = await registerToken('alice');
    final put = await call('PUT', '/api/follows',
        token: token,
        body: {
          'work': {'id': 'w1', 'title': 'A'},
          'updatedAt': 100,
        });
    expect(put.statusCode, 200);

    final list = await jsonOf(await call('GET', '/api/follows', token: token));
    expect((list['items'] as List), hasLength(1));
    expect((list['items'] as List).first['work']['id'], 'w1');

    final del = await call('DELETE', '/api/follows/w1?updatedAt=200', token: token);
    expect(del.statusCode, 200);
    final after = await jsonOf(await call('GET', '/api/follows', token: token));
    expect(after['items'], isEmpty);
  });

  test('follows: an older put does not overwrite a newer one (LWW)', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/follows',
        token: token, body: {'work': {'id': 'w1', 'title': 'new'}, 'updatedAt': 200});
    final stale = await jsonOf(await call('PUT', '/api/follows',
        token: token, body: {'work': {'id': 'w1', 'title': 'old'}, 'updatedAt': 100}));
    expect(stale['work']['title'], 'new');
    expect(stale['updatedAt'], 200);
  });

  test('history: put, list by watchedAt desc, clear', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/history', token: token, body: {
      'work': {'id': 'w1'}, 'episodeTitle': '第1集', 'episodeIndex': 0,
      'watchedAt': 100, 'updatedAt': 100,
    });
    await call('PUT', '/api/history', token: token, body: {
      'work': {'id': 'w2'}, 'episodeTitle': '第9集', 'episodeIndex': 8,
      'watchedAt': 300, 'updatedAt': 300,
    });

    final list = await jsonOf(await call('GET', '/api/history', token: token));
    final items = list['items'] as List;
    expect(items.map((e) => e['work']['id']).toList(), ['w2', 'w1']);
    expect(items.first['episodeTitle'], '第9集');

    final cleared = await call('DELETE', '/api/history?updatedAt=400', token: token);
    expect(cleared.statusCode, 200);
    expect((await jsonOf(await call('GET', '/api/history', token: token)))['items'],
        isEmpty);
  });

  test('follows and history reject a missing body field with 400', () async {
    final token = await registerToken('alice');
    expect((await call('PUT', '/api/follows',
            token: token, body: {'updatedAt': 1}))
        .statusCode, 400);
    expect((await call('PUT', '/api/history',
            token: token, body: {'work': {'id': 'w1'}}))
        .statusCode, 400);
  });

  test('one user cannot see another user\'s follows', () async {
    final a = await registerToken('alice');
    final b = await registerToken('bob');
    await call('PUT', '/api/follows',
        token: a, body: {'work': {'id': 'w1'}, 'updatedAt': 1});
    final list = await jsonOf(await call('GET', '/api/follows', token: b));
    expect(list['items'], isEmpty);
  });

  test('sync returns changes after the given seq and a nextSeq cursor', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/follows',
        token: token, body: {'work': {'id': 'w1'}, 'updatedAt': 100});

    final first = await jsonOf(await call('GET', '/api/sync?sinceSeq=0', token: token));
    expect((first['follows'] as List), hasLength(1));
    expect((first['follows'] as List).first['deleted'], false);
    final next = first['nextSeq'] as int;
    expect(next, greaterThan(0));

    final second =
        await jsonOf(await call('GET', '/api/sync?sinceSeq=$next', token: token));
    expect(second['follows'], isEmpty);
    expect(second['history'], isEmpty);
  });

  test('sync surfaces tombstones with deleted true', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/follows',
        token: token, body: {'work': {'id': 'w1'}, 'updatedAt': 100});
    await call('DELETE', '/api/follows/w1?updatedAt=200', token: token);

    final sync = await jsonOf(await call('GET', '/api/sync?sinceSeq=0', token: token));
    final follows = sync['follows'] as List;
    expect(follows, hasLength(1));
    expect(follows.first['deleted'], true);
    expect(follows.first['work']['id'], 'w1');
  });

  test('sync includes history with its fields', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/history', token: token, body: {
      'work': {'id': 'w1'}, 'episodeTitle': '第3集', 'episodeIndex': 2,
      'watchedAt': 100, 'updatedAt': 100,
    });
    final sync = await jsonOf(await call('GET', '/api/sync?sinceSeq=0', token: token));
    final history = sync['history'] as List;
    expect(history, hasLength(1));
    expect(history.first['episodeTitle'], '第3集');
    expect(history.first['deleted'], false);
  });

  test('sync history tombstones stay identifiable after a clear', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/history', token: token, body: {
      'work': {'id': 'w1', 'title': 'A'}, 'episodeTitle': '第3集',
      'episodeIndex': 2, 'watchedAt': 100, 'updatedAt': 100,
    });
    await call('DELETE', '/api/history?updatedAt=200', token: token);

    final sync = await jsonOf(await call('GET', '/api/sync?sinceSeq=0', token: token));
    final history = sync['history'] as List;
    expect(history, hasLength(1));
    expect(history.first['deleted'], true);
    expect(history.first['work']['id'], 'w1');
    expect(history.first['episodeTitle'], '第3集');
  });
}
