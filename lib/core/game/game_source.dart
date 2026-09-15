import 'models.dart';

abstract class GameSource {
  String get id;
  String get name;
  String get baseUrl;

  /// 该源声明的浏览分区（首页顶部 chip）。
  List<GameBrowseOption> get browseOptions;

  /// 按分区选项分页拉取。
  Future<GameList> browse(String optionKey, {int page = 1});

  /// 详情。
  Future<GameDetail> detail(String id);

  /// 关键词搜索（仅第一页）。
  Future<List<Game>> search(String keyword);
}

class GameSourceManager {
  GameSourceManager({List<GameSource>? sources}) {
    for (final s in sources ?? const <GameSource>[]) {
      register(s);
    }
  }

  final List<GameSource> _sources = [];

  List<GameSource> get sources => List.unmodifiable(_sources);

  void register(GameSource source) {
    if (_sources.any((s) => s.id == source.id)) {
      throw ArgumentError('duplicate game source id: ${source.id}');
    }
    _sources.add(source);
  }

  GameSource? byId(String id) {
    for (final s in _sources) {
      if (s.id == id) return s;
    }
    return null;
  }
}
