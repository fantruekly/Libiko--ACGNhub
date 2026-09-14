import 'models.dart';

abstract class NovelSource {
  String get id;
  String get name;
  String get baseUrl;

  /// 首页：若干带标题的书单。
  Future<NovelHome> home();

  /// 该源声明的浏览分组（每个分组含若干选项）。
  List<NovelBrowseGroup> get browseGroups;

  /// 按浏览选项分页拉取书单。
  Future<NovelList> browse(String optionKey, {int page = 1});

  // v1 仅声明，后续实现：
  Future<List<Novel>> search(String keyword, {int page = 1});
  Future<NovelDetail> detail(String id);
  Future<NovelChapter> chapter(String novelId, String chapterId);
}

class NovelSourceManager {
  NovelSourceManager({List<NovelSource>? sources}) {
    for (final s in sources ?? const <NovelSource>[]) {
      register(s);
    }
  }

  final List<NovelSource> _sources = [];

  List<NovelSource> get sources => List.unmodifiable(_sources);

  void register(NovelSource source) {
    if (_sources.any((s) => s.id == source.id)) {
      throw ArgumentError('duplicate novel source id: ${source.id}');
    }
    _sources.add(source);
  }

  NovelSource? byId(String id) {
    for (final s in _sources) {
      if (s.id == id) return s;
    }
    return null;
  }
}
