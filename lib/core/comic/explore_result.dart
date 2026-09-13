import 'models.dart';

/// A titled sub-section of an explore result (`multiPartPage` parts and
/// `singlePageWithMultiPart` entries).
class ComicPart {
  final String title;
  final List<Comic> comics;
  final String? viewMore;

  const ComicPart({required this.title, required this.comics, this.viewMore});
}

/// A normalized explore/search result: the flattened comics, the titled parts
/// it was built from, plus optional pagination metadata.
class ExplorePage {
  final List<Comic> comics;
  final int? maxPage;
  final String? next;
  final String? viewMore;
  final List<ComicPart> parts;

  const ExplorePage(
      {required this.comics,
      this.maxPage,
      this.next,
      this.viewMore,
      this.parts = const []});
}

/// Normalizes the shapes a Venera source can return from `search.load` /
/// `explore[].load`:
/// - `{ comics, maxPage }`
/// - `{ parts: [{ title, comics }] }`
/// - `[{ title, comics }]` (multiPartPage)
/// - `{ <title>: Comic[], ... }` (singlePageWithMultiPart)
/// - `{ data: [Comic[] | { title, comics }] }` (mixed)
/// It also returns the first non-empty `viewMore` (a `category:<name>@<param>`
/// target) found on parts/data entries, and keeps each titled part.
ExplorePage parseExploreResult(dynamic raw) {
  final out = <Comic>[];
  final parts = <ComicPart>[];

  List<Comic> comicsOf(dynamic list) {
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Comic.fromJs(e.cast<dynamic, dynamic>()))
        .toList();
  }

  void addComics(dynamic list) => out.addAll(comicsOf(list));

  String? viewMore;
  void takeViewMore(dynamic part) {
    if (part is! Map) return;
    final vm = part['viewMore'];
    if (viewMore == null && vm is String && vm.isNotEmpty) viewMore = vm;
  }

  void addParts(dynamic rawParts) {
    if (rawParts is! List) return;
    for (final part in rawParts) {
      if (part is Map) {
        final comics = comicsOf(part['comics']);
        out.addAll(comics);
        parts.add(ComicPart(
          title: part['title']?.toString() ?? '',
          comics: comics,
          viewMore: part['viewMore']?.toString(),
        ));
        takeViewMore(part);
      }
    }
  }

  int? maxPage;
  String? next;

  if (raw is List) {
    addParts(raw);
  } else if (raw is Map) {
    final comics = raw['comics'];
    final rawParts = raw['parts'];
    final data = raw['data'];
    if (comics is List) addComics(comics);
    if (rawParts is List) addParts(rawParts);
    if (data is List) {
      for (final item in data) {
        if (item is List) {
          addComics(item);
        } else if (item is Map) {
          final itemComics = comicsOf(item['comics']);
          out.addAll(itemComics);
          parts.add(ComicPart(
            title: item['title']?.toString() ?? '',
            comics: itemComics,
            viewMore: item['viewMore']?.toString(),
          ));
          takeViewMore(item);
        }
      }
    }
    if (comics is! List && rawParts is! List && data is! List) {
      for (final entry in raw.entries) {
        final entryComics = comicsOf(entry.value);
        out.addAll(entryComics);
        parts.add(ComicPart(
            title: entry.key.toString(), comics: entryComics));
      }
    }
    final mp = raw['maxPage'];
    if (mp is num) maxPage = mp.toInt();
    final n = raw['next'];
    if (n is String && n.isNotEmpty) next = n;
  }

  return ExplorePage(
      comics: out,
      maxPage: maxPage,
      next: next,
      viewMore: viewMore,
      parts: parts);
}
