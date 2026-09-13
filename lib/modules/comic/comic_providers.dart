import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_image.dart';
import '../../core/comic/comic_reader_settings.dart';
import '../../core/comic/comic_source.dart';
import '../../core/comic/explore_result.dart';
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

Future<ComicExplorePage> buildAlignedExplorePage({
  required int page,
  required int pageSize,
  required bool cursorPaged,
  required Future<ExplorePage> Function(int sourceIndex) fetch,
}) async {
  final accumulated = <Comic>[];
  var sourceIndex = 1;
  var hasMoreSource = true;
  while (accumulated.length <= page * pageSize && hasMoreSource) {
    final sourcePage = await fetch(sourceIndex);
    accumulated.addAll(sourcePage.comics);
    if (cursorPaged) {
      hasMoreSource = sourcePage.next != null;
    } else {
      hasMoreSource = sourcePage.maxPage != null
          ? sourceIndex < sourcePage.maxPage!
          : sourcePage.comics.isNotEmpty;
    }
    if (sourcePage.comics.isEmpty) break;
    sourceIndex++;
  }
  final start = (page - 1) * pageSize;
  final end = (start + pageSize).clamp(0, accumulated.length);
  final comics = start >= accumulated.length
      ? const <Comic>[]
      : accumulated.sublist(start, end);
  return ComicExplorePage(
    comics: comics,
    page: page,
    maxPage: null,
    hasNext: accumulated.length > page * pageSize,
    serverPaged: true,
  );
}

(String?, String?) _continuationTarget(String? viewMore) {
  if (viewMore == null || !viewMore.startsWith('category:')) {
    return (null, null);
  }
  final rest = viewMore.substring('category:'.length);
  final at = rest.indexOf('@');
  final name = at < 0 ? rest : rest.substring(0, at);
  final param = at < 0 ? null : rest.substring(at + 1);
  if (name.isEmpty) return (null, null);
  return (name, param);
}

/// How long an explore result stays usable from the on-disk cache.
const _exploreCacheTtl = Duration(minutes: 10);

String _exploreCacheKey(String sourceKey, int section) =>
    'comic_explore_cache.$sourceKey.$section';

/// Drops the on-disk explore cache for a section so the next load refetches.
void clearExploreCache(String sourceKey, int section) {
  AppDatabase().setString(_exploreCacheKey(sourceKey, section), '');
}

ExplorePage? _readExploreCache(String sourceKey, int section) {
  final raw = AppDatabase().getString(_exploreCacheKey(sourceKey, section));
  if (raw == null || raw.isEmpty) return null;
  try {
    final map = json.decode(raw) as Map<String, dynamic>;
    final ts = (map['ts'] as num).toInt();
    if (DateTime.now().millisecondsSinceEpoch - ts >
        _exploreCacheTtl.inMilliseconds) {
      return null;
    }
    return ExplorePage.fromJson((map['page'] as Map).cast<String, dynamic>());
  } catch (_) {
    return null;
  }
}

void _writeExploreCache(String sourceKey, int section, ExplorePage page) {
  AppDatabase().setString(
    _exploreCacheKey(sourceKey, section),
    json.encode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'page': page.toJson(),
    }),
  );
}

/// The full one-shot result for a non-server-paged section, cached per section
/// (in memory and on disk for [_exploreCacheTtl]), including its `viewMore`
/// target.
final comicExploreAllProvider =
    FutureProvider.family<ExplorePage, (String, int)>((ref, key) async {
  final (sourceKey, section) = key;
  final cached = _readExploreCache(sourceKey, section);
  if (cached != null) return cached;
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  final page = await manager.explore(source, section, page: 1);
  _writeExploreCache(sourceKey, section, page);
  return page;
});

/// One source page for a server- or cursor-paged section. Cursor sections
/// chain: source page N reads page N-1's `next`.
final FutureProviderFamily<ExplorePage, (String, int, int)>
    comicSourcePageProvider = FutureProvider.family<ExplorePage,
        (String, int, int)>((ref, key) async {
  final (sourceKey, section, sourceIndex) = key;
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  final meta = section >= 0 && section < source.sections.length
      ? source.sections[section]
      : null;
  if (meta?.usesLoadNext == true) {
    final cursor = sourceIndex <= 1
        ? null
        : (await ref.watch(
                comicSourcePageProvider((sourceKey, section, sourceIndex - 1))
                    .future))
            .next;
    return manager.explore(source, section, page: sourceIndex, cursor: cursor);
  }
  return manager.explore(source, section, page: sourceIndex);
});

/// Server- and cursor-paged sections accumulate source pages (fetched through
/// [comicSourcePageProvider]) and are sliced here at [_explorePageSize] (48)
/// comics per page with `maxPage` null, so `hasNext` is true while more source
/// pages remain. Every other (one-shot) section is loaded once and paginated
/// here, then continues into the source's category listing after its explore
/// content.
final FutureProviderFamily<ComicExplorePage, (String, int, int, int)>
    comicExploreProvider = FutureProvider.family<ComicExplorePage,
        (String, int, int, int)>((ref, key) async {
  final (sourceKey, section, part, page) = key;
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
  if (sectionMeta?.usesLoadNext == true || type == 'multiPageComicList') {
    return buildAlignedExplorePage(
      page: page,
      pageSize: _explorePageSize,
      cursorPaged: sectionMeta?.usesLoadNext == true,
      fetch: (sourceIndex) => ref.watch(
          comicSourcePageProvider((sourceKey, section, sourceIndex)).future),
    );
  }
  final explore =
      await ref.watch(comicExploreAllProvider((sourceKey, section)).future);
  final selectedPart = explore.parts.isNotEmpty
      ? explore.parts[part.clamp(0, explore.parts.length - 1)]
      : null;
  final all = selectedPart?.comics ?? explore.comics;
  final explorePages =
      all.isEmpty ? 1 : (all.length + _explorePageSize - 1) ~/ _explorePageSize;
  if (page <= explorePages) {
    final start = (page - 1) * _explorePageSize;
    final end = (start + _explorePageSize).clamp(0, all.length);
    final comics =
        start >= all.length ? const <Comic>[] : all.sublist(start, end);
    return ComicExplorePage(
      comics: comics,
      page: page,
      maxPage: source.hasCategoryComics ? null : explorePages,
      hasNext: source.hasCategoryComics || page < explorePages,
      serverPaged: false,
    );
  }
  if (!source.hasCategoryComics) {
    return ComicExplorePage(
      comics: const [],
      page: page,
      maxPage: explorePages,
      hasNext: false,
      serverPaged: false,
    );
  }
  final catPage = page - explorePages;
  final (cat, param) =
      _continuationTarget(selectedPart?.viewMore ?? explore.viewMore);
  final result =
      await manager.category(source, catPage, category: cat, param: param);
  final rawMax = result.maxPage;
  final maxPage = (rawMax == null || rawMax < 1) ? null : rawMax;
  return ComicExplorePage(
    comics: result.comics,
    page: page,
    maxPage: null,
    hasNext: maxPage != null ? catPage < maxPage : result.comics.isNotEmpty,
    serverPaged: true,
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
