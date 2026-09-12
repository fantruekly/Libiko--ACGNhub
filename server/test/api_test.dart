import 'dart:convert';

import 'package:acgnhub_server/src/api.dart';
import 'package:acgnhub_server/src/auth.dart';
import 'package:acgnhub_server/src/database.dart';
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
}
