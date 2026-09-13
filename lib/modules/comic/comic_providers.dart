import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_image.dart';
import '../../core/comic/comic_reader_settings.dart';
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

/// One page of an explore section.
class ComicExplorePage {
  final List<Comic> comics;
  final int page;
  final int? maxPage;
  final bool hasNext;
  final bool serverPaged;
  final String? next;

  const ComicExplorePage({
    required this.comics,
    required this.page,
    this.maxPage,
    required this.hasNext,
    required this.serverPaged,
    this.next,
  });
}

const _explorePageSize = 48;

/// The full one-shot list for a non-server-paged section (cached per section).
final comicExploreAllProvider =
    FutureProvider.family<List<Comic>, (String, int)>((ref, key) async {
  final (sourceKey, section) = key;
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  return (await manager.explore(source, section, page: 1)).comics;
});

/// `multiPageComicList` sections page on the source; every other section is
/// loaded once and paginated here at [_explorePageSize] comics per page. A
/// source that pages by offset without a total (Komiic, zaimanhua) reports no
/// `maxPage`, so `hasNext` is true while the page still has comics.
final FutureProviderFamily<ComicExplorePage, (String, int, int)>
    comicExploreProvider = FutureProvider.family<ComicExplorePage,
        (String, int, int)>((ref, key) async {
  final (sourceKey, section, page) = key;
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  final sectionMeta = section >= 0 && section < source.sections.length
      ? source.sections[section]
      : null;
  final type = sectionMeta?.type ?? '';
  if (sectionMeta?.usesLoadNext == true) {
    final cursor = page <= 1
        ? null
        : (await ref.watch(
                comicExploreProvider((sourceKey, section, page - 1)).future))
            .next;
    final result =
        await manager.explore(source, section, page: page, cursor: cursor);
    return ComicExplorePage(
      comics: result.comics,
      page: page,
      maxPage: null,
      hasNext: result.next != null,
      serverPaged: true,
      next: result.next,
    );
  }
  if (type == 'multiPageComicList') {
    final result = await manager.explore(source, section, page: page);
    final rawMax = result.maxPage;
    final maxPage = (rawMax == null || rawMax < 1) ? null : rawMax;
    return ComicExplorePage(
      comics: result.comics,
      page: page,
      maxPage: maxPage,
      hasNext: maxPage != null ? page < maxPage : result.comics.isNotEmpty,
      serverPaged: true,
    );
  }
  final all =
      await ref.watch(comicExploreAllProvider((sourceKey, section)).future);
  final maxPage =
      all.isEmpty ? 1 : (all.length + _explorePageSize - 1) ~/ _explorePageSize;
  final start = (page - 1) * _explorePageSize;
  final end = (start + _explorePageSize).clamp(0, all.length);
  final comics = start >= all.length ? const <Comic>[] : all.sublist(start, end);
  return ComicExplorePage(
    comics: comics,
    page: page,
    maxPage: maxPage,
    hasNext: page < maxPage,
    serverPaged: false,
  );
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

/// The persisted reader mode (continuous vertical vs. horizontal page flip).
class ComicReaderSettingsNotifier extends Notifier<ComicReaderSettings> {
  final _manager = ComicReaderSettingsManager();

  @override
  ComicReaderSettings build() => _manager.read();

  Future<void> setMode(ComicReaderMode mode) async {
    final next = state.copyWith(mode: mode);
    await _manager.write(next);
    state = next;
  }
}

final comicReaderSettingsProvider =
    NotifierProvider<ComicReaderSettingsNotifier, ComicReaderSettings>(
        ComicReaderSettingsNotifier.new);
