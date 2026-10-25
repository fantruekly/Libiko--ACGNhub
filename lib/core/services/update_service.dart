import 'dart:async';

import 'package:dio/dio.dart';

class UpdateInfo {
  final String version;
  final String notes;
  final String url;
  final DateTime? publishedAt;

  const UpdateInfo(
      {required this.version,
      required this.notes,
      required this.url,
      this.publishedAt});
}

enum UpdateCheckFailure {
  timeout,
  network,
  rateLimited,
  server,
  invalidResponse
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.kind, this.message);
  final UpdateCheckFailure kind;
  final String message;

  @override
  String toString() => message;
}

/// Only concurrent checks share a request. A later manual check queries again.
class UpdateService {
  UpdateService({Dio? dio, this.timeout = const Duration(seconds: 12)})
      : _dio = dio ?? Dio();

  static const owner = 'fantruekly';
  static const repo = 'Libiko--ACGNhub';
  static const releasesUrl = 'https://github.com/$owner/$repo/releases';

  final Dio _dio;
  final Duration timeout;
  final _pending = <String, Future<UpdateInfo?>>{};

  Future<UpdateInfo?> check(String currentVersion) =>
      _pending.putIfAbsent(currentVersion, () async {
        try {
          return await _check(currentVersion);
        } finally {
          _pending.remove(currentVersion);
        }
      });

  Future<UpdateInfo?> _check(String currentVersion) async {
    if (_Version.parse(currentVersion) == null) {
      throw const UpdateCheckException(
          UpdateCheckFailure.invalidResponse, '当前版本信息无效，请到发布页检查更新');
    }
    final cancel = CancelToken();
    try {
      final response = await _dio
          .get<dynamic>(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
        cancelToken: cancel,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      )
          .timeout(timeout, onTimeout: () {
        cancel.cancel('Update check deadline exceeded');
        throw const UpdateCheckException(
            UpdateCheckFailure.timeout, '检查更新超时，请稍后重试');
      });
      if (response.statusCode == 404) return null;
      if ((response.statusCode ?? 0) >= 400) {
        throw _httpError(response.statusCode);
      }
      final data = response.data;
      if (data is! Map ||
          data['tag_name'] is! String ||
          (data['draft'] != null && data['draft'] is! bool) ||
          (data['prerelease'] != null && data['prerelease'] is! bool)) {
        throw const FormatException('Invalid release');
      }
      if (data['draft'] == true || data['prerelease'] == true) return null;
      final tag = (data['tag_name'] as String).trim();
      final latest = _Version.parse(tag);
      if (latest == null) throw const FormatException('Invalid release tag');
      // Even if its flag is incorrect, an RC is not a stable update.
      if (latest.preRelease.isNotEmpty) return null;
      if (!isNewerVersion(currentVersion, tag)) return null;
      final rawUrl = data['html_url'];
      final uri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
      final validUrl = uri != null &&
          const ['https', 'http'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty;
      return UpdateInfo(
        version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
        notes: data['body'] is String ? (data['body'] as String).trim() : '',
        url: validUrl
            ? uri.toString()
            : '$releasesUrl/tag/${Uri.encodeComponent(tag)}',
        publishedAt: data['published_at'] is String
            ? DateTime.tryParse(data['published_at'] as String)
            : null,
      );
    } on UpdateCheckException {
      rethrow;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      if (error.response?.statusCode != null) {
        throw _httpError(error.response!.statusCode);
      }
      if (const [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout
      ].contains(error.type)) {
        throw const UpdateCheckException(
            UpdateCheckFailure.timeout, '检查更新超时，请稍后重试');
      }
      if (error.error is FormatException) {
        throw const UpdateCheckException(
            UpdateCheckFailure.invalidResponse, '更新信息格式异常，请稍后重试');
      }
      throw const UpdateCheckException(
          UpdateCheckFailure.network, '无法连接更新服务，请检查网络后重试');
    } on FormatException {
      throw const UpdateCheckException(
          UpdateCheckFailure.invalidResponse, '更新信息格式异常，请稍后重试');
    }
  }

  static UpdateCheckException _httpError(int? status) {
    if (status == 403 || status == 429) {
      return const UpdateCheckException(
          UpdateCheckFailure.rateLimited, '更新服务访问受限，请稍后重试或前往发布页');
    }
    return const UpdateCheckException(
        UpdateCheckFailure.server, '更新服务暂时不可用，请稍后重试');
  }

  /// SemVer precedence, ignoring build metadata. Short numeric versions such as
  /// `1` and `1.2` remain accepted for older release tags.
  static bool isNewerVersion(String current, String latest) {
    final a = _Version.parse(current);
    final b = _Version.parse(latest);
    return a != null && b != null && b.compareTo(a) > 0;
  }
}

class _Version implements Comparable<_Version> {
  const _Version(this.core, this.preRelease);
  final List<int> core;
  final List<String> preRelease;
  static final _pattern = RegExp(
      r'^[vV]?(0|[1-9]\d*)(?:\.(0|[1-9]\d*))?(?:\.(0|[1-9]\d*))?(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$');
  static final _numeric = RegExp(r'^\d+$');

  static _Version? parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) return null;
    final core = <int>[];
    for (var i = 1; i <= 3; i++) {
      final number = int.tryParse(match.group(i) ?? '0');
      if (number == null) return null;
      core.add(number);
    }
    final preRelease = match.group(4)?.split('.') ?? <String>[];
    if (preRelease.any((part) =>
        _numeric.hasMatch(part) && part.length > 1 && part.startsWith('0'))) {
      return null;
    }
    return _Version(core, preRelease);
  }

  @override
  int compareTo(_Version other) {
    for (var i = 0; i < 3; i++) {
      final comparison = core[i].compareTo(other.core[i]);
      if (comparison != 0) return comparison;
    }
    if (preRelease.isEmpty || other.preRelease.isEmpty) {
      return preRelease.isEmpty ? (other.preRelease.isEmpty ? 0 : 1) : -1;
    }
    for (var i = 0; i < preRelease.length && i < other.preRelease.length; i++) {
      final a = preRelease[i];
      final b = other.preRelease[i];
      if (a == b) continue;
      final aNumeric = _numeric.hasMatch(a);
      final bNumeric = _numeric.hasMatch(b);
      if (aNumeric && bNumeric) {
        final length = a.length.compareTo(b.length);
        return length != 0 ? length : a.compareTo(b);
      }
      if (aNumeric != bNumeric) return aNumeric ? -1 : 1;
      return a.compareTo(b);
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }
}
