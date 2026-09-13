import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_image.dart';
import '../../core/comic/comic_source.dart';
import '../../core/comic/models.dart';
import '../../core/storage/database.dart';

final comicSourceManagerProvider =
    Provider<ComicSourceManager>((ref) => ComicSourceManager());

final comicSourcesProvider = FutureProvider<List<ComicSource>>((ref) async {
  final manager = ref.watch(comicSourceManagerProvider);
  await manager.load();
  return manager.sources;
});

/// The first explore section's first page for a source.
final comicExploreProvider =
    FutureProvider.family<List<Comic>, String>((ref, sourceKey) async {
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null || !source.canExplore) return const [];
  return manager.explore(source, 0);
});

/// A search hit paired with the source that produced it (a comic id is only
/// meaningful together with its source key).
class ComicSearchResult {
  final Comic comic;
  final String sourceKey;
  const ComicSearchResult({required this.comic, required this.sourceKey});
}

/// Search across every source that can search, merging the results.
final comicSearchProvider =
    FutureProvider.family<List<ComicSearchResult>, String>(
        (ref, keyword) async {
  final manager = ref.watch(comicSourceManagerProvider);
  final sources = ref.watch(comicSourcesProvider).valueOrNull ?? const [];
  final searchable = sources.where((s) => s.canSearch).toList();
  if (searchable.isEmpty) return const [];
  final results = <ComicSearchResult>[];
  Object? lastError;
  var succeeded = 0;
  for (final source in searchable) {
    try {
      for (final comic in await manager.search(source, keyword)) {
        results.add(ComicSearchResult(comic: comic, sourceKey: source.key));
      }
      succeeded++;
    } catch (e) {
      lastError = e;
    }
  }
  if (succeeded == 0) {
    throw StateError('所有漫画源搜索失败：$lastError');
  }
  return results;
});

final comicDetailProvider =
    FutureProvider.family<ComicDetails, (String, String)>(
        (ref, key) async {
  final manager = ref.watch(comicSourceManagerProvider);
  final (sourceKey, comicId) = key;
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  return manager.loadInfo(source, comicId);
});

final comicEpProvider =
    FutureProvider.family<ComicEp, (String, String, String)>(
        (ref, key) async {
  final manager = ref.watch(comicSourceManagerProvider);
  final (sourceKey, comicId, chapterId) = key;
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  return manager.loadEp(source, comicId, chapterId);
});

final comicImageProvider = Provider<ComicImageProvider>(
    (ref) => ComicImageProvider(ref.watch(comicSourceManagerProvider)));

/// The persisted URL of the remote source list shown on the 源管理 page.
class ComicSourceListUrlNotifier extends Notifier<String> {
  static const _key = 'comic_source_list_url';

  @override
  String build() => AppDatabase().getString(_key) ?? '';

  Future<void> set(String value) async {
    await AppDatabase().setString(_key, value);
    state = value;
  }
}

final comicSourceListUrlProvider =
    NotifierProvider<ComicSourceListUrlNotifier, String>(
        ComicSourceListUrlNotifier.new);
