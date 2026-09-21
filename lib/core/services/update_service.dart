import 'package:dio/dio.dart';

class UpdateInfo {
  final String version;
  final String notes;
  final String url;

  const UpdateInfo({required this.version, required this.notes, required this.url});
}

/// Checks the project's public GitHub Releases for a newer version.
class UpdateService {
  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  static const owner = 'fantruekly';
  static const repo = 'Libiko--ACGNhub';

  final Dio _dio;

  Future<UpdateInfo?> check(String currentVersion) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/repos/$owner/$repo/releases/latest',
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    final data = response.data;
    if (data == null) return null;
    final latest = _normalize((data['tag_name'] ?? '').toString());
    if (latest == null || !isNewerVersion(currentVersion, latest)) return null;
    return UpdateInfo(
      version: latest,
      notes: (data['body'] ?? '').toString(),
      url: (data['html_url'] ?? '').toString(),
    );
  }

  /// True when [latest] is a strictly newer `major.minor.patch` than [current].
  static bool isNewerVersion(String current, String latest) {
    final a = _parse(current);
    final b = _parse(latest);
    if (a == null || b == null) return false;
    for (var i = 0; i < 3; i++) {
      if (b[i] != a[i]) return b[i] > a[i];
    }
    return false;
  }

  static String? _normalize(String tag) => _parse(tag) == null ? null : tag.replaceFirst(RegExp(r'^v'), '');

  static List<int>? _parse(String value) {
    final cleaned = value.trim().replaceFirst(RegExp(r'^v'), '').split('+').first;
    final parts = cleaned.split('.');
    if (parts.isEmpty) return null;
    final out = <int>[];
    for (var i = 0; i < 3; i++) {
      final part = i < parts.length ? parts[i] : '0';
      final n = int.tryParse(RegExp(r'^\d+').firstMatch(part)?.group(0) ?? '');
      if (n == null) return null;
      out.add(n);
    }
    return out;
  }
}
