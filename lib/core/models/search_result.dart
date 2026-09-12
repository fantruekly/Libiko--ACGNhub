import 'work.dart';

class SearchResult {
  final List<Work> works;
  final int totalPages;
  final int currentPage;
  final bool hasMore;

  const SearchResult({
    required this.works,
    required this.totalPages,
    required this.currentPage,
  }) : hasMore = currentPage < totalPages;
}
