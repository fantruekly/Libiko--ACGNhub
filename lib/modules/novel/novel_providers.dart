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
