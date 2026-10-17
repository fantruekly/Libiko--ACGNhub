import 'cancellation.dart';

class VideoItem {
  final String id;
  final String title;
  final String? cover;
  final String detailUrl;

  const VideoItem(
      {required this.id,
      required this.title,
      this.cover,
      required this.detailUrl});
}

class VideoEpisode {
  final String id;
  final String title;
  final int index;
  final String playUrl;
  final String? userAgent;
  final String? referer;
  final bool useLegacyParser;
  final String? sourceId;
  final String? lineId;
  final String? lineName;
  final String? episodeKey;

  const VideoEpisode(
      {required this.id,
      required this.title,
      required this.index,
      required this.playUrl,
      this.userAgent,
      this.referer,
      this.sourceId,
      this.lineId,
      this.lineName,
      this.episodeKey,
      this.useLegacyParser = false});
}

/// A conservative cross-line identity. Unrecognized/special titles keep their
/// whole label, so an OVA or a two-part episode never matches a regular episode.
String? episodeKeyFromTitle(String title) {
  final label = title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  if (label.isEmpty) return null;
  final regular = RegExp(r'^(?:第)?(\d+)(?:集|话|話)?$').firstMatch(label) ??
      RegExp(r'^(?:ep|episode)[.\-]?(\d+)$').firstMatch(label);
  if (regular != null) return 'episode:${int.parse(regular.group(1)!)}';
  return 'title:$label';
}

/// Returns a list position, preserving the current source and line.
int? nextEpisodeIndex(List<VideoEpisode> episodes, int currentIndex) {
  if (currentIndex < 0 || currentIndex >= episodes.length) return null;
  final current = episodes[currentIndex];
  for (var i = currentIndex + 1; i < episodes.length; i++) {
    final candidate = episodes[i];
    if (candidate.sourceId == current.sourceId &&
        candidate.lineId == current.lineId) {
      return i;
    }
  }
  return null;
}

/// Matches an unambiguous episode key, never a line-relative array position.
int? matchingEpisodeIndex(
    List<VideoEpisode> episodes, int currentIndex, String targetLineId,
    {String? targetSourceId}) {
  if (currentIndex < 0 || currentIndex >= episodes.length) return null;
  final current = episodes[currentIndex];
  final key = current.episodeKey;
  if (key == null || key.isEmpty) return null;
  final sourceId = targetSourceId ?? current.sourceId;
  // Duplicate identities on either line require a manual choice.
  if (episodes
          .where((e) =>
              e.sourceId == current.sourceId &&
              e.lineId == current.lineId &&
              e.episodeKey == key)
          .length !=
      1) {
    return null;
  }
  final matches = <int>[];
  for (var i = 0; i < episodes.length; i++) {
    final e = episodes[i];
    if (e.sourceId == sourceId &&
        e.lineId == targetLineId &&
        e.episodeKey == key) {
      matches.add(i);
    }
  }
  return matches.length == 1 ? matches.single : null;
}

abstract class VideoSource {
  String get id;
  String get name;
  String get baseUrl;
  Future<List<VideoItem>> search(String keyword, {CancellationToken? cancel});
  Future<List<VideoEpisode>> episodes(String detailUrl,
      {CancellationToken? cancel});
}
