import '../models/work.dart';
import '../models/search_result.dart';
import '../source/source_manager.dart';

class SearchEngine {
  final SourceManager _sourceManager;

  SearchEngine(this._sourceManager);

  Future<List<SearchResult>> search(
    WorkType type,
    String keyword, {
    int page = 1,
  }) async {
    if (keyword.trim().isEmpty) return [];
    return _sourceManager.searchAll(type, keyword, page: page);
  }

  Future<List<Work>> getAggregatedResults(
    WorkType type,
    String keyword, {
    int page = 1,
  }) async {
    final results = await search(type, keyword, page: page);
    final seen = <String>{};
    final aggregated = <Work>[];
    for (final result in results) {
      for (final work in result.works) {
        if (seen.add(work.id)) {
          aggregated.add(work);
        }
      }
    }
    return aggregated;
  }
}