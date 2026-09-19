import 'dart:convert';

import 'package:dio/dio.dart';

import 'cancellation.dart';
import 'source_rule.dart';
import 'video_source.dart';

/// The body encoding used by an API-mode request.
class ApiBodyType {
  static const String none = 'none';
  static const String json = 'json';
  static const String form = 'form';

  static String normalize(Object? value) {
    switch (value) {
      case json:
        return json;
      case form:
        return form;
      default:
        return none;
    }
  }
}

/// The response shape used by an API-mode chapter rule.
class ApiChapterFormat {
  static const String nested = 'nested';
  static const String delimited = 'delimited';

  static String normalize(Object? value) =>
      value == delimited ? delimited : nested;
}

/// A Kazumi API-mode request: an HTTP method, a URL template, headers, query
/// parameters and an optional body, all rendered with `@variable` tokens.
class ApiRequestConfig {
  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, String> query;
  final String bodyType;
  final String body;

  const ApiRequestConfig({
    this.method = 'GET',
    this.url = '',
    this.headers = const {},
    this.query = const {},
    this.bodyType = ApiBodyType.none,
    this.body = '',
  });

  factory ApiRequestConfig.fromJson(Map<String, dynamic> json) {
    return ApiRequestConfig(
      method: (json['method'] as String? ?? 'GET').toUpperCase(),
      url: json['url'] as String? ?? '',
      headers: _stringMap(json['headers']),
      query: _stringMap(json['query']),
      bodyType: ApiBodyType.normalize(json['bodyType']),
      body: _bodyString(json['body']),
    );
  }
}

/// Maps a JSON search response into [VideoItem]s.
class ApiSearchConfig {
  final ApiRequestConfig request;
  final String listPath;
  final String namePath;
  final String sourcePath;

  const ApiSearchConfig({
    this.request = const ApiRequestConfig(),
    this.listPath = r'$.data[*]',
    this.namePath = r'$.name',
    this.sourcePath = r'$.url',
  });

  factory ApiSearchConfig.fromJson(Map<String, dynamic> json) {
    return ApiSearchConfig(
      request: ApiRequestConfig.fromJson(_stringKeyMap(json['request'])),
      listPath: json['listPath'] as String? ?? r'$.data[*]',
      namePath: json['namePath'] as String? ?? r'$.name',
      sourcePath: json['sourcePath'] as String? ?? r'$.url',
    );
  }
}

/// Maps a JSON chapter response into [VideoEpisode]s, either from a nested
/// structure or from separator-delimited strings.
class ApiChapterConfig {
  final ApiRequestConfig request;
  final String format;

  final String roadsPath;
  final String roadNamePath;
  final String episodesPath;
  final String episodeNamePath;
  final String episodeUrlPath;

  final String roadNamesPath;
  final String roadEpisodesPath;

  final String roadSeparator;
  final String episodeSeparator;
  final String fieldSeparator;

  final String episodePageUrl;
  final Map<String, String> episodePageQuery;

  const ApiChapterConfig({
    this.request = const ApiRequestConfig(),
    this.format = ApiChapterFormat.nested,
    this.roadsPath = r'$.data.roads[*]',
    this.roadNamePath = r'$.name',
    this.episodesPath = r'$.episodes[*]',
    this.episodeNamePath = r'$.name',
    this.episodeUrlPath = r'$.url',
    this.roadNamesPath = '',
    this.roadEpisodesPath = '',
    this.roadSeparator = r'$$$',
    this.episodeSeparator = '#',
    this.fieldSeparator = r'$',
    this.episodePageUrl = '',
    this.episodePageQuery = const {},
  });

  factory ApiChapterConfig.fromJson(Map<String, dynamic> json) {
    return ApiChapterConfig(
      request: ApiRequestConfig.fromJson(_stringKeyMap(json['request'])),
      format: ApiChapterFormat.normalize(json['format']),
      roadsPath: json['roadsPath'] as String? ?? r'$.data.roads[*]',
      roadNamePath: json['roadNamePath'] as String? ?? r'$.name',
      episodesPath: json['episodesPath'] as String? ?? r'$.episodes[*]',
      episodeNamePath: json['episodeNamePath'] as String? ?? r'$.name',
      episodeUrlPath: json['episodeUrlPath'] as String? ?? r'$.url',
      roadNamesPath: json['roadNamesPath'] as String? ?? '',
      roadEpisodesPath: json['roadEpisodesPath'] as String? ?? '',
      roadSeparator: json['roadSeparator'] as String? ?? r'$$$',
      episodeSeparator: json['episodeSeparator'] as String? ?? '#',
      fieldSeparator: json['fieldSeparator'] as String? ?? r'$',
      episodePageUrl: _episodePageUrl(json['episodePage']),
      episodePageQuery: _episodePageQuery(json['episodePage']),
    );
  }
}

/// Reads every value matched by the restricted JSONPath [path] from [root].
///
/// Supported grammar: `$`, `.field`, `[n]` and `[*]`. Anything else yields an
/// empty list so a malformed rule simply produces no results.
List<dynamic> jsonPathAll(dynamic root, String path) {
  final expression = path.trim();
  if (expression.isEmpty || !expression.startsWith(r'$')) return const [];

  var current = <dynamic>[root];
  var index = 1;
  while (index < expression.length) {
    final char = expression[index];
    if (char == '.') {
      index++;
      final start = index;
      while (index < expression.length && _fieldChar.hasMatch(expression[index])) {
        index++;
      }
      if (index == start) return const [];
      final field = expression.substring(start, index);
      current = [
        for (final value in current)
          if (value is Map && value.containsKey(field)) value[field],
      ];
      continue;
    }
    if (char == '[') {
      final end = expression.indexOf(']', index);
      if (end < 0) return const [];
      final content = expression.substring(index + 1, end).trim();
      if (content == '*') {
        current = [
          for (final value in current)
            if (value is List) ...value,
        ];
      } else {
        final position = int.tryParse(content);
        if (position == null || position < 0) return const [];
        current = [
          for (final value in current)
            if (value is List && position < value.length) value[position],
        ];
      }
      index = end + 1;
      continue;
    }
    return const [];
  }
  return current;
}

final RegExp _fieldChar = RegExp(r'[A-Za-z0-9_$-]');

/// Replaces every `@key` in [template] with the matching value from [vars].
///
/// Longer keys are substituted first so `@episodeIndex` is not clobbered by an
/// `@episode` variable. Unknown tokens are left untouched.
String resolveEpisodeUrl(String template, Map<String, String> vars) {
  if (vars.isEmpty || !template.contains('@')) return template;
  final keys = vars.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  var result = template;
  for (final key in keys) {
    result = result.replaceAll('@$key', vars[key] ?? '');
  }
  return result;
}

/// A `dio`-backed client that runs a [SourceRule]'s API-mode search and
/// chapter requests.
class ApiRuleClient {
  final SourceRule rule;
  final Dio _dio;

  ApiRuleClient(this.rule, {Dio? dio}) : _dio = dio ?? Dio();

  Future<List<VideoItem>> search(String keyword,
      {CancellationToken? cancel}) async {
    if (cancel?.isCancelled ?? false) return const [];
    final raw = rule.searchApiConfig;
    if (raw == null) return const [];
    final config = ApiSearchConfig.fromJson(raw);
    final variables = <String, String>{
      'keyword': keyword,
      'baseUrl': rule.baseUrl,
    };
    final document = await _send(config.request, variables);
    if (cancel?.isCancelled ?? false) return const [];
    final items = <VideoItem>[];
    for (final node in jsonPathAll(document, config.listPath)) {
      final title = _firstString(jsonPathAll(node, config.namePath));
      final source = _firstString(jsonPathAll(node, config.sourcePath));
      if (title.isEmpty || source.isEmpty) continue;
      final url = _resolveUrl(source, rule.baseUrl);
      items.add(VideoItem(id: url, title: title, detailUrl: url));
    }
    return items;
  }

  Future<List<VideoEpisode>> episodes(String detailUrl,
      {CancellationToken? cancel}) async {
    if (cancel?.isCancelled ?? false) return const [];
    final raw = rule.chapterApiConfig;
    if (raw == null) return const [];
    final config = ApiChapterConfig.fromJson(raw);
    final variables = <String, String>{
      'source': detailUrl,
      'baseUrl': rule.baseUrl,
    };
    final document = await _send(config.request, variables);
    if (cancel?.isCancelled ?? false) return const [];
    return config.format == ApiChapterFormat.delimited
        ? _parseDelimited(document, config, variables)
        : _parseNested(document, config, variables);
  }

  List<VideoEpisode> _parseNested(
    dynamic document,
    ApiChapterConfig config,
    Map<String, String> rootVariables,
  ) {
    final hasRoads = config.roadsPath.trim().isNotEmpty;
    final roads =
        hasRoads ? jsonPathAll(document, config.roadsPath) : <dynamic>[document];
    final episodes = <VideoEpisode>[];
    final multipleRoads = roads.length > 1;
    for (var roadIndex = 0; roadIndex < roads.length; roadIndex++) {
      final road = roads[roadIndex];
      final roadName = multipleRoads && config.roadNamePath.trim().isNotEmpty
          ? _firstString(jsonPathAll(road, config.roadNamePath))
          : '';
      var roadEpisodeIndex = 0;
      for (final node in jsonPathAll(road, config.episodesPath)) {
        final name = _firstString(jsonPathAll(node, config.episodeNamePath));
        final rawUrl = config.episodeUrlPath.trim().isEmpty
            ? ''
            : _firstString(jsonPathAll(node, config.episodeUrlPath));
        final url = _episodeUrl(
          config,
          rootVariables,
          rawUrl: rawUrl,
          roadIndex: roadIndex,
          episodeIndex: roadEpisodeIndex,
        );
        if (url.isEmpty) continue;
        final title =
            (multipleRoads && roadName.isNotEmpty && name.isNotEmpty)
                ? '$roadName $name'
                : name;
        episodes.add(_episode(
          url,
          title,
          episodes.length,
        ));
        roadEpisodeIndex++;
      }
    }
    return episodes;
  }

  List<VideoEpisode> _parseDelimited(
    dynamic document,
    ApiChapterConfig config,
    Map<String, String> rootVariables,
  ) {
    final roadNames = _firstString(jsonPathAll(document, config.roadNamesPath))
        .split(config.roadSeparator);
    final groups = _firstString(jsonPathAll(document, config.roadEpisodesPath))
        .split(config.roadSeparator);
    final episodes = <VideoEpisode>[];
    for (var roadIndex = 0; roadIndex < groups.length; roadIndex++) {
      final roadName =
          roadIndex < roadNames.length ? roadNames[roadIndex].trim() : '';
      final entries = groups[roadIndex].split(config.episodeSeparator);
      var roadEpisodeIndex = 0;
      for (final raw in entries) {
        final entry = raw.trim();
        if (entry.isEmpty) continue;
        final split = entry.indexOf(config.fieldSeparator);
        if (split < 0) continue;
        final name = entry.substring(0, split).trim();
        final rawUrl =
            entry.substring(split + config.fieldSeparator.length).trim();
        final url = _episodeUrl(
          config,
          rootVariables,
          rawUrl: rawUrl,
          roadIndex: roadIndex,
          episodeIndex: roadEpisodeIndex,
        );
        if (url.isEmpty) continue;
        final title =
            (groups.length > 1 && roadName.isNotEmpty) ? '$roadName $name' : name;
        episodes.add(_episode(url, title, episodes.length));
        roadEpisodeIndex++;
      }
    }
    return episodes;
  }

  VideoEpisode _episode(String url, String name, int index) => VideoEpisode(
        id: url,
        title: name.isEmpty ? '第${index + 1}集' : name,
        index: index,
        playUrl: url,
        userAgent: rule.userAgent,
        referer: rule.referer,
        useLegacyParser: rule.useLegacyParser,
      );

  String _episodeUrl(
    ApiChapterConfig config,
    Map<String, String> rootVariables, {
    required String rawUrl,
    required int roadIndex,
    required int episodeIndex,
  }) {
    if (config.episodePageUrl.trim().isEmpty) {
      return _resolveUrl(rawUrl, rule.baseUrl);
    }
    final variables = <String, String>{
      ...rootVariables,
      'episodeUrl': rawUrl,
      'roadIndex': '$roadIndex',
      'roadNumber': '${roadIndex + 1}',
      'episodeIndex': '$episodeIndex',
      'episodeNumber': '${episodeIndex + 1}',
    };
    var url = resolveEpisodeUrl(config.episodePageUrl, variables);
    if (config.episodePageQuery.isNotEmpty) {
      final query = config.episodePageQuery.entries
          .map((e) => '${resolveEpisodeUrl(e.key, variables)}='
              '${resolveEpisodeUrl(e.value, variables)}')
          .join('&');
      url = '$url${url.contains('?') ? '&' : '?'}$query';
    }
    return _resolveUrl(url, rule.baseUrl);
  }

  Future<dynamic> _send(
    ApiRequestConfig config,
    Map<String, String> variables,
  ) async {
    final url = _resolveUrl(
      resolveEpisodeUrl(config.url, variables),
      rule.baseUrl,
    );
    final headers = config.headers.map(
      (key, value) =>
          MapEntry(resolveEpisodeUrl(key, variables), resolveEpisodeUrl(value, variables)),
    );
    final query = config.query.map(
      (key, value) =>
          MapEntry(resolveEpisodeUrl(key, variables), resolveEpisodeUrl(value, variables)),
    );
    final response = await _dio.request<dynamic>(
      url,
      data: _body(config, variables),
      queryParameters: query,
      options: Options(method: config.method, headers: headers),
    );
    return _decode(response.data);
  }

  dynamic _body(ApiRequestConfig config, Map<String, String> variables) {
    if (config.method.toUpperCase() != 'POST' ||
        config.bodyType == ApiBodyType.none ||
        config.body.isEmpty) {
      return null;
    }
    final body = resolveEpisodeUrl(config.body, variables);
    if (config.bodyType == ApiBodyType.json) {
      try {
        return jsonDecode(body);
      } catch (_) {
        return body;
      }
    }
    return body;
  }

  dynamic _decode(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  static String _firstString(List<dynamic> values) {
    if (values.isEmpty) return '';
    final value = values.first;
    if (value == null) return '';
    return value is String ? value.trim() : value.toString().trim();
  }

  static String _resolveUrl(String url, String base) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (trimmed.startsWith('/')) return '$root$trimmed';
    return '$root/$trimmed';
  }
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item?.toString() ?? ''));
}

Map<String, dynamic> _stringKeyMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _bodyString(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  return jsonEncode(value);
}

String _episodePageUrl(Object? value) {
  if (value is Map) return value['url'] as String? ?? '';
  return '';
}

Map<String, String> _episodePageQuery(Object? value) {
  if (value is Map) return _stringMap(value['query']);
  return const {};
}
