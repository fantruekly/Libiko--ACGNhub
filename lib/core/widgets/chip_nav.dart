/// Steps a three-level chip selection by [delta] (+1 / -1), crossing into the
/// adjacent level when the current one is at its end. Levels run outer (a) ->
/// inner (c); moving a level resets the levels inside it to their minimum.
/// Returns null when the outer level is already at its end.
({int a, int b, int c})? stepChipSelection({
  required int a,
  required int aMin,
  required int aMax,
  required int b,
  required int bMin,
  required int bMax,
  required int c,
  required int cMin,
  required int cMax,
  required int delta,
}) {
  if (cMax > cMin) {
    final next = c + delta;
    if (next >= cMin && next <= cMax) return (a: a, b: b, c: next);
  }
  if (bMax > bMin) {
    final next = b + delta;
    if (next >= bMin && next <= bMax) return (a: a, b: next, c: cMin);
  }
  if (aMax > aMin) {
    final next = a + delta;
    if (next >= aMin && next <= aMax) return (a: next, b: bMin, c: cMin);
  }
  return null;
}
