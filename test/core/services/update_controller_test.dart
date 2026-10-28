import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/services/update_controller.dart';
import 'package:libiko/core/services/update_service.dart';

const _release = UpdateInfo(
    version: '2.0.0', notes: '更新内容', url: 'https://github.com/release');

class _Service extends UpdateService {
  int calls = 0;
  Future<UpdateInfo?> Function() response = () async => _release;
  @override
  Future<UpdateInfo?> check(String currentVersion) {
    calls++;
    return response();
  }
}

void main() {
  late _Service service;
  late DateTime now;
  String? stored;
  late UpdateController controller;
  UpdateController create() => UpdateController(
      service: service,
      loadVersion: () async => '1.0.0',
      read: () => stored,
      write: (value) async => stored = value,
      clock: () => now);

  setUp(() {
    service = _Service();
    now = DateTime(2026, 10, 25, 12);
    stored = null;
    controller = create();
  });
  tearDown(() => controller.dispose());

  test('automatic checks throttle across restarts but manual checks bypass',
      () async {
    expect(await controller.check(), UpdateCheckResult.available);
    expect(await controller.check(), UpdateCheckResult.skipped);
    controller.dispose();
    controller = create();
    expect(await controller.check(), UpdateCheckResult.skipped);
    expect(await controller.check(manual: true), UpdateCheckResult.available);
    expect(service.calls, 2);
    now = now.add(const Duration(hours: 12));
    expect(await controller.check(), UpdateCheckResult.available);
  });

  test(
      'disabled and skipped preferences persist without blocking manual checks',
      () async {
    await controller.setAutomatic(false);
    await controller.skipVersion('2.0.0');
    controller.dispose();
    controller = create();
    expect(controller.automatic, isFalse);
    expect(controller.skippedVersion, '2.0.0');
    expect(await controller.check(), UpdateCheckResult.skipped);
    expect(service.calls, 0);
    expect(await controller.check(manual: true), UpdateCheckResult.available);
    await controller.setAutomatic(true);
    now = now.add(const Duration(hours: 12));
    expect(await controller.check(), UpdateCheckResult.skipped);
    expect(service.calls, 2);
    service.response = () async => const UpdateInfo(
        version: '2.1.0', notes: '', url: 'https://github.com/release');
    now = now.add(const Duration(hours: 12));
    expect(await controller.check(), UpdateCheckResult.available);
  });

  test(
      'concurrent startup and manual checks share work and release loading state',
      () async {
    final completer = Completer<UpdateInfo?>();
    service.response = () => completer.future;
    final startup = controller.check();
    final manual = controller.check(manual: true);
    await Future<void>.delayed(Duration.zero);
    expect(controller.checking, isTrue);
    expect(service.calls, 1);
    completer.complete(_release);
    expect(await startup, UpdateCheckResult.available);
    expect(await manual, UpdateCheckResult.available);
    expect(controller.checking, isFalse);
    expect(controller.lastChecked, now);
  });

  test(
      'failed automatic checks retry after 30 minutes and preserve last success',
      () async {
    await controller.check();
    final success = controller.lastChecked;
    service.response = () async => throw StateError('offline');
    expect(await controller.check(manual: true), UpdateCheckResult.failed);
    expect(controller.lastChecked, success);
    expect(controller.error, isNotNull);
    expect(controller.update, isNull);
    now = now.add(const Duration(minutes: 29));
    expect(await controller.check(), UpdateCheckResult.skipped);
    now = now.add(const Duration(minutes: 1));
    service.response = () async => null;
    expect(await controller.check(), UpdateCheckResult.upToDate);
    expect(controller.error, isNull);
    expect(controller.update, isNull);
  });

  test('preference save failures roll back user choices', () async {
    controller.dispose();
    controller = UpdateController(
        service: service,
        loadVersion: () async => '1.0.0',
        read: () => null,
        write: (_) async => throw StateError('disk full'));
    await expectLater(controller.setAutomatic(false), throwsStateError);
    expect(controller.automatic, isTrue);
    await expectLater(controller.skipVersion('2.0.0'), throwsStateError);
    expect(controller.skippedVersion, isNull);
    expect(await controller.check(manual: true), UpdateCheckResult.available);
  });

  test('saved preferences contain no release body or URL', () async {
    await controller.check();
    final data = jsonDecode(stored!) as Map;
    expect(data.keys, isNot(contains('url')));
    expect(data.keys, isNot(contains('notes')));
  });
}
