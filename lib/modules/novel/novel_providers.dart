import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/lknovel_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_source.dart';

final novelSourceManagerProvider = Provider<NovelSourceManager>(
  (ref) => NovelSourceManager(sources: [LinovelibSource(), LknovelSource()]),
);

final novelSourcesProvider =
    Provider<List<NovelSource>>((ref) => ref.watch(novelSourceManagerProvider).sources);

/// 合并首页各书单并按 id 去重。
List<Novel> flattenHome(NovelHome home) {
  final seen = <String>{};
  final out = <Novel>[];
  for (final section in home.sections) {
    for (final novel in section.items) {
      if (seen.add(novel.id)) out.add(novel);
    }
  }
  return out;
}

final novelHomeProvider =
    FutureProvider.family<NovelHome, String>((ref, sourceId) async {
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.home();
});

final novelBrowseProvider =
    FutureProvider.family<NovelList, (String, String, int)>((ref, key) async {
  final (sourceId, optionKey, page) = key;
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.browse(optionKey, page: page);
});

final novelDetailProvider =
    FutureProvider.family<NovelDetail, (String, String)>((ref, key) async {
  final (sourceId, novelId) = key;
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.detail(novelId);
});

/// 按分卷顺序扁平化章节（供阅读器上一/下一章与目录使用）。
List<NovelChapterRef> flattenChapters(NovelDetail detail) =>
    [for (final volume in detail.volumes) ...volume.chapters];

final novelChapterProvider =
    FutureProvider.family<NovelChapter, (String, String, String)>(
        (ref, key) async {
  final (sourceId, novelId, chapterId) = key;
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.chapter(novelId, chapterId);
});

class NovelSearchResult {
  final Novel novel;
  final String sourceKey;
  const NovelSearchResult({required this.novel, required this.sourceKey});
}

/// 单个源搜索的超时时间，避免某个源卡住拖慢整个搜索。
const Duration novelSearchTimeout = Duration(seconds: 10);

/// 单个轻小说源的搜索结果，按源独立。
/// 页面可据此按源渐进展示：哪个源先返回就先显示，慢的源不阻塞。
final novelSearchSourceProvider =
    FutureProvider.family<List<NovelSearchResult>, (String, String)>(
        (ref, key) async {
  final (sourceId, keyword) = key;
  final k = keyword.trim();
  if (k.isEmpty) return const [];
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) return const [];
  final novels = await source.search(k).timeout(novelSearchTimeout);
  return [
    for (final novel in novels)
      NovelSearchResult(novel: novel, sourceKey: sourceId),
  ];
});

/// 并发搜索所有源并合并（按源顺序、标题去重）。慢的源不会叠加等待时间。
final novelSearchProvider =
    FutureProvider.family<List<NovelSearchResult>, String>((ref, keyword) async {
  final k = keyword.trim();
  if (k.isEmpty) return const [];
  final sources = ref.watch(novelSourceManagerProvider).sources;
  if (sources.isEmpty) return const [];
  final perSource = await Future.wait(sources.map((source) async {
    try {
      final novels = await source.search(k).timeout(novelSearchTimeout);
      return (source.id, novels, null);
    } catch (e) {
      return (source.id, const <Novel>[], e);
    }
  }));
  final out = <NovelSearchResult>[];
  final seen = <String>{};
  Object? lastError;
  var succeeded = 0;
  for (final (sourceId, novels, error) in perSource) {
    if (error != null) {
      lastError = error;
      continue;
    }
    succeeded++;
    for (final novel in novels) {
      if (seen.add(novel.title.trim())) {
        out.add(NovelSearchResult(novel: novel, sourceKey: sourceId));
      }
    }
  }
  if (succeeded == 0) {
    throw StateError('所有轻小说源搜索失败：$lastError');
  }
  return out;
});
