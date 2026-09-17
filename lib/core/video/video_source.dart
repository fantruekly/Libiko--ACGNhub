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

  const VideoEpisode(
      {required this.id,
      required this.title,
      required this.index,
      required this.playUrl,
      this.userAgent});
}

abstract class VideoSource {
  String get id;
  String get name;
  String get baseUrl;
  Future<List<VideoItem>> search(String keyword);
  Future<List<VideoEpisode>> episodes(String detailUrl);
}
