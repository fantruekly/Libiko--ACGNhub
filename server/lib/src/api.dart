import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth.dart';
import 'database.dart';

class Api {
  Api(this.db, this.auth);

  final Database db;
  final Auth auth;

  static final _usernameRe = RegExp(r'^[A-Za-z0-9_-]{3,32}$');

  Handler get handler {
    final router = Router()
      ..post('/api/auth/register', _register)
      ..post('/api/auth/login', _login)
      ..post('/api/auth/refresh', _refresh)
      ..get('/api/follows', _auth(_listFollows))
      ..put('/api/follows', _auth(_putFollow))
      ..delete('/api/follows/<workId>', _deleteFollowRoute)
      ..get('/api/history', _auth(_listHistory))
      ..put('/api/history', _auth(_putHistory))
      ..delete('/api/history', _auth(_clearHistory))
      ..get('/api/sync', _auth(_sync))
      ..get('/api/me', _auth(_me));
    return Pipeline().addHandler(_guard(router.call));
  }

  Response _json(int status, Object body) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Response _error(int status, String code, String message) =>
      _json(status, {'error': code, 'message': message});

  Future<Map<String, dynamic>?> _readJson(Request req) async {
    try {
      final decoded = jsonDecode(await req.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Converts an unexpected exception into a 500 without leaking details.
  Handler _guard(Handler inner) {
    return (Request req) async {
      try {
        return await inner(req);
      } catch (e, st) {
        // ignore: avoid_print
        print('Unhandled error on ${req.method} ${req.requestedUri.path}: $e\n$st');
        return _error(500, 'internal', 'Internal server error');
      }
    };
  }

  /// Requires a valid access token and injects the user id into the context.
  Future<Response> Function(Request) _auth(
      Future<Response> Function(Request) inner) {
    return (Request req) async {
      final userId = _userId(req);
      if (userId == null) {
        return _error(401, 'unauthorized', 'Missing or invalid token');
      }
      return inner(req.change(context: {'userId': userId}));
    };
  }

  int? _userId(Request req) {
    final header = req.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    return auth.verifyToken(header.substring(7));
  }

  int _ctxUserId(Request req) => req.context['userId'] as int;

  Future<Response> _register(Request req) async {
    final body = await _readJson(req);
    if (body == null) return _error(400, 'bad_request', 'Expected a JSON object');

    final username = body['username'];
    final password = body['password'];
    if (username is! String || !_usernameRe.hasMatch(username)) {
      return _error(400, 'bad_request',
          'username must be 3-32 characters of A-Z a-z 0-9 _ -');
    }
    if (password is! String || password.length < 6) {
      return _error(400, 'bad_request', 'password must be at least 6 characters');
    }
    if (utf8.encode(password as String).length > 72) {
      return _error(400, 'bad_request', 'password must be at most 72 bytes');
    }
    if (db.findUserByName(username) != null) {
      return _error(409, 'conflict', 'Username already taken');
    }

    final id = db.createUser(username, auth.hashPassword(password));
    return _json(201, {
      'token': auth.issueAccessToken(id),
      'refreshToken': auth.issueRefreshToken(id),
      'user': {'id': id, 'username': username},
    });
  }

  Future<Response> _login(Request req) async {
    final body = await _readJson(req);
    if (body == null) return _error(400, 'bad_request', 'Expected a JSON object');

    final username = body['username'];
    final password = body['password'];
    if (username is! String || password is! String) {
      return _error(400, 'bad_request', 'username and password are required');
    }

    final user = db.findUserByName(username);
    if (user == null ||
        !auth.verifyPassword(password, user['password_hash'] as String)) {
      return _error(401, 'unauthorized', 'Invalid username or password');
    }

    final id = user['id'] as int;
    return _json(200, {
      'token': auth.issueAccessToken(id),
      'refreshToken': auth.issueRefreshToken(id),
      'user': {'id': id, 'username': user['username']},
    });
  }

  Future<Response> _refresh(Request req) async {
    final body = await _readJson(req);
    if (body == null) return _error(400, 'bad_request', 'Expected a JSON object');

    final refreshToken = body['refreshToken'];
    if (refreshToken is! String) {
      return _error(400, 'bad_request', 'refreshToken is required');
    }
    final userId = auth.verifyToken(refreshToken, type: 'refresh');
    if (userId == null) {
      return _error(401, 'unauthorized', 'Invalid or expired refresh token');
    }
    return _json(200, {'token': auth.issueAccessToken(userId)});
  }

  Future<Response> _me(Request req) async {
    final user = db.findUserById(_ctxUserId(req));
    if (user == null) return _error(401, 'unauthorized', 'Unknown user');
    return _json(200, {'id': user['id'], 'username': user['username']});
  }

  /// `shelf_router` passes the path parameter as a second argument.
  Future<Response> _deleteFollowRoute(Request req, String workId) =>
      _auth((r) => _deleteFollow(r, workId))(req);

  Future<Response> _listFollows(Request req) async {
    final items = db.listFollows(_ctxUserId(req)).map((row) {
      return {
        'work': jsonDecode(row['work_json'] as String),
        'updatedAt': row['client_updated_at'],
      };
    }).toList();
    return _json(200, {'items': items});
  }

  Future<Response> _putFollow(Request req) async {
    final body = await _readJson(req);
    if (body == null) return _error(400, 'bad_request', 'Expected a JSON object');
    final work = body['work'];
    final updatedAt = body['updatedAt'];
    if (work is! Map<String, dynamic> || work['id'] is! String) {
      return _error(400, 'bad_request', 'work.id is required');
    }
    if (updatedAt is! int) {
      return _error(400, 'bad_request', 'updatedAt must be an integer');
    }
    final row = db.upsertFollow(
      userId: _ctxUserId(req),
      workId: work['id'] as String,
      work: work,
      updatedAt: updatedAt,
    );
    return _json(200, {
      'work': jsonDecode(row['work_json'] as String),
      'updatedAt': row['client_updated_at'],
    });
  }

  Future<Response> _deleteFollow(Request req, String workId) async {
    final updatedAt =
        int.tryParse(req.url.queryParameters['updatedAt'] ?? '');
    if (updatedAt == null) {
      return _error(400, 'bad_request', 'updatedAt query parameter is required');
    }
    final userId = _ctxUserId(req);
    final existing = db.getFollow(userId, workId);
    final work = existing == null
        ? const <String, dynamic>{}
        : jsonDecode(existing['work_json'] as String) as Map<String, dynamic>;
    final row = db.upsertFollow(
      userId: userId,
      workId: workId,
      work: work,
      updatedAt: updatedAt,
      deleted: true,
    );
    return _json(200, {'workId': workId, 'updatedAt': row['client_updated_at']});
  }

  Future<Response> _listHistory(Request req) async {
    final items = db.listHistory(_ctxUserId(req)).map((row) {
      return {
        'work': jsonDecode(row['work_json'] as String),
        'episodeTitle': row['episode_title'],
        'episodeIndex': row['episode_index'],
        'watchedAt': row['watched_at'],
        'updatedAt': row['client_updated_at'],
      };
    }).toList();
    return _json(200, {'items': items});
  }

  Future<Response> _putHistory(Request req) async {
    final body = await _readJson(req);
    if (body == null) return _error(400, 'bad_request', 'Expected a JSON object');
    final work = body['work'];
    final episodeTitle = body['episodeTitle'];
    final episodeIndex = body['episodeIndex'];
    final watchedAt = body['watchedAt'];
    final updatedAt = body['updatedAt'];
    if (work is! Map<String, dynamic> || work['id'] is! String) {
      return _error(400, 'bad_request', 'work.id is required');
    }
    if (episodeTitle is! String ||
        episodeIndex is! int ||
        watchedAt is! int ||
        updatedAt is! int) {
      return _error(400, 'bad_request',
          'episodeTitle, episodeIndex, watchedAt and updatedAt are required');
    }
    final row = db.upsertHistory(
      userId: _ctxUserId(req),
      workId: work['id'] as String,
      work: work,
      episodeTitle: episodeTitle,
      episodeIndex: episodeIndex,
      watchedAt: watchedAt,
      updatedAt: updatedAt,
    );
    return _json(200, {
      'work': jsonDecode(row['work_json'] as String),
      'episodeTitle': row['episode_title'],
      'episodeIndex': row['episode_index'],
      'watchedAt': row['watched_at'],
      'updatedAt': row['client_updated_at'],
    });
  }

  Future<Response> _clearHistory(Request req) async {
    final updatedAt = int.tryParse(req.url.queryParameters['updatedAt'] ?? '');
    if (updatedAt == null) {
      return _error(400, 'bad_request', 'updatedAt query parameter is required');
    }
    final count = db.clearHistory(_ctxUserId(req), updatedAt);
    return _json(200, {'deleted': count});
  }

  Future<Response> _sync(Request req) async {
    final userId = _ctxUserId(req);
    final sinceSeq = int.tryParse(req.url.queryParameters['sinceSeq'] ?? '0') ?? 0;

    final follows = db.followsSince(userId, sinceSeq).map((row) {
      return {
        'work': jsonDecode(row['work_json'] as String),
        'updatedAt': row['client_updated_at'],
        'deleted': (row['deleted'] as int) == 1,
      };
    }).toList();

    final history = db.historySince(userId, sinceSeq).map((row) {
      return {
        'work': jsonDecode(row['work_json'] as String),
        'episodeTitle': row['episode_title'],
        'episodeIndex': row['episode_index'],
        'watchedAt': row['watched_at'],
        'updatedAt': row['client_updated_at'],
        'deleted': (row['deleted'] as int) == 1,
      };
    }).toList();

    return _json(200, {
      'follows': follows,
      'history': history,
      'nextSeq': db.currentSeq(userId),
    });
  }
}
