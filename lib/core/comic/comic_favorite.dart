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
    for (final row in AppDatabase().collections.all(_key)) {
      try {
        favorites.add(ComicFavorite.fromJson(row));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return favorites;
  }

  bool isFavorite(String sourceKey, String comicId) {
    final store = AppDatabase().collections;
    return store.get(
            _key,
            store.recordKey(
                _key, {'sourceKey': sourceKey, 'comicId': comicId})) !=
        null;
  }

  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> toggle(ComicFavorite favorite) => _enqueue(() async {
        final exists = isFavorite(favorite.sourceKey, favorite.comicId);
        if (exists) {
          AppDatabase().collections.remove(_key, favorite.toJson());
        } else {
          AppDatabase().collections.upsert(_key, favorite.toJson());
        }
      });

  Future<void> remove(String sourceKey, String comicId) => _enqueue(() async {
        final store = AppDatabase().collections;
        final row = store.get(
            _key,
            store
                .recordKey(_key, {'sourceKey': sourceKey, 'comicId': comicId}));
        if (row != null) store.remove(_key, row);
      });

  Future<void> clear() => _enqueue(() => AppDatabase().remove(_key));

  @visibleForTesting
  static List<ComicFavorite> upsert(
      List<ComicFavorite> current, ComicFavorite favorite) {
    final out = current
        .where((f) => !(f.sourceKey == favorite.sourceKey &&
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
