import '../sources/source_preferences.dart';

/// Take one snapshot per search. Health updates never reorder an active search
/// or override the user's explicit source ordering.
List<T> prioritizeAnimeSources<T>(
  List<T> sources, {
  required String Function(T) idOf,
  required SourcePreferences preferences,
  required SourceHealth Function(String) health,
  DateTime? now,
}) {
  final enabled = preferences.apply(SourceKind.anime, sources, idOf);
  final ids = enabled.map(idOf).toSet();
  if ((preferences.order[SourceKind.anime] ?? const []).any(ids.contains)) {
    return enabled;
  }
  final time = now ?? DateTime.now();
  final snapshot = {
    for (final source in enabled) idOf(source): health(idOf(source))
  };
  bool recent(DateTime? date, Duration age) {
    if (date == null) return false;
    final elapsed = time.difference(date);
    return !elapsed.isNegative && elapsed < age;
  }

  int rank(SourceHealth value) {
    final failedLast = value.lastPlaybackFailure != null &&
        (value.lastPlaybackSuccess == null ||
            value.lastPlaybackFailure!.isAfter(value.lastPlaybackSuccess!));
    if (failedLast &&
        recent(value.lastPlaybackFailure, const Duration(minutes: 10))) {
      return 2;
    }
    if (!failedLast &&
        recent(value.lastPlaybackSuccess, const Duration(days: 7))) {
      return 0;
    }
    return 1;
  }

  final sorted = enabled.indexed.toList();
  sorted.sort((a, b) {
    final left = snapshot[idOf(a.$2)]!;
    final right = snapshot[idOf(b.$2)]!;
    final priority = rank(left).compareTo(rank(right));
    if (priority != 0) return priority;
    if (rank(left) == 0) {
      // Missing timing sorts after measured successful starts. Always use the
      // same rule so three sources cannot produce a cyclic comparator.
      final speed = (left.lastStartupMs ?? 0x7fffffffffffffff)
          .compareTo(right.lastStartupMs ?? 0x7fffffffffffffff);
      if (speed != 0) return speed;
    }
    return a.$1.compareTo(b.$1);
  });
  return [for (final source in sorted) source.$2];
}
