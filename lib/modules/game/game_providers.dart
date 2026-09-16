import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/galgamezywz_source.dart';
import '../../core/game/game_source.dart';
import '../../core/game/models.dart';
import '../../core/game/nekogal_source.dart';

final gameSourceManagerProvider = Provider<GameSourceManager>(
  (ref) => GameSourceManager(sources: [GalgameZywzSource(), NekogalSource()]),
);

final gameSourcesProvider = Provider<List<GameSource>>(
  (ref) => ref.watch(gameSourceManagerProvider).sources,
);

final gameBrowseProvider =
    FutureProvider.family<GameList, (String, String, int)>((ref, key) async {
  final (sourceId, optionKey, page) = key;
  final source = ref.watch(gameSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('game source $sourceId not found');
  return source.browse(optionKey, page: page);
});

final gameDetailProvider =
    FutureProvider.family<GameDetail, (String, String)>((ref, key) async {
  final (sourceId, gameId) = key;
  final source = ref.watch(gameSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('game source $sourceId not found');
  return source.detail(gameId);
});

class GameSearchResult {
  final Game game;
  final String sourceKey;
  const GameSearchResult({required this.game, required this.sourceKey});
}

const Duration gameSearchTimeout = Duration(seconds: 10);

final gameSearchSourceProvider =
    FutureProvider.family<List<GameSearchResult>, (String, String)>(
        (ref, key) async {
  final (sourceId, keyword) = key;
  final k = keyword.trim();
  if (k.isEmpty) return const [];
  final source = ref.watch(gameSourceManagerProvider).byId(sourceId);
  if (source == null) return const [];
  final games = await source.search(k).timeout(gameSearchTimeout);
  return [
    for (final game in games)
      GameSearchResult(game: game, sourceKey: sourceId),
  ];
});

final gameSearchProvider =
    FutureProvider.family<List<GameSearchResult>, String>((ref, keyword) async {
  final k = keyword.trim();
  if (k.isEmpty) return const [];
  final sources = ref.watch(gameSourceManagerProvider).sources;
  if (sources.isEmpty) return const [];
  final perSource = await Future.wait(sources.map((source) async {
    try {
      final games = await source.search(k).timeout(gameSearchTimeout);
      return (source.id, games, null);
    } catch (e) {
      return (source.id, const <Game>[], e);
    }
  }));
  final out = <GameSearchResult>[];
  final seen = <String>{};
  Object? lastError;
  var succeeded = 0;
  for (final (sourceId, games, error) in perSource) {
    if (error != null) {
      lastError = error;
      continue;
    }
    succeeded++;
    for (final game in games) {
      if (seen.add(game.title.trim())) {
        out.add(GameSearchResult(game: game, sourceKey: sourceId));
      }
    }
  }
  if (succeeded == 0) {
    throw StateError('所有游戏源搜索失败：$lastError');
  }
  return out;
});
