/// Title matching helpers. Scores are deterministic and deliberately conservative:
/// a plausible substring is insufficient when a season or edition disagrees.
const double defaultTitleMatchThreshold = 0.72;

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
  if (a.contains(b) || b.contains(a)) {
    // Avoid treating a tiny shared prefix as a confident match.
    final ratio =
        a.length < b.length ? a.length / b.length : b.length / a.length;
    return ratio >= 0.55 ? 0.9 : ratio;
  }
  final ba = _bigrams(a);
  final bb = _bigrams(b);
  return 2 * ba.intersection(bb).length / (ba.length + bb.length);
}

int? _number(String value) {
  final number = int.tryParse(value);
  if (number != null) return number;
  const digits = {
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
    '十': 10
  };
  if (digits.containsKey(value)) return digits[value];
  if (value.startsWith('十') && value.length == 2) {
    return 10 + (digits[value[1]] ?? 0);
  }
  if (value.endsWith('十') && value.length == 2) {
    return (digits[value[0]] ?? 0) * 10;
  }
  const romans = {
    'i': 1,
    'ii': 2,
    'iii': 3,
    'iv': 4,
    'v': 5,
    'vi': 6,
    'vii': 7,
    'viii': 8,
    'ix': 9,
    'x': 10
  };
  return romans[value.toLowerCase()];
}

int? _season(String title) {
  final text = title
      .replaceAll('Ⅱ', ' II ')
      .replaceAll('Ⅲ', ' III ')
      .replaceAll('Ⅳ', ' IV ')
      .replaceAll('Ⅰ', ' I ');
  final chinese = RegExp(r'第\s*([一二三四五六七八九十\d]+)\s*[季期]').firstMatch(text);
  if (chinese != null) return _number(chinese[1]!);
  final english = RegExp(r'\b(?:season\s*|s)(\d+)\b', caseSensitive: false)
      .firstMatch(text);
  if (english != null) return _number(english[1]!);
  final ordinal =
      RegExp(r'\b(\d+)(?:st|nd|rd|th)\s+season\b', caseSensitive: false)
          .firstMatch(text);
  if (ordinal != null) return _number(ordinal[1]!);
  final roman =
      RegExp(r'(?:^|[\s:：～~\-])([ivx]+)(?=$|[\s:：～~\-])', caseSensitive: false)
          .firstMatch(text);
  if (roman != null) return _number(roman[1]!);
  final suffix = RegExp(r'^(.*[^\d\s])\s*([1-9]\d?)$').firstMatch(text);
  if (suffix != null) return _number(suffix[2]!);
  return null;
}

String? _edition(String title) {
  if (RegExp(r'总集篇|總集篇|总集编|總集編|recap|compilation', caseSensitive: false)
      .hasMatch(title)) {
    return 'recap';
  }
  if (RegExp(r'剧场版|劇場版|电影|電影|\bmovie\b|\bfilm\b', caseSensitive: false)
      .hasMatch(title)) {
    return 'movie';
  }
  if (RegExp(r'\bova\b|\boad\b', caseSensitive: false).hasMatch(title)) {
    return 'ova';
  }
  if (RegExp(r'特别篇|特別篇|\bspecial\b', caseSensitive: false).hasMatch(title)) {
    return 'special';
  }
  return null;
}

String _matchingTitle(String title) => normalizeTitle(title
    .replaceAll(
        RegExp(
            r'剧场版|劇場版|电影|電影|总集篇|總集篇|总集编|總集編|特别篇|特別篇|\b(?:movie|film|ova|oad|special|recap|compilation)\b',
            caseSensitive: false),
        '')
    .replaceAll(RegExp(r'第\s*[一二三四五六七八九十\d]+\s*[季期]'), '')
    .replaceAll(
        RegExp(r'\b(?:season\s*\d+|s\d+|\d+(?:st|nd|rd|th)\s+season)\b',
            caseSensitive: false),
        '')
    .replaceAll(
        RegExp(r'(?:^|[\s:：～~\-])[ivx]+(?=$|[\s:：～~\-])', caseSensitive: false),
        '')
    .replaceAll(RegExp('[ⅠⅡⅢⅣ]'), '')
    .replaceFirstMapped(
        RegExp(r'^(.*[^\d\s])\s*([1-9]\d?)$'), (match) => match[1]!));

/// Extract only known metadata title fields, never arbitrary extra values.
List<String> titleSearchQueries(String title, Map<String, dynamic> extra) {
  final queries = <String>[];
  final seen = <String>{};
  void add(Object? value) {
    if (value is! String || value.trim().isEmpty) return;
    if (seen.add(normalizeTitle(value))) queries.add(value.trim());
  }

  add(title);
  for (final key in const [
    'titleNative',
    'titleEnglish',
    'titleRomaji',
    'aliases',
    'synonyms'
  ]) {
    final value = extra[key];
    if (value is List) {
      for (final alias in value) {
        add(alias);
      }
    } else {
      add(value);
    }
  }
  return queries.take(4).toList();
}

/// 0..1 confidence, suppressing a conflicting season or edition even when an
/// alias happens to omit that qualifier. Missing season information is manual.
double titleMatchScore(String query, String candidate,
    {Iterable<String> aliases = const [], String? format}) {
  final queries =
      [query, ...aliases].where((q) => normalizeTitle(q).isNotEmpty).toList();
  if (queries.isEmpty || normalizeTitle(candidate).isEmpty) return 0;
  int? expectedSeason;
  for (final q in queries) {
    expectedSeason ??= _season(q);
  }
  final candidateSeason = _season(candidate);
  if (expectedSeason != null &&
      candidateSeason != null &&
      expectedSeason != candidateSeason) {
    return 0;
  }
  if (expectedSeason == null &&
      candidateSeason != null &&
      candidateSeason > 1) {
    return 0;
  }
  final expectedEdition = _edition(query) ?? _edition(format ?? '');
  final actualEdition = _edition(candidate);
  if ((expectedEdition ?? 'tv') != (actualEdition ?? 'tv')) return 0;
  var score = 0.0;
  for (final q in queries) {
    final current = _dice(_matchingTitle(q), _matchingTitle(candidate));
    if (current > score) score = current;
  }
  if (expectedSeason != null && candidateSeason == null && score > 0.65) {
    return 0.65;
  }
  return score;
}

/// Returns -1 when none reaches [minimumScore]; callers must retain candidates
/// for manual confirmation rather than treating the first hit as a match.
int bestMatchIndex(String query, List<String> candidates,
    {double minimumScore = defaultTitleMatchThreshold,
    Iterable<String> aliases = const [],
    String? format}) {
  var best = -1;
  var bestScore = minimumScore;
  for (var i = 0; i < candidates.length; i++) {
    final score =
        titleMatchScore(query, candidates[i], aliases: aliases, format: format);
    if (score > 0 &&
        score >= minimumScore &&
        (best == -1 || score > bestScore)) {
      bestScore = score;
      best = i;
    }
  }
  return best;
}
