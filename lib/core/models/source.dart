import 'work.dart';

class SourceInfo {
  final String id;
  final String name;
  final WorkType type;
  final String baseUrl;
  final String? description;

  const SourceInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    this.description,
  });
}
