/// Title matching helpers for picking a source's best search result.
String normalizeTitle(String s) {
  final lower = s.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    if (RegExp(r'[\s\p{P}\p{S}]', unicode: true).hasMatch(ch)) continue;
    buf.write(ch);
  }
  return buf.toString();
}

Set<String> _bigrams(String s) {
  if (s.length < 2) return s.isEmpty ? {} : {s};
  return {for (var i = 0; i < s.length - 1; i++) s.substring(i, i + 2)};
}

double _dice(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  if (a.contains(b) || b.contains(a)) return 0.9;
  final ba = _bigrams(a);
  final bb = _bigrams(b);
  if (ba.isEmpty || bb.isEmpty) return 0;
  final inter = ba.intersection(bb).length;
  return 2 * inter / (ba.length + bb.length);
}

/// Index of the candidate whose normalized title best matches [query], or -1.
int bestMatchIndex(String query, List<String> candidates) {
  if (candidates.isEmpty) return -1;
  final q = normalizeTitle(query);
  var best = 0;
  var bestScore = -1.0;
  for (var i = 0; i < candidates.length; i++) {
    final score = _dice(q, normalizeTitle(candidates[i]));
    if (score > bestScore) {
      bestScore = score;
      best = i;
    }
  }
  return best;
}
