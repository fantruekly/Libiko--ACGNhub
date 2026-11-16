import 'resolve_result.dart';
import 'video_source.dart';

/// Try the explicitly selected line first. Only a definite empty result
/// justifies automatic line switching; slow/network failures stay retryable.
Future<(int, ResolveResult)> resolveLineFallback(
    List<VideoEpisode> episodes,
    int selected,
    Future<ResolveResult> Function(VideoEpisode) resolve,
    bool Function() cancelled) async {
  var index = selected;
  var result = await resolve(episodes[index]);
  final tried = <String?>{episodes[index].lineId};
  for (final episode in episodes) {
    if (cancelled() || result.ok || result.failure != ResolveFailure.notFound) {
      break;
    }
    if (!tried.add(episode.lineId) || episode.lineId == null) continue;
    final match = matchingEpisodeIndex(episodes, selected, episode.lineId!,
        targetSourceId: episodes[selected].sourceId);
    if (match == null) continue;
    index = match;
    result = await resolve(episodes[index]);
  }
  return (index, result);
}
