import 'dart:convert';
import '../models/work.dart';
import '../storage/database.dart';

class FavoriteManager {
  static const _key = 'favorites';

  List<Work> getFavorites({WorkType? type}) {
    final jsonList = AppDatabase().getStringList(_key);
    final works = jsonList.map((j) => Work.fromJson(json.decode(j) as Map<String, dynamic>)).toList();
    if (type != null) {
      return works.where((w) => w.type == type).toList();
    }
    return works;
  }

  Future<void> addFavorite(Work work) async {
    final favorites = getFavorites();
    if (favorites.any((w) => w.id == work.id)) return;
    favorites.add(work);
    await _save(favorites);
  }

  Future<void> removeFavorite(String workId) async {
    final favorites = getFavorites();
    favorites.removeWhere((w) => w.id == workId);
    await _save(favorites);
  }

  bool isFavorite(String workId) {
    return getFavorites().any((w) => w.id == workId);
  }

  Future<void> _save(List<Work> works) async {
    final jsonList = works.map((w) => json.encode(w.toJson())).toList();
    await AppDatabase().setStringList(_key, jsonList);
  }
}