import 'dart:async';

import '../sources/managed_sources.dart';
import 'cancellation.dart';
import 'rule_source.dart';
import 'video_source.dart';

/// API searches do not occupy a WebView and must not queue behind page loads.
bool usesApiSearch(VideoSource source) {
  if (source is ManagedVideoSource) return usesApiSearch(source.source);
  return source is RuleVideoSource && source.rule.searchMode == 'api';
}

/// Each alias gets its own bounded attempt, including room for the scraper's
/// separate queue and request deadlines. Cancellation retires the real request,
/// not just the Future observed by the caller.
class SourceSearch {
  const SourceSearch({this.attemptTimeout = const Duration(seconds: 30)});

  final Duration attemptTimeout;

  Future<List<VideoItem>> run(
    VideoSource source,
    Iterable<String> queries, {
    required CancellationToken cancel,
    required bool Function(List<VideoItem>) matches,
    void Function(List<VideoItem>)? onResults,
  }) async {
    final items = <VideoItem>[];
    final seen = <String>{};
    // Alternate titles help after a successful response without a match.
    // Do not repeatedly contact a slow or unavailable site with other names.
    for (final query in queries.take(3)) {
      if (cancel.isCancelled) return const [];
      try {
        final found = await _attempt(source, query, cancel);
        if (cancel.isCancelled) return const [];
        for (final item in found) {
          if (seen.add(item.detailUrl)) items.add(item);
        }
        onResults?.call(List.unmodifiable(items));
        if (matches(items)) break;
      } catch (_) {
        if (cancel.isCancelled) return const [];
        if (items.isNotEmpty) return items;
        rethrow;
      }
    }
    return items;
  }

  Future<List<VideoItem>> _attempt(
      VideoSource source, String query, CancellationToken parent) async {
    final request = CancellationToken();
    final stopped = Completer<List<VideoItem>>();
    void stop() {
      request.cancel();
      if (!stopped.isCompleted) stopped.complete(const []);
    }

    parent.addListener(stop);
    try {
      return await Future.any([
        Future.sync(() => source.search(query, cancel: request)),
        stopped.future,
      ]).timeout(attemptTimeout, onTimeout: () {
        request.cancel();
        throw TimeoutException(
            'Source search attempt timed out', attemptTimeout);
      });
    } finally {
      parent.removeListener(stop);
      request.cancel();
    }
  }
}
