import '../models/work.dart';

enum AnimeFeed { trending, season, today }

abstract class MetadataProvider {
  String get id;
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1});
  Future<List<Work>> search(String keyword, {int page = 1});
  Future<Work> detail(Work work);
}
