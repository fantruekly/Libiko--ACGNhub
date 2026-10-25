import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../storage/database.dart';
import 'update_service.dart';

enum UpdateCheckResult { available, upToDate, failed, skipped }

/// Shared by startup and Settings so checks and preferences stay consistent.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required this.service,
    required Future<String> Function() loadVersion,
    required String? Function() read,
    required Future<void> Function(String) write,
    DateTime Function()? clock,
  })  : _loadVersion = loadVersion,
        _write = write,
        _clock = clock ?? DateTime.now {
    try {
      final value = jsonDecode(read() ?? '{}') as Map<String, dynamic>;
      automatic = value['automatic'] != false;
      skippedVersion = value['skippedVersion'] as String?;
      lastChecked = DateTime.tryParse(value['lastChecked']?.toString() ?? '');
      _lastAttempt = DateTime.tryParse(value['lastAttempt']?.toString() ?? '');
      _lastFailed = value['lastFailed'] == true;
    } catch (_) {
      // Corrupt preferences must not prevent checking for updates.
    }
  }

  final UpdateService service;
  final Future<String> Function() _loadVersion;
  final Future<void> Function(String) _write;
  final DateTime Function() _clock;
  bool automatic = true;
  String? skippedVersion;
  DateTime? lastChecked;
  DateTime? _lastAttempt;
  bool _lastFailed = false;
  String? currentVersion;
  UpdateInfo? update;
  String? error;
  bool checking = false;
  bool _disposed = false;
  Future<void>? _pending;
  Future<void> _saving = Future.value();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _save() {
    final text = jsonEncode({
      'automatic': automatic,
      'skippedVersion': skippedVersion,
      'lastChecked': lastChecked?.toUtc().toIso8601String(),
      'lastAttempt': _lastAttempt?.toUtc().toIso8601String(),
      'lastFailed': _lastFailed,
    });
    final next = _saving.then((_) => _write(text));
    _saving = next.catchError((Object _) {});
    return next;
  }

  Future<void> setAutomatic(bool value) async {
    final old = automatic;
    automatic = value;
    try {
      await _save();
    } catch (_) {
      automatic = old;
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<void> skipVersion(String version) async {
    final old = skippedVersion;
    skippedVersion = version;
    try {
      await _save();
    } catch (_) {
      skippedVersion = old;
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<UpdateCheckResult> check({bool manual = false}) async {
    if (_pending == null) {
      final elapsed =
          _lastAttempt == null ? null : _clock().difference(_lastAttempt!);
      final cooldown =
          _lastFailed ? const Duration(minutes: 30) : const Duration(hours: 12);
      if (!manual &&
          (!automatic ||
              (elapsed != null && !elapsed.isNegative && elapsed < cooldown))) {
        return UpdateCheckResult.skipped;
      }
      _pending = _perform();
    }
    try {
      await _pending;
    } finally {
      _pending = null;
    }
    if (error != null) return UpdateCheckResult.failed;
    if (update == null) return UpdateCheckResult.upToDate;
    if (!manual && skippedVersion == update!.version) {
      return UpdateCheckResult.skipped;
    }
    return UpdateCheckResult.available;
  }

  Future<void> _perform() async {
    checking = true;
    error = null;
    _notify();
    _lastAttempt = _clock();
    try {
      currentVersion = await _loadVersion().timeout(const Duration(seconds: 5));
      update = await service.check(currentVersion!);
      lastChecked = _clock();
      _lastFailed = false;
    } catch (failure) {
      _lastFailed = true;
      error =
          failure is UpdateCheckException ? failure.message : '暂时无法检查更新，请稍后重试';
    } finally {
      try {
        await _save();
      } catch (_) {
        // A preference write failure must not hide a valid release response.
      }
      checking = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
final updateControllerProvider =
    ChangeNotifierProvider<UpdateController>((ref) {
  const key = 'updates.preferences.v1';
  return UpdateController(
    service: ref.watch(updateServiceProvider),
    loadVersion: () async => (await PackageInfo.fromPlatform()).version,
    read: () => AppDatabase().getString(key),
    write: (value) async {
      if (!await AppDatabase().setString(key, value)) {
        throw StateError('无法保存更新设置');
      }
    },
  );
});
