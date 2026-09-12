import 'work.dart';

class WatchRecord {
  final Work work;
  final String episodeTitle;
  final int episodeIndex;
  final DateTime watchedAt;

  const WatchRecord({
    required this.work,
    required this.episodeTitle,
    required this.episodeIndex,
    required this.watchedAt,
  });

  factory WatchRecord.fromJson(Map<String, dynamic> json) => WatchRecord(
        work: Work.fromJson(json['work'] as Map<String, dynamic>),
        episodeTitle: json['episodeTitle'] as String? ?? '',
        episodeIndex: json['episodeIndex'] as int? ?? 0,
        watchedAt:
            DateTime.fromMillisecondsSinceEpoch(json['watchedAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'work': work.toJson(),
        'episodeTitle': episodeTitle,
        'episodeIndex': episodeIndex,
        'watchedAt': watchedAt.millisecondsSinceEpoch,
      };
}
