import '../video/video_source.dart';
import '../video/rule_source.dart';
import '../video/cancellation.dart';
import '../novel/novel_source.dart';
import '../novel/models.dart';
import '../game/game_source.dart';
import '../game/models.dart';
import 'source_preferences.dart';

class ManagedVideoSource implements VideoSource {
  ManagedVideoSource(this.source, this.health);
  final VideoSource source;
  final SourceHealthRepository health;
  @override
  String get id => source.id;
  @override
  String get name => source.name;
  @override
  String get baseUrl => source.baseUrl;
  @override
  Future<List<VideoItem>> search(String keyword, {CancellationToken? cancel}) {
    final delegate = source;
    if (delegate is RuleVideoSource && delegate.hasCachedSearch(keyword)) {
      return delegate.search(keyword, cancel: cancel);
    }
    return health.track(
        SourceKind.anime, id, () => source.search(keyword, cancel: cancel),
        cancelled: () => cancel?.isCancelled == true);
  }

  @override
  Future<List<VideoEpisode>> episodes(String detailUrl,
      {CancellationToken? cancel}) {
    final delegate = source;
    if (delegate is RuleVideoSource && delegate.hasCachedEpisodes(detailUrl)) {
      return delegate.episodes(detailUrl, cancel: cancel);
    }
    return health.track(
        SourceKind.anime, id, () => source.episodes(detailUrl, cancel: cancel),
        cancelled: () => cancel?.isCancelled == true);
  }
}

class ManagedNovelSource implements NovelSource {
  ManagedNovelSource(this.source, this.health);
  final NovelSource source;
  final SourceHealthRepository health;
  @override
  String get id => source.id;
  @override
  String get name => source.name;
  @override
  String get baseUrl => source.baseUrl;
  @override
  List<NovelBrowseGroup> get browseGroups => source.browseGroups;
  @override
  Future<NovelHome> home() => health.track(SourceKind.novel, id, source.home);
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) => health.track(
      SourceKind.novel, id, () => source.browse(optionKey, page: page));
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) => health.track(
      SourceKind.novel, id, () => source.search(keyword, page: page));
  @override
  Future<NovelDetail> detail(String id) =>
      health.track(SourceKind.novel, this.id, () => source.detail(id));
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) => health
      .track(SourceKind.novel, id, () => source.chapter(novelId, chapterId));
}

class ManagedGameSource implements GameSource {
  ManagedGameSource(this.source, this.health);
  final GameSource source;
  final SourceHealthRepository health;
  @override
  String get id => source.id;
  @override
  String get name => source.name;
  @override
  String get baseUrl => source.baseUrl;
  @override
  List<GameBrowseOption> get browseOptions => source.browseOptions;
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) => health.track(
      SourceKind.game, id, () => source.browse(optionKey, page: page));
  @override
  Future<GameDetail> detail(String id) =>
      health.track(SourceKind.game, this.id, () => source.detail(id));
  @override
  Future<List<Game>> search(String keyword) =>
      health.track(SourceKind.game, id, () => source.search(keyword));
}
