enum TapZone { left, center, right }

TapZone tapZoneFor(double dx, double width) {
  if (width <= 0) return TapZone.center;
  final third = width / 3;
  if (dx < third) return TapZone.left;
  if (dx >= third * 2) return TapZone.right;
  return TapZone.center;
}

Duration seekTarget(Duration position, int delta, Duration duration) {
  final target = position + Duration(seconds: delta);
  if (target < Duration.zero) return Duration.zero;
  if (duration > Duration.zero && target > duration) return duration;
  return target;
}

String formatDuration(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
