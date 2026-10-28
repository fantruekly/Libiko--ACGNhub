import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/services/update_service.dart';

void main() {
  test('isNewerVersion compares semver', () {
    expect(UpdateService.isNewerVersion('1.0.0', '1.0.1'), isTrue);
    expect(UpdateService.isNewerVersion('1.0.0', '1.1.0'), isTrue);
    expect(UpdateService.isNewerVersion('1.0.0', '2.0.0'), isTrue);
    expect(UpdateService.isNewerVersion('1.0.0', 'v1.0.1'), isTrue);
    expect(UpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
    expect(UpdateService.isNewerVersion('1.2.0', '1.1.9'), isFalse);
    expect(UpdateService.isNewerVersion('1.0.0', 'abc'), isFalse);
  });

  test('check returns an UpdateInfo for a newer release', () async {
    final dio = Dio()
      ..httpClientAdapter = _JsonAdapter({
        'tag_name': 'v0.2.0',
        'body': '更新说明',
        'html_url': 'https://example.com/release',
      });
    final info = await UpdateService(dio: dio).check('0.1.0');
    expect(info?.version, '0.2.0');
    expect(info?.notes, '更新说明');
    expect(info?.url, 'https://example.com/release');
  });

  test('check returns null when already latest', () async {
    final dio = Dio()..httpClientAdapter = _JsonAdapter({'tag_name': 'v0.1.0'});
    expect(await UpdateService(dio: dio).check('0.1.0'), isNull);
  });

  test('installed release and newer local builds do not prompt again',
      () async {
    final dio = Dio()..httpClientAdapter = _JsonAdapter({'tag_name': 'v0.1.2'});
    final service = UpdateService(dio: dio);
    for (final installed in ['0.1.2', '0.1.2+3', '0.1.3']) {
      expect(await service.check(installed), isNull, reason: installed);
    }
    expect((await service.check('0.1.1'))?.version, '0.1.2');
  });

  test('semver handles prerelease ordering, build metadata and short tags', () {
    const versions = [
      '1.0.0-alpha',
      '1.0.0-alpha.1',
      '1.0.0-alpha.beta',
      '1.0.0-beta',
      '1.0.0-beta.2',
      '1.0.0-beta.11',
      '1.0.0-rc.1',
      '1.0.0'
    ];
    for (var i = 1; i < versions.length; i++) {
      expect(
          UpdateService.isNewerVersion(versions[i - 1], versions[i]), isTrue);
      expect(
          UpdateService.isNewerVersion(versions[i], versions[i - 1]), isFalse);
    }
    expect(UpdateService.isNewerVersion('1.0.0+1', '1.0.0+2'), isFalse);
    expect(UpdateService.isNewerVersion('1', 'V1.2'), isTrue);
    expect(UpdateService.isNewerVersion('v1.2', '1.2.0'), isFalse);
  });

  test('semver rejects malformed suffixes and leading zero identifiers', () {
    for (final value in [
      '1.0.1garbage',
      '1.0.1.2',
      '01.0.1',
      '1.0.1-01',
      '1.0.1-',
      '1.0.1+',
      '1.0.1+build..x',
      'release-1.0.1'
    ]) {
      expect(UpdateService.isNewerVersion('1.0.0', value), isFalse,
          reason: value);
      expect(UpdateService.isNewerVersion(value, '2.0.0'), isFalse,
          reason: value);
    }
  });

  test('filters draft, prerelease and mislabeled prerelease versions',
      () async {
    for (final data in [
      {'tag_name': 'v2.0.0', 'draft': true},
      {'tag_name': 'v2.0.0', 'prerelease': true},
      {'tag_name': 'v2.0.0-rc.1', 'prerelease': false}
    ]) {
      final dio = Dio()..httpClientAdapter = _JsonAdapter(data);
      expect(await UpdateService(dio: dio).check('1.0.0'), isNull);
    }
  });

  test('stable release upgrades an installed prerelease', () async {
    final dio = Dio()..httpClientAdapter = _JsonAdapter({'tag_name': 'v1.0.0'});
    expect(
        (await UpdateService(dio: dio).check('1.0.0-rc.1'))?.version, '1.0.0');
  });

  test('missing release returns null rather than a failed check', () async {
    final dio = Dio()..httpClientAdapter = _JsonAdapter({}, status: 404);
    expect(await UpdateService(dio: dio).check('1.0.0'), isNull);
  });

  test('invalid URLs use the official tagged release and date is retained',
      () async {
    for (final url in ['', 'javascript:alert(1)', '//other.test/path']) {
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter({
          'tag_name': 'v2.0.0',
          'html_url': url,
          'published_at': '2026-10-25T01:00:00Z',
        });
      final update = await UpdateService(dio: dio).check('1.0.0');
      expect(update?.url, '${UpdateService.releasesUrl}/tag/v2.0.0');
      expect(update?.publishedAt, DateTime.utc(2026, 10, 25, 1));
    }
  });

  test('bad release data is not mistaken for already latest', () async {
    for (final data in [
      null,
      [],
      {},
      {'tag_name': 'v2.0.1oops'}
    ]) {
      final dio = Dio()..httpClientAdapter = _JsonAdapter(data);
      await expectLater(UpdateService(dio: dio).check('1.0.0'),
          throwsA(_failure(UpdateCheckFailure.invalidResponse)));
    }
  });

  test('classifies rate limiting, service failure and network errors',
      () async {
    for (final status in [403, 429, 500]) {
      final dio = Dio()..httpClientAdapter = _JsonAdapter({}, status: status);
      await expectLater(
          UpdateService(dio: dio).check('1.0.0'),
          throwsA(_failure(status == 500
              ? UpdateCheckFailure.server
              : UpdateCheckFailure.rateLimited)));
    }
    final dio = Dio()
      ..httpClientAdapter =
          _JsonAdapter(null, failure: DioExceptionType.connectionError);
    await expectLater(UpdateService(dio: dio).check('1.0.0'),
        throwsA(_failure(UpdateCheckFailure.network)));
  });

  test('deadline covers a hanging injected adapter and cancels the request',
      () async {
    final adapter = _JsonAdapter(null, hang: true);
    final dio = Dio()..httpClientAdapter = adapter;
    await expectLater(
        UpdateService(dio: dio, timeout: const Duration(milliseconds: 30))
            .check('1.0.0'),
        throwsA(_failure(UpdateCheckFailure.timeout)));
    await Future<void>.delayed(Duration.zero);
    expect(adapter.cancelled, isTrue);
  });

  test('concurrent checks share a request but later manual checks are fresh',
      () async {
    final gate = Completer<void>();
    final adapter = _JsonAdapter({'tag_name': 'v2.0.0'}, gate: gate.future);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = UpdateService(dio: dio);
    final a = service.check('1.0.0');
    final b = service.check('1.0.0');
    expect(identical(a, b), isTrue);
    gate.complete();
    expect((await a)?.version, '2.0.0');
    await b;
    expect(adapter.requests, 1);
    await service.check('1.0.0');
    expect(adapter.requests, 2);
  });

  test('failed checks are cleared so the next attempt can succeed', () async {
    final adapter = _JsonAdapter({'tag_name': 'v2.0.0'}, status: 500);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = UpdateService(dio: dio);
    await expectLater(
        service.check('1.0.0'), throwsA(_failure(UpdateCheckFailure.server)));
    adapter.status = 200;
    expect((await service.check('1.0.0'))?.version, '2.0.0');
    expect(adapter.requests, 2);
  });
}

Matcher _failure(UpdateCheckFailure failure) =>
    isA<UpdateCheckException>().having((error) => error.kind, 'kind', failure);

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.json,
      {this.status = 200, this.gate, this.hang = false, this.failure});
  final Object? json;
  int status;
  final Future<void>? gate;
  final bool hang;
  final DioExceptionType? failure;
  int requests = 0;
  bool cancelled = false;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests++;
    cancelFuture?.then((_) => cancelled = true);
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    if (hang) return Completer<ResponseBody>().future;
    if (gate != null) await gate;
    return ResponseBody.fromString(
      const JsonEncoder().convert(json),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
