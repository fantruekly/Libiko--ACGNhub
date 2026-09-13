import 'work.dart';

class FollowRecord {
  final Work work;
  final DateTime updatedAt;
  final bool deleted;
  final bool dirty;

  const FollowRecord({
    required this.work,
    required this.updatedAt,
    this.deleted = false,
    this.dirty = false,
  });

  factory FollowRecord.fromJson(Map<String, dynamic> json) => FollowRecord(
        work: Work.fromJson(json['work'] as Map<String, dynamic>),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int? ?? 0),
        deleted: json['deleted'] as bool? ?? false,
        dirty: json['dirty'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'work': work.toJson(),
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
        'dirty': dirty,
      };

  FollowRecord copyWith({DateTime? updatedAt, bool? deleted, bool? dirty}) =>
      FollowRecord(
        work: work,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
      );
}
