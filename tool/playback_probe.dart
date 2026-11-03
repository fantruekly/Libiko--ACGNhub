// Run with tool/test_playback_sources.ps1. This is a separate diagnostic app;
// it deliberately does not initialize the app database, account or providers.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:crypto/crypto.dart';

import 'package:libiko/core/video/browser_pool.dart';
import 'package:libiko/core/video/cancellation.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/playback_session.dart';
import 'package:libiko/core/video/resolved_stream_cache.dart';
import 'package:libiko/core/video/rule_source.dart';
import 'package:libiko/core/video/source_cache.dart';
import 'package:libiko/core/video/source_rule.dart';
import 'package:libiko/core/video/stream_resolver.dart';
import 'package:libiko/core/video/video_source.dart';
import 'package:libiko/core/video/windows_webview_runtime.dart';

import 'playback_probe_report.dart';

const _reportDirectory = String.fromEnvironment('PLAYBACK_AUDIT_DIR',
    defaultValue: 'dist/playback-audit');
const _keywords = String.fromEnvironment('PLAYBACK_AUDIT_KEYWORDS',
    defaultValue: '鬼灭,葬送的芙莉莲');
const _sourceFilter = String.fromEnvironment('PLAYBACK_AUDIT_SOURCES');
const _configuredSeconds =
    int.fromEnvironment('PLAYBACK_AUDIT_SECONDS', defaultValue: 10);
const _testSeek = bool.fromEnvironment('PLAYBACK_AUDIT_SEEK');
const _maxLines = int.fromEnvironment('PLAYBACK_AUDIT_LINES', defaultValue: 3);
final _observeSeconds = _configuredSeconds.clamp(10, 60);
final _video = ValueNotifier<VideoController?>(null);
final _ruleMetadata = <String, Map<String, dynamic>>{};
final _report = <String, dynamic>{
  'schema': 1,
  'startedAt': DateTime.now().toUtc().toIso8601String(),
  'status': 'running',
  'platform': Platform.operatingSystem,
  'observeSeconds': _observeSeconds,
  'seekRequested': _testSeek,
  'samples': <Map<String, dynamic>>[],
};

void _log(String text) {
  final safe = redactProbeText(text);
  debugPrint('[Playback audit] $safe');
  final dir = Directory(_reportDirectory)..createSync(recursive: true);
  File('${dir.path}/progress.log')
      .writeAsStringSync('$safe\n', mode: FileMode.append);
}

void _save() {
  _report['windowsRuntimeRecoveries'] = WindowsWebViewRuntime.recoveries;
  final dir = Directory(_reportDirectory)..createSync(recursive: true);
  File('${dir.path}/report.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_report));
  File('${dir.path}/report.md')
      .writeAsStringSync(playbackAuditMarkdown(_report));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  runApp(MaterialApp(
      home: Scaffold(
          backgroundColor: Colors.black,
          body: ValueListenableBuilder<VideoController?>(
              valueListenable: _video,
              builder: (_, controller, __) => controller == null
                  ? const Center(child: Text('正在检查动漫播放源'))
                  : Video(controller: controller, controls: null)))));
  await Future<void>.delayed(const Duration(milliseconds: 150));
  await windowManager.hide();
  _save();
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest.listAssets().where((path) =>
        path.startsWith('assets/source_rules/') && path.endsWith('.json'));
    final names =
        _sourceFilter.split(',').where((name) => name.isNotEmpty).toSet();
    final rules = <SourceRule>[];
    for (final path in paths) {
      final raw = await rootBundle.loadString(path);
      final rule = SourceRule.fromJsonString(raw);
      _ruleMetadata[rule.id] = {
        'version': (jsonDecode(raw) as Map)['version']?.toString(),
        'sha256': sha256.convert(utf8.encode(raw)).toString(),
      };
      if (names.isEmpty || names.contains(rule.name)) rules.add(rule);
    }
    rules.sort((a, b) => a.name.compareTo(b.name));
    if (rules.isEmpty) throw StateError('No matching bundled source');
    final keywords = _keywords.split(',').where((value) => value.isNotEmpty);
    _report['expectedSamples'] = rules.length * keywords.length;
    _save();
    for (final rule in rules) {
      for (final keyword in keywords) {
        final row = await _sample(rule, keyword);
        (_report['samples'] as List).add(row);
        _save();
        _log(
            '${rule.name} / $keyword: ${row['status']} (${row['failureStage'] ?? 'complete'})');
      }
    }
    _report['status'] = 'completed';
  } catch (error) {
    _report['status'] = 'failed';
    _report['fatalType'] = error.runtimeType.toString();
    _log('Audit failed: ${error.runtimeType}');
  } finally {
    _report['finishedAt'] = DateTime.now().toUtc().toIso8601String();
    _save();
    _video.value = null;
    await sharedBrowserPool
        .shutdown()
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    _log(
        'Finished; report saved. Restore the normal app build before distribution.');
  }
  exit(_report['status'] == 'completed' ? 0 : 1);
}

Future<Map<String, dynamic>> _sample(SourceRule rule, String keyword) async {
  final row = <String, dynamic>{
    'source': rule.name,
    'sourceId': rule.id,
    'rule': _ruleMetadata[rule.id],
    'keyword': keyword,
    'status': 'failed',
    'attempts': <Map<String, dynamic>>[],
  };
  final cancel = CancellationToken();
  final source = RuleVideoSource(rule, cache: SourceCache());
  final clock = Stopwatch();
  var stage = 'search';
  try {
    _log('${rule.name} / $keyword: search');
    clock.start();
    final items = await source
        .search(keyword, cancel: cancel)
        .timeout(const Duration(seconds: 32));
    row['searchMs'] = clock.elapsedMilliseconds;
    row['searchResults'] = items.length;
    if (items.isEmpty) {
      row['status'] = 'no_search_result';
      row['failureStage'] = stage;
      return row;
    }
    final item = items[
        selectProbeTitle(keyword, [for (final item in items) item.title])];
    row['title'] = item.title;
    stage = 'episodes';
    _log('${rule.name} / $keyword: episodes');
    clock.reset();
    final episodes = await source
        .episodes(item.detailUrl, cancel: cancel)
        .timeout(const Duration(seconds: 32));
    row['episodesMs'] = clock.elapsedMilliseconds;
    row['episodeCount'] = episodes.length;
    if (episodes.isEmpty) {
      row['status'] = 'no_episodes';
      row['failureStage'] = stage;
      return row;
    }
    final selected = <VideoEpisode>[];
    final lines = <String?>{};
    for (final episode in episodes) {
      if (episode.episodeKey == episodes.first.episodeKey &&
          lines.add(episode.lineId)) {
        selected.add(episode);
      }
    }
    row['episode'] = episodes.first.title;
    final lineResults = <Map<String, dynamic>>[];
    row['lineResults'] = lineResults;
    final passedLines = <String>[];
    for (final episode in selected.take(_maxLines.clamp(1, 5))) {
      final line = <String, dynamic>{
        'line': episode.lineName,
        'lineId': episode.lineId,
        'episode': episode.title
      };
      lineResults.add(line);
      final lineCancel = CancellationToken();
      cancel.addListener(lineCancel.cancel);
      try {
        stage = 'resolve';
        _log('${rule.name} / $keyword / ${episode.lineName}: resolve');
        clock.reset();
        final result = await StreamResolver(cache: ResolvedStreamCache())
            .resolve(episode.playUrl,
                userAgent: episode.userAgent,
                referer: episode.referer,
                legacy: episode.useLegacyParser,
                cancel: lineCancel)
            .timeout(const Duration(seconds: 35), onTimeout: () {
          lineCancel.cancel();
          throw TimeoutException('Line resolve deadline');
        });
        line.addAll({
          'resolveMs': clock.elapsedMilliseconds,
          'candidateCount': result.candidates.length,
          'resolverVerified': result.verified
        });
        if (!result.ok) {
          line.addAll({
            'status': 'resolve_failed',
            'resolveFailure': result.failure?.name
          });
          continue;
        }
        stage = 'playback';
        line['status'] = 'playback_failed';
        for (final candidate in result.candidates.take(2)) {
          _log('${rule.name} / $keyword / ${episode.lineName}: native video');
          final attempt = await _play(candidate, episode);
          attempt['line'] = episode.lineName;
          attempt['lineId'] = episode.lineId;
          (row['attempts'] as List).add(attempt);
          if (attempt['status'] == 'passed') {
            line['status'] = 'passed';
            passedLines.add(episode.lineName ?? episode.lineId ?? '默认线路');
            break;
          }
        }
      } catch (error) {
        line.addAll({
          'status': 'request_failed',
          'failureStage': stage,
          'errorType': error.runtimeType.toString()
        });
      } finally {
        cancel.removeListener(lineCancel.cancel);
        lineCancel.cancel();
      }
    }
    row['line'] = (passedLines.isNotEmpty
            ? passedLines
            : selected.map((e) => e.lineName ?? '默认线路'))
        .join('、');
    final attemptedPlayback = (row['attempts'] as List).isNotEmpty;
    row['status'] = passedLines.isNotEmpty
        ? 'passed'
        : attemptedPlayback
            ? 'playback_failed'
            : 'resolve_failed';
    if (passedLines.isEmpty) {
      row['failureStage'] = attemptedPlayback ? 'playback' : 'resolve';
    }
  } catch (error) {
    row['failureStage'] = stage;
    row['errorType'] = error.runtimeType.toString();
    if (error is PlatformException) {
      row['platformCode'] = redactProbeText(error.code);
      final message = redactProbeText(error.message ?? '');
      row['platformMessage'] =
          message.length > 200 ? message.substring(0, 200) : message;
    }
    row['status'] = error is TimeoutException ? 'timed_out' : 'request_failed';
  } finally {
    cancel.cancel();
  }
  return row;
}

Future<Map<String, dynamic>> _play(
    MediaCandidate candidate, VideoEpisode episode) async {
  final evidence = <String, dynamic>{
    'mediaHost': Uri.tryParse(candidate.url)?.host,
    'status': 'failed',
    'firstFrameRendered': false,
  };
  final player = Player();
  final controller = VideoController(player);
  final clock = Stopwatch()..start();
  var observation = PlaybackObservation(requiredSeconds: _observeSeconds);
  var errorCount = 0;
  final failed = Completer<void>();
  final subscriptions = <StreamSubscription<dynamic>>[
    player.stream.position
        .listen((position) => observation.record(position, clock.elapsed)),
    player.stream.error.listen((_) {
      errorCount++;
      if (!failed.isCompleted) failed.complete();
    }),
  ];
  _video.value = controller;
  try {
    await player.setVolume(0);
    final native = player.platform;
    if (native is NativePlayer) {
      await native.setProperty('network-timeout', '15');
    }
    await player
        .open(Media(candidate.url,
            httpHeaders: playbackHeaders(candidate, episode)))
        .timeout(const Duration(seconds: 15));
    var frameReady = false;
    await Future.any<void>([
      controller.waitUntilFirstFrameRendered.then((_) => frameReady = true),
      failed.future,
    ]).timeout(const Duration(seconds: 30));
    evidence['firstFrameRendered'] = frameReady;
    evidence['firstFrameMs'] = clock.elapsedMilliseconds;
    if (!frameReady || errorCount > 0) {
      evidence['status'] = 'native_error';
      return evidence;
    }
    observation = PlaybackObservation(requiredSeconds: _observeSeconds);
    observation.record(player.state.position, clock.elapsed);
    final until = clock.elapsed + Duration(seconds: _observeSeconds + 5);
    while (clock.elapsed < until &&
        errorCount == 0 &&
        !observation.stableAt(clock.elapsed)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final video = player.state.videoParams;
    evidence['videoWidth'] = video.w;
    evidence['videoHeight'] = video.h;
    evidence.addAll(observation.toJson(clock.elapsed));
    final validVideo = (video.w ?? 0) > 0 && (video.h ?? 0) > 0;
    if (errorCount > 0) {
      evidence['status'] = 'native_error';
    } else if (!validVideo || !observation.stableAt(clock.elapsed)) {
      evidence['status'] = 'unstable_or_no_video';
    } else {
      evidence['status'] = 'passed';
      evidence['observationErrorEvents'] = errorCount;
      try {
        final bytes =
            await player.screenshot().timeout(const Duration(seconds: 4));
        evidence['decodedFrameBytes'] = bytes?.length ?? 0;
      } catch (_) {
        evidence['decodedFrameBytes'] = 0;
      }
      if (_testSeek && player.state.duration > const Duration(seconds: 45)) {
        try {
          final target = player.state.position + const Duration(seconds: 15);
          await player.seek(target).timeout(const Duration(seconds: 5));
          final limit = clock.elapsed + const Duration(seconds: 10);
          while (clock.elapsed < limit &&
              errorCount == 0 &&
              player.state.position <
                  target + const Duration(milliseconds: 500)) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
          evidence['seekPassed'] = errorCount == 0 &&
              player.state.position >=
                  target + const Duration(milliseconds: 500);
          evidence['seekStatus'] =
              evidence['seekPassed'] == true ? 'passed' : 'failed';
        } catch (error) {
          evidence['seekPassed'] = false;
          evidence['seekStatus'] =
              error is TimeoutException ? 'timed_out' : 'failed';
          evidence['seekErrorType'] = error.runtimeType.toString();
        }
      }
    }
  } catch (error) {
    evidence['status'] =
        error is TimeoutException ? 'playback_timeout' : 'native_exception';
    evidence['errorType'] = error.runtimeType.toString();
  } finally {
    evidence['errorEvents'] = errorCount;
    evidence['elapsedMs'] = clock.elapsedMilliseconds;
    _video.value = null;
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await player
        .dispose()
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }
  return evidence;
}
