import 'work.dart';

class WatchRecord {
  final Work work;
  final String episodeTitle;
  final int episodeIndex;
  final DateTime watchedAt;
  final DateTime updatedAt;
  final bool deleted;
  final bool dirty;
  final int positionMs;
  final int durationMs;
  final String? sourceId;
  final String? lineId;
  final String? episodeKey;
  final bool completed;

  WatchRecord({
    required this.work,
    required this.episodeTitle,
    required this.episodeIndex,
    required this.watchedAt,
    DateTime? updatedAt,
    this.deleted = false,
    this.dirty = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.sourceId,
    this.lineId,
    this.episodeKey,
    this.completed = false,
  }) : updatedAt = updatedAt ?? watchedAt;

  factory WatchRecord.fromJson(Map<String, dynamic> json) {
    final watchedAt =
        DateTime.fromMillisecondsSinceEpoch(json['watchedAt'] as int? ?? 0);
    final updatedMs = json['updatedAt'] as int?;
    return WatchRecord(
      work: Work.fromJson(json['work'] as Map<String, dynamic>),
      episodeTitle: json['episodeTitle'] as String? ?? '',
      episodeIndex: json['episodeIndex'] as int? ?? 0,
      watchedAt: watchedAt,
      updatedAt: updatedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedMs),
      deleted: json['deleted'] as bool? ?? false,
      dirty: json['dirty'] as bool? ?? false,
      positionMs: json['positionMs'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
      sourceId: json['sourceId'] as String?,
      lineId: json['lineId'] as String?,
      episodeKey: json['episodeKey'] as String?,
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'work': work.toJson(),
        'episodeTitle': episodeTitle,
        'episodeIndex': episodeIndex,
        'watchedAt': watchedAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
        'dirty': dirty,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'sourceId': sourceId,
        'lineId': lineId,
        'episodeKey': episodeKey,
        'completed': completed,
      };

  WatchRecord copyWith({
    String? episodeTitle,
    int? episodeIndex,
    DateTime? watchedAt,
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
    int? positionMs,
    int? durationMs,
    String? sourceId,
    String? lineId,
    String? episodeKey,
    bool? completed,
  }) =>
      WatchRecord(
        work: work,
        episodeTitle: episodeTitle ?? this.episodeTitle,
        episodeIndex: episodeIndex ?? this.episodeIndex,
        watchedAt: watchedAt ?? this.watchedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        positionMs: positionMs ?? this.positionMs,
        durationMs: durationMs ?? this.durationMs,
        sourceId: sourceId ?? this.sourceId,
        lineId: lineId ?? this.lineId,
        episodeKey: episodeKey ?? this.episodeKey,
        completed: completed ?? this.completed,
      );
}
