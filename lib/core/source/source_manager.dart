import 'source_adapter.dart';
import '../models/work.dart';
import '../models/search_result.dart';

class SourceManager {
  final List<SourceAdapter> _adapters = [];

  List<SourceAdapter> get adapters => List.unmodifiable(_adapters);

  void register(SourceAdapter adapter) {
    if (_adapters.any((a) => a.id == adapter.id)) {
      throw ArgumentError('Source with id "${adapter.id}" already registered');
    }
    _adapters.add(adapter);
  }

  void remove(String sourceId) {
    _adapters.removeWhere((a) => a.id == sourceId);
  }

  List<SourceAdapter> getByType(WorkType type) {
    return _adapters.where((a) => a.type == type).toList();
  }

  SourceAdapter? getById(String sourceId) {
    try {
      return _adapters.firstWhere((a) => a.id == sourceId);
    } catch (_) {
      return null;
    }
  }

  Future<List<SearchResult>> searchAll(
    WorkType type,
    String keyword, {
    int page = 1,
  }) async {
    final adapters = getByType(type);
    if (adapters.isEmpty) return [];

    final results = await Future.wait(
      adapters.map((a) => a.search(keyword, page: page)),
    );
    return results;
  }
}