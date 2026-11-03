import 'dart:async';

import '../models/work.dart';
import 'cancellation.dart';
import 'title_match.dart';
import 'video_source.dart';

class PlaybackSourceCandidate {
  const PlaybackSourceCandidate(this.source, this.item);
  final VideoSource source;
  final VideoItem item;
}

class PlaybackRecoveryRequest {
  const PlaybackRecoveryRequest(
      {required this.episode,
      required this.attemptedSources,
      required this.cancel});
  final VideoEpisode episode;
  final Set<String> attemptedSources;
  final CancellationToken cancel;
}

class PlaybackAlternative {
  const PlaybackAlternative(
      {required this.episodes, required this.index, required this.sourceName});
  final List<VideoEpisode> episodes;
  final int index;
  final String sourceName;
}

class PlaybackRecoveryResult {
  const PlaybackRecoveryResult(
      {this.alternative, this.attemptedSources = const {}});
  final PlaybackAlternative? alternative;
  final Set<String> attemptedSources;
}

typedef PlaybackRecoveryFinder = Future<PlaybackRecoveryResult> Function(
    PlaybackRecoveryRequest request);

/// Automatic recovery is stricter than the discovery UI. Manually confirming a
/// plausible result does not establish its suitability for automatic switching.
bool isUnambiguousRecoveryMatch(
    Work work, VideoItem selected, Iterable<VideoItem> items) {
  final queries = titleSearchQueries(work.title, work.extra);
  double score(VideoItem item) => titleMatchScore(work.title, item.title,
      aliases: queries.skip(1), format: work.extra['format'] as String?);
  final selectedScore = score(selected);
  if (selectedScore < 0.9) return false;
  return !items.any((item) =>
      item.detailUrl != selected.detailUrl &&
      score(item) >= selectedScore - 0.05);
}

/// Uses already matched works only, with a shared deadline and no more than two
/// other sources per episode. Every attempted source is returned, even on error.
class CrossSourceRecovery {
  const CrossSourceRecovery(this.candidates,
      {this.timeout = const Duration(seconds: 25), this.maxOtherSources = 2});
  final List<PlaybackSourceCandidate> candidates;
  final Duration timeout;
  final int maxOtherSources;

  Future<PlaybackRecoveryResult> find(PlaybackRecoveryRequest request) async {
    final attempted = <String>{};
    final key = request.episode.episodeKey;
    if (key == null || key.isEmpty || request.cancel.isCancelled) {
      return const PlaybackRecoveryResult();
    }
    final remainingSources =
        (maxOtherSources + 1 - request.attemptedSources.length)
            .clamp(0, maxOtherSources);
    final clock = Stopwatch()..start();
    for (final candidate in candidates) {
      final source = candidate.source;
      if (request.cancel.isCancelled || attempted.length >= remainingSources) {
        break;
      }
      if (request.attemptedSources.contains(source.id) ||
          !attempted.add(source.id)) {
        continue;
      }
      final remaining = timeout - clock.elapsed;
      if (remaining <= Duration.zero) break;
      final cancel = CancellationToken();
      final stopped = Completer<List<VideoEpisode>>();
      void stop() {
        cancel.cancel();
        if (!stopped.isCompleted) stopped.complete(const []);
      }

      request.cancel.addListener(stop);
      try {
        final episodes = await Future.any([
          Future.sync(
              () => source.episodes(candidate.item.detailUrl, cancel: cancel)),
          stopped.future,
        ]).timeout(remaining, onTimeout: () {
          cancel.cancel();
          return const [];
        });
        if (request.cancel.isCancelled) break;
        final lines = <String?>{};
        for (var i = 0; i < episodes.length; i++) {
          final episode = episodes[i];
          if (episode.sourceId != source.id ||
              episode.episodeKey != key ||
              !lines.add(episode.lineId)) {
            continue;
          }
          if (episodes
                  .where((e) =>
                      e.sourceId == source.id &&
                      e.lineId == episode.lineId &&
                      e.episodeKey == key)
                  .length !=
              1) {
            continue;
          }
          return PlaybackRecoveryResult(
              attemptedSources: Set.unmodifiable(attempted),
              alternative: PlaybackAlternative(
                  episodes: List.unmodifiable(episodes),
                  index: i,
                  sourceName: source.name));
        }
      } catch (_) {
        // The next already matched source may still contain this episode.
      } finally {
        request.cancel.removeListener(stop);
        cancel.cancel();
      }
    }
    return PlaybackRecoveryResult(
        attemptedSources: Set.unmodifiable(attempted));
  }
}
