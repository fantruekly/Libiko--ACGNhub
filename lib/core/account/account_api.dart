import 'package:dio/dio.dart';

import 'account_models.dart';

class AccountException implements Exception {
  final int? statusCode;
  final String code;
  final String message;

  const AccountException({
    this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'AccountException($statusCode, $code): $message';
}

class AccountApi {
  AccountApi(String baseUrl, {Dio? dio})
      : baseUrl = _normalize(baseUrl),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
              validateStatus: (_) => true,
            ));

  final String baseUrl;
  final Dio _dio;

  static String _normalize(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  Future<AuthSession> register(String username, String password) =>
      _session('/api/auth/register', username, password);

  Future<AuthSession> login(String username, String password) =>
      _session('/api/auth/login', username, password);

  Future<AuthSession> _session(
      String path, String username, String password) async {
    final json =
        await _request(() => _dio.post('$baseUrl$path', data: {
              'username': username,
              'password': password,
            }));
    return AuthSession.fromJson(json);
  }

  Future<String> refresh(String refreshToken) async {
    final json = await _request(() => _dio.post('$baseUrl/api/auth/refresh',
        data: {'refreshToken': refreshToken}));
    return json['token'] as String;
  }

  Future<AccountUser> me(String token) async {
    final json = await _request(() => _dio.get('$baseUrl/api/me',
        options: Options(headers: {'authorization': 'Bearer $token'})));
    return AccountUser.fromJson(json);
  }

  Future<Map<String, dynamic>> _request(
      Future<Response> Function() send) async {
    final Response response;
    try {
      response = await send();
    } on DioException catch (e) {
      throw AccountException(code: 'network', message: _networkMessage(e));
    }
    final status = response.statusCode ?? 0;
    final data = response.data;
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    if (status >= 200 && status < 300) return map;
    throw AccountException(
      statusCode: status,
      code: map['error'] as String? ?? 'http',
      message: map['message'] as String? ?? '请求失败（$status）',
    );
  }

  static String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '连接超时';
      case DioExceptionType.connectionError:
        return '无法连接服务器';
      default:
        return '网络错误';
    }
  }
}
