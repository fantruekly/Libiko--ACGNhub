import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/source/source_adapter.dart';
import 'package:acgnhub/core/source/source_manager.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/models/chapter.dart';
import 'package:acgnhub/core/models/search_result.dart';

class _MockAdapter extends SourceAdapter {
  @override
  String get id => 'mock';
  @override
  String get name => 'Mock';
  @override
  WorkType get type => WorkType.anime;
  @override
  String get baseUrl => 'https://mock.com';

  @override
  Future<SearchResult> search(String keyword, {int page = 1}) async {
    return SearchResult(works: [], totalPages: 0, currentPage: 1);
  }

  @override
  Future<Work> fetchDetail(String workId) async {
    return Work(
        id: workId, sourceId: id, sourceName: name, type: type, title: 'Mock');
  }

  @override
  Future<List<Chapter>> fetchChapters(String workId) async => [];
  @override
  Future<dynamic> fetchContent(String chapterId) async => null;
}

void main() {
  group('SourceManager', () {
    test('register and getByType', () {
      final manager = SourceManager();
      final adapter = _MockAdapter();
      manager.register(adapter);
      expect(manager.getByType(WorkType.anime).length, 1);
      expect(manager.getByType(WorkType.comic), isEmpty);
    });

    test('duplicate registration throws', () {
      final manager = SourceManager();
      manager.register(_MockAdapter());
      expect(() => manager.register(_MockAdapter()), throwsArgumentError);
    });

    test('remove source', () {
      final manager = SourceManager();
      manager.register(_MockAdapter());
      manager.remove('mock');
      expect(manager.adapters, isEmpty);
    });

    test('getById', () {
      final manager = SourceManager();
      manager.register(_MockAdapter());
      expect(manager.getById('mock')?.id, 'mock');
      expect(manager.getById('nonexistent'), isNull);
    });
  });
}
