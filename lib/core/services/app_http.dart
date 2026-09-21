import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// A single shared [Dio] for requests that do not need a bespoke client.
///
/// Reusing one client keeps a single connection pool alive across the app, so
/// repeated requests to the same host reuse TCP/TLS connections instead of
/// opening a fresh pool for every `Dio()` instance. The idle timeout is raised
/// above dio's 3s default so a connection survives the gap between requests.
class AppHttp {
  AppHttp._();

  static final Dio client = _create();

  static Dio _create() {
    final httpClient = HttpClient()
      ..idleTimeout = const Duration(seconds: 30)
      ..maxConnectionsPerHost = 8;
    return Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (_) => true,
    ))
      ..httpClientAdapter =
          IOHttpClientAdapter(createHttpClient: () => httpClient);
  }
}
