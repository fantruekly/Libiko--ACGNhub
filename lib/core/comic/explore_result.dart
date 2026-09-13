import 'models.dart';

/// A normalized explore/search result: the flattened comics plus optional
/// pagination metadata.
class ExplorePage {
  final List<Comic> comics;
  final int? maxPage;
  final String? next;

  const ExplorePage({required this.comics, this.maxPage, this.next});
}

/// Normalizes the shapes a Venera source can return from `search.load` /
/// `explore[].load`:
/// - `{ comics, maxPage }`
/// - `{ parts: [{ title, comics }] }`
/// - `[{ title, comics }]` (multiPartPage)
/// - `{ <title>: Comic[], ... }` (singlePageWithMultiPart)
/// - `{ data: [Comic[] | { title, comics }] }` (mixed)
ExplorePage parseExploreResult(dynamic raw) {
  final out = <Comic>[];
  void addComics(dynamic list) {
    if (list is! List) return;
    out.addAll(list
        .whereType<Map>()
        .map((e) => Comic.fromJs(e.cast<dynamic, dynamic>())));
  }

  void addParts(dynamic parts) {
    if (parts is! List) return;
    for (final part in parts) {
      if (part is Map) addComics(part['comics']);
    }
  }

  int? maxPage;
  String? next;

  if (raw is List) {
    addParts(raw);
  } else if (raw is Map) {
    final comics = raw['comics'];
    final parts = raw['parts'];
    final data = raw['data'];
    if (comics is List) addComics(comics);
    if (parts is List) addParts(parts);
    if (data is List) {
      for (final item in data) {
        if (item is List) {
          addComics(item);
        } else if (item is Map) {
          addComics(item['comics']);
        }
      }
    }
    if (comics is! List && parts is! List && data is! List) {
      for (final value in raw.values) {
        addComics(value);
      }
    }
    final mp = raw['maxPage'];
    if (mp is num) maxPage = mp.toInt();
    final n = raw['next'];
    if (n is String && n.isNotEmpty) next = n;
  }

  return ExplorePage(comics: out, maxPage: maxPage, next: next);
}
