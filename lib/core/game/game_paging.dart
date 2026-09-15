import 'models.dart';

const int gamePageSize = 24;

class GameSourcePage {
  final List<Game> items;
  final bool hasMore;
  const GameSourcePage({required this.items, required this.hasMore});
}

Future<GameList> buildGamePage({
  required int page,
  required int sourcePageSize,
  required Future<GameSourcePage> Function(int sourcePage) fetch,
}) async {
  assert(sourcePageSize > 0 && gamePageSize % sourcePageSize == 0,
      'sourcePageSize must divide gamePageSize');
  final pagesPerApp = (gamePageSize / sourcePageSize).ceil();
  final startServer = (page - 1) * pagesPerApp + 1;
  final items = <Game>[];
  var hasMore = false;
  for (var i = 0; i < pagesPerApp; i++) {
    final GameSourcePage result;
    try {
      result = await fetch(startServer + i);
    } catch (_) {
      if (i == 0) rethrow;
      hasMore = false;
      break;
    }
    if (result.items.isEmpty) {
      hasMore = false;
      break;
    }
    items.addAll(result.items);
    hasMore = result.hasMore;
    if (!hasMore) break;
  }
  final trimmed =
      items.length > gamePageSize ? items.sublist(0, gamePageSize) : items;
  return GameList(items: trimmed, page: page, hasMore: hasMore);
}
