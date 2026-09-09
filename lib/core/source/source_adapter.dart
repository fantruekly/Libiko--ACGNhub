import '../models/work.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';
import '../models/source.dart';

abstract class SourceAdapter {
  String get id;
  String get name;
  WorkType get type;
  String get baseUrl;

  SourceInfo get info => SourceInfo(
        id: id,
        name: name,
        type: type,
        baseUrl: baseUrl,
      );

  Future<SearchResult> search(String keyword, {int page = 1});
  Future<Work> fetchDetail(String workId);
  Future<List<Chapter>> fetchChapters(String workId);
  Future<dynamic> fetchContent(String chapterId);
}