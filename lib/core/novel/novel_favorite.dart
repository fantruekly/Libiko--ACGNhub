import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

class NovelFavorite {
  final String sourceKey;
  final String novelId;
  final String title;
  final String? cover;
  final DateTime addedAt;

  const NovelFavorite({
    required this.sourceKey,
    required this.novelId,
    required this.title,
    this.cover,
    required this.addedAt,
  });

  factory NovelFavorite.fromJson(Map<String, dynamic> json) => NovelFavorite(
        sourceKey: json['sourceKey'] as String? ?? '',
        novelId: json['novelId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cover: json['cover'] as String?,
        addedAt:
            DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'sourceKey': sourceKey,
        'novelId': novelId,
        'title': title,
        'cover': cover,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };
}

class NovelFavoriteManager {
  static const _key = 'novel_favorites';

  List<NovelFavorite> all() {
    final favorites = <NovelFavorite>[];
    for (final row in AppDatabase().collections.all(_key)) {
      try {
        favorites.add(NovelFavorite.fromJson(row));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return favorites;
  }

  bool isFavorite(String sourceKey, String novelId) {
    final store = AppDatabase().collections;
    return store.get(
            _key,
            store.recordKey(
                _key, {'sourceKey': sourceKey, 'novelId': novelId})) !=
        null;
  }

  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> toggle(NovelFavorite favorite) => _enqueue(() async {
        final exists = isFavorite(favorite.sourceKey, favorite.novelId);
        if (exists) {
          AppDatabase().collections.remove(_key, favorite.toJson());
        } else {
          AppDatabase().collections.upsert(_key, favorite.toJson());
        }
      });

  Future<void> remove(String sourceKey, String novelId) => _enqueue(() async {
        final store = AppDatabase().collections;
        final row = store.get(
            _key,
            store
                .recordKey(_key, {'sourceKey': sourceKey, 'novelId': novelId}));
        if (row != null) store.remove(_key, row);
      });

  Future<void> clear() => _enqueue(() => AppDatabase().remove(_key));

  @visibleForTesting
  static List<NovelFavorite> upsert(
      List<NovelFavorite> current, NovelFavorite favorite) {
    final out = current
        .where((f) => !(f.sourceKey == favorite.sourceKey &&
            f.novelId == favorite.novelId))
        .toList();
    out.insert(0, favorite);
    return out;
  }
}

class NovelFavoritesNotifier extends Notifier<List<NovelFavorite>> {
  final _manager = NovelFavoriteManager();

  @override
  List<NovelFavorite> build() => _manager.all();

  Future<void> toggle(NovelFavorite favorite) async {
    await _manager.toggle(favorite);
    state = _manager.all();
  }

  Future<void> clear() async {
    await _manager.clear();
    state = const [];
  }
}

final novelFavoritesProvider =
    NotifierProvider<NovelFavoritesNotifier, List<NovelFavorite>>(
        NovelFavoritesNotifier.new);
