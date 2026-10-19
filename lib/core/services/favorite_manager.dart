import '../models/work.dart';
import '../storage/database.dart';

class FavoriteManager {
  static const _key = 'favorites';

  List<Work> getFavorites({WorkType? type}) {
    final works =
        AppDatabase().collections.all(_key).map(Work.fromJson).toList();
    if (type != null) {
      return works.where((w) => w.type == type).toList();
    }
    return works;
  }

  Future<void> addFavorite(Work work) async {
    final favorites = getFavorites();
    if (favorites.any((w) => w.id == work.id && w.type == work.type)) return;
    AppDatabase().collections.upsert(_key, work.toJson());
  }

  Future<void> removeFavorite(String workId) async {
    final favorites = getFavorites();
    for (final work in favorites.where((work) => work.id == workId)) {
      AppDatabase().collections.remove(_key, work.toJson());
    }
  }

  bool isFavorite(String workId) {
    return getFavorites().any((w) => w.id == workId);
  }
}
