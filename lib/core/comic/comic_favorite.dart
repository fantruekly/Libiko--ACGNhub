import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

class ComicFavorite {
  final String sourceKey;
  final String comicId;
  final String title;
  final String? cover;
  final DateTime addedAt;

  const ComicFavorite({
    required this.sourceKey,
    required this.comicId,
    required this.title,
    this.cover,
    required this.addedAt,
  });

  factory ComicFavorite.fromJson(Map<String, dynamic> json) => ComicFavorite(
        sourceKey: json['sourceKey'] as String? ?? '',
        comicId: json['comicId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cover: json['cover'] as String?,
        addedAt:
            DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'sourceKey': sourceKey,
        'comicId': comicId,
        'title': title,
        'cover': cover,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };
}

class ComicFavoriteManager {
  static const _key = 'comic_favorites';

  List<ComicFavorite> all() {
    final favorites = <ComicFavorite>[];
    for (final raw in AppDatabase().getStringList(_key)) {
      try {
        favorites.add(
            ComicFavorite.fromJson(json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return favorites;
  }

  bool isFavorite(String sourceKey, String comicId) =>
      all().any((f) => f.sourceKey == sourceKey && f.comicId == comicId);

  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> toggle(ComicFavorite favorite) => _enqueue(() async {
        final favorites = all();
        final exists = favorites.any((f) =>
            f.sourceKey == favorite.sourceKey && f.comicId == favorite.comicId);
        if (exists) {
          final remaining = favorites
              .where((f) =>
                  !(f.sourceKey == favorite.sourceKey &&
                      f.comicId == favorite.comicId))
              .toList();
          await _save(remaining);
        } else {
          await _save(upsert(favorites, favorite));
        }
      });

  Future<void> remove(String sourceKey, String comicId) => _enqueue(() async {
        final favorites = all()
            .where((f) => !(f.sourceKey == sourceKey && f.comicId == comicId))
            .toList();
        await _save(favorites);
      });

  Future<void> clear() => _enqueue(() => AppDatabase().remove(_key));

  Future<void> _save(List<ComicFavorite> favorites) async {
    await AppDatabase().setStringList(
        _key, favorites.map((f) => json.encode(f.toJson())).toList());
  }

  @visibleForTesting
  static List<ComicFavorite> upsert(
      List<ComicFavorite> current, ComicFavorite favorite) {
    final out = current
        .where((f) =>
            !(f.sourceKey == favorite.sourceKey &&
                f.comicId == favorite.comicId))
        .toList();
    out.insert(0, favorite);
    return out;
  }
}

class ComicFavoritesNotifier extends Notifier<List<ComicFavorite>> {
  final _manager = ComicFavoriteManager();

  @override
  List<ComicFavorite> build() => _manager.all();

  bool isFavorite(String sourceKey, String comicId) =>
      state.any((f) => f.sourceKey == sourceKey && f.comicId == comicId);

  Future<void> toggle(ComicFavorite favorite) async {
    await _manager.toggle(favorite);
    state = _manager.all();
  }

  Future<void> clear() async {
    await _manager.clear();
    state = const [];
  }
}

final comicFavoritesProvider =
    NotifierProvider<ComicFavoritesNotifier, List<ComicFavorite>>(
        ComicFavoritesNotifier.new);
