import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/galgamezywz_source.dart';
import '../../core/game/game_source.dart';
import '../../core/game/models.dart';

final gameSourceManagerProvider = Provider<GameSourceManager>(
  (ref) => GameSourceManager(sources: [GalgameZywzSource()]),
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
