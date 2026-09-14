import 'dart:convert';

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
    for (final raw in AppDatabase().getStringList(_key)) {
      try {
        favorites.add(
            NovelFavorite.fromJson(json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return favorites;
  }

  bool isFavorite(String sourceKey, String novelId) =>
      all().any((f) => f.sourceKey == sourceKey && f.novelId == novelId);

  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> toggle(NovelFavorite favorite) => _enqueue(() async {
        final favorites = all();
        final exists = favorites.any((f) =>
            f.sourceKey == favorite.sourceKey && f.novelId == favorite.novelId);
        if (exists) {
          final remaining = favorites
              .where((f) =>
                  !(f.sourceKey == favorite.sourceKey &&
                      f.novelId == favorite.novelId))
              .toList();
          await _save(remaining);
        } else {
          await _save(upsert(favorites, favorite));
        }
      });

  Future<void> remove(String sourceKey, String novelId) => _enqueue(() async {
        final favorites = all()
            .where((f) => !(f.sourceKey == sourceKey && f.novelId == novelId))
            .toList();
        await _save(favorites);
      });

  Future<void> clear() => _enqueue(() => AppDatabase().remove(_key));

  Future<void> _save(List<NovelFavorite> favorites) async {
    await AppDatabase().setStringList(
        _key, favorites.map((f) => json.encode(f.toJson())).toList());
  }

  @visibleForTesting
  static List<NovelFavorite> upsert(
      List<NovelFavorite> current, NovelFavorite favorite) {
    final out = current
        .where((f) =>
            !(f.sourceKey == favorite.sourceKey &&
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
