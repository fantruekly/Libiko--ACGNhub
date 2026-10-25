import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

enum SourceKind { anime, comic, novel, game }

class SourcePreferences {
  const SourcePreferences({this.disabled = const {}, this.order = const {}});
  final Map<SourceKind, Set<String>> disabled;
  final Map<SourceKind, List<String>> order;

  bool enabled(SourceKind kind, String id) =>
      !(disabled[kind]?.contains(id) ?? false);

  List<T> apply<T>(SourceKind kind, List<T> sources, String Function(T) idOf,
      {bool includeDisabled = false}) {
    final positions = {
      for (final (i, id) in (order[kind] ?? <String>[]).indexed) id: i
    };
    final sorted = sources.indexed
        .where((item) => includeDisabled || enabled(kind, idOf(item.$2)))
        .toList();
    sorted.sort((a, b) {
      final rank = (positions[idOf(a.$2)] ?? positions.length + a.$1)
          .compareTo(positions[idOf(b.$2)] ?? positions.length + b.$1);
      return rank == 0 ? a.$1.compareTo(b.$1) : rank;
    });
    return [for (final item in sorted) item.$2];
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'disabled': {
          for (final e in disabled.entries) e.key.name: e.value.toList()
        },
        'order': {for (final e in order.entries) e.key.name: e.value},
      };

  factory SourcePreferences.fromJson(Map<String, dynamic> json) {
    Set<String> ids(dynamic value) {
      if (value is! List || value.any((id) => id is! String)) {
        throw const FormatException('源偏好必须包含字符串列表');
      }
      return value.cast<String>().where((id) => id.isNotEmpty).toSet();
    }

    Map<SourceKind, Set<String>> parse(dynamic raw) {
      if (raw == null) return {};
      if (raw is! Map) throw const FormatException('源偏好格式无效');
      return {
        for (final kind in SourceKind.values)
          if (raw[kind.name] != null) kind: ids(raw[kind.name])
      };
    }

    if (json['version'] != null && json['version'] != 1) {
      throw const FormatException('不支持的源偏好版本');
    }
    final order = parse(json['order']);
    return SourcePreferences(disabled: parse(json['disabled']), order: {
      for (final entry in order.entries) entry.key: entry.value.toList()
    });
  }
}

/// Settings remain in SharedPreferences; no credentials or health are exported.
class SourcePreferencesRepository {
  SourcePreferencesRepository(
      {String? Function(String)? read,
      Future<void> Function(String, String)? write})
      : _read = read ?? _readSetting,
        _write = write ?? _writeSetting;
  static const storageKey = 'source_preferences.v1';
  final String? Function(String) _read;
  final Future<void> Function(String, String) _write;

  static String? _readSetting(String key) {
    try {
      return AppDatabase().getString(key);
    } on StateError {
      return null;
    }
  }

  static Future<void> _writeSetting(String key, String value) async {
    if (!await AppDatabase().setString(key, value)) throw StateError('源设置保存失败');
  }

  SourcePreferences load() {
    final raw = _read(storageKey);
    if (raw == null) return const SourcePreferences();
    try {
      return SourcePreferences.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const SourcePreferences();
    }
  }

  Future<void> save(SourcePreferences preferences) =>
      _write(storageKey, jsonEncode(preferences.toJson()));
  Map<String, dynamic> exportSnapshot() => load().toJson();
  Future<void> restoreSnapshot(Map<String, dynamic> snapshot) =>
      save(SourcePreferences.fromJson(snapshot));
}

class SourcePreferencesNotifier extends StateNotifier<SourcePreferences> {
  SourcePreferencesNotifier(this.repository) : super(repository.load());
  final SourcePreferencesRepository repository;
  Future<void> _pending = Future.value();

  Future<void> _update(SourcePreferences Function(SourcePreferences) update) {
    final next = _pending.then((_) async {
      final value = update(state);
      await repository.save(value);
      state = value;
    });
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> setEnabled(SourceKind kind, String id, bool enabled) =>
      _update((state) {
        final ids = Set<String>.of(state.disabled[kind] ?? {});
        enabled ? ids.remove(id) : ids.add(id);
        return SourcePreferences(
            disabled: {...state.disabled, kind: ids}, order: state.order);
      });
  Future<void> setOrder(SourceKind kind, List<String> ids) =>
      _update((state) => SourcePreferences(
          disabled: state.disabled,
          order: {...state.order, kind: ids.toSet().toList()}));
  Future<void> move(
      SourceKind kind, List<String> visibleOrder, String id, int delta) {
    final ids = List<String>.of(visibleOrder);
    final index = ids.indexOf(id);
    if (index < 0 || index + delta < 0 || index + delta >= ids.length) {
      return Future.value();
    }
    ids.removeAt(index);
    ids.insert(index + delta, id);
    return setOrder(kind, ids);
  }

  Future<void> restoreSnapshot(Map<String, dynamic> json) {
    final restored = SourcePreferences.fromJson(json);
    return _update((_) => restored);
  }
}

final sourcePreferencesRepositoryProvider =
    Provider<SourcePreferencesRepository>(
        (ref) => SourcePreferencesRepository());
final sourcePreferencesProvider =
    StateNotifierProvider<SourcePreferencesNotifier, SourcePreferences>((ref) =>
        SourcePreferencesNotifier(
            ref.watch(sourcePreferencesRepositoryProvider)));

enum SourceFailureKind {
  timeout,
  network,
  authentication,
  parsing,
  unavailable,
  unknown
}

String sourceFailureLabel(SourceFailureKind kind) => switch (kind) {
      SourceFailureKind.timeout => '请求超时',
      SourceFailureKind.network => '网络连接失败',
      SourceFailureKind.authentication => '需要登录或访问受限',
      SourceFailureKind.parsing => '内容或规则解析失败',
      SourceFailureKind.unavailable => '源站不可用',
      SourceFailureKind.unknown => '请求失败',
    };

SourceFailureKind classifySourceFailure(Object error) {
  if (error is TimeoutException) return SourceFailureKind.timeout;
  if (error is SocketException) return SourceFailureKind.network;
  if (error is FormatException) return SourceFailureKind.parsing;
  if (error is DioException) {
    if ([
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout
    ].contains(error.type)) {
      return SourceFailureKind.timeout;
    }
    if ([401, 403].contains(error.response?.statusCode)) {
      return SourceFailureKind.authentication;
    }
    if ((error.response?.statusCode ?? 0) >= 500) {
      return SourceFailureKind.unavailable;
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.badCertificate) {
      return SourceFailureKind.network;
    }
  }
  // Browser and JS adapters often wrap the underlying transport exception.
  final text = error.toString().toLowerCase();
  if (text.contains('timeout') || text.contains('timed out')) {
    return SourceFailureKind.timeout;
  }
  if (text.contains('403') ||
      text.contains('401') ||
      text.contains('login required')) {
    return SourceFailureKind.authentication;
  }
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused')) {
    return SourceFailureKind.network;
  }
  return SourceFailureKind.unknown;
}

class SourceHealth {
  const SourceHealth({this.lastSuccess, this.lastFailure, this.failure});
  final DateTime? lastSuccess;
  final DateTime? lastFailure;
  final SourceFailureKind? failure;
  bool get mostRecentSucceeded =>
      lastSuccess != null &&
      (lastFailure == null || !lastSuccess!.isBefore(lastFailure!));
  Map<String, dynamic> toJson() => {
        'success': lastSuccess?.toIso8601String(),
        'failureAt': lastFailure?.toIso8601String(),
        'failure': failure?.name
      };
  factory SourceHealth.fromJson(Map<String, dynamic> json) => SourceHealth(
      lastSuccess: DateTime.tryParse(json['success']?.toString() ?? ''),
      lastFailure: DateTime.tryParse(json['failureAt']?.toString() ?? ''),
      failure: SourceFailureKind.values
          .where((k) => k.name == json['failure'])
          .firstOrNull);
}

/// Observes actual source calls; no probes and no failure exception text stored.
class SourceHealthRepository extends ChangeNotifier {
  SourceHealthRepository(
      {String? Function(String)? read,
      Future<void> Function(String, String)? write,
      DateTime Function()? clock})
      : _read = read ?? SourcePreferencesRepository._readSetting,
        _write = write ?? SourcePreferencesRepository._writeSetting,
        _clock = clock ?? DateTime.now;
  final String? Function(String) _read;
  final Future<void> Function(String, String) _write;
  final DateTime Function() _clock;
  final Map<String, SourceHealth> _health = {};
  Future<void> _pending = Future.value();
  bool _disposed = false;
  String _key(SourceKind kind, String id) =>
      'source_health.v1.${kind.name}.$id';
  SourceHealth health(SourceKind kind, String id) =>
      _health.putIfAbsent(_key(kind, id), () {
        try {
          final raw = _read(_key(kind, id));
          return raw == null
              ? const SourceHealth()
              : SourceHealth.fromJson(
                  Map<String, dynamic>.from(jsonDecode(raw) as Map));
        } catch (_) {
          return const SourceHealth();
        }
      });
  void _record(SourceKind kind, String id, {Object? error}) {
    if (_disposed) return;
    final old = health(kind, id);
    final value = SourceHealth(
        lastSuccess: error == null ? _clock() : old.lastSuccess,
        lastFailure: error != null ? _clock() : old.lastFailure,
        failure: error != null ? classifySourceFailure(error) : old.failure);
    final key = _key(kind, id);
    _health[key] = value;
    notifyListeners();
    _pending = _pending
        .then((_) => _write(key, jsonEncode(value.toJson())))
        .catchError((Object _) {});
  }

  Future<T> track<T>(SourceKind kind, String id, Future<T> Function() request,
      {bool Function()? cancelled}) async {
    try {
      final result = await request();
      if (cancelled?.call() != true) _record(kind, id);
      return result;
    } catch (error) {
      if (cancelled?.call() != true &&
          !(error is DioException && error.type == DioExceptionType.cancel)) {
        _record(kind, id, error: error);
      }
      rethrow;
    }
  }

  Future<void> flush() => _pending;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final sourceHealthProvider = ChangeNotifierProvider<SourceHealthRepository>(
    (ref) => SourceHealthRepository());
