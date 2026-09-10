# Phase 1: Anime Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the ACGNhub Flutter app with core infrastructure and a working anime module (XPath rule engine + video player).

**Architecture:** Single Flutter app with core layer (models, services, source adapter framework) and anime module (XPathAdapter, video player, UI pages). The core layer is designed to be extended by Phase 2-4 modules.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod (state), dio (HTTP), media_kit (video), isar (DB), html + xml (XPath), cached_network_image, flutter_cache_manager

## Global Constraints

- Target platform: Windows first (Android later, after all 4 phases complete on Windows)
- No danmaku (bullet comments) functionality
- Development on `dev` branch, PR merge to `main` after user acceptance
- Commit messages follow `feat(module): description` format
- Follow existing code conventions (Dart/Flutter standard)

---

### Task 1: Scaffold Flutter project

**Files:**
- Create: entire Flutter project structure via `flutter create`

**Interfaces:**
- Produces: Standard Flutter project with `lib/main.dart`, `pubspec.yaml`, `test/`, `windows/`

- [ ] **Step 1: Create Flutter project**

```bash
cd D:\ACGNhub
flutter create --org com.acgnhub --project-name acgnhub .
```

- [ ] **Step 2: Configure pubspec.yaml with dependencies**

Replace the generated `pubspec.yaml` with:

```yaml
name: acgnhub
description: ACGNhub - Anime, Comic, Game, Novel aggregation app
publish_to: 'none'
version: 0.1.0

environment:
  sdk: '>=3.6.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  dio: ^5.7.0
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0
  flutter_cache_manager: ^3.4.1
  media_kit: ^1.2.0
  media_kit_video: ^1.2.0
  media_kit_libs_windows_video: ^1.0.9
  html: ^0.15.5
  xml: ^6.5.0
  cached_network_image: ^3.4.1
  shared_preferences: ^2.3.4
  path_provider: ^2.1.5
  path: ^1.9.0
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/rules/
```

- [ ] **Step 3: Create assets directory**

```bash
mkdir -p assets\rules
```

- [ ] **Step 4: Run flutter pub get**

```bash
flutter pub get
```

- [ ] **Step 5: Verify project builds**

```bash
flutter build windows --debug
```

Expected: Build succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter project with dependencies"
```

---

### Task 2: Create core data models

**Files:**
- Create: `lib/core/models/work.dart`
- Create: `lib/core/models/chapter.dart`
- Create: `lib/core/models/source.dart`
- Create: `lib/core/models/search_result.dart`
- Create: `test/core/models/work_test.dart`

**Interfaces:**
- Produces: `Work`, `Chapter`, `SourceInfo`, `SearchResult` classes with `fromJson`/`toJson`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p lib\core\models
mkdir -p test\core\models
```

- [ ] **Step 2: Write Work model**

Create `lib/core/models/work.dart`:

```dart
enum WorkType { anime, comic, novel, game }

class Work {
  final String id;
  final String sourceId;
  final String sourceName;
  final WorkType type;
  final String title;
  final String? coverUrl;
  final String? summary;
  final List<String> tags;
  final String? author;
  final Map<String, dynamic> extra;

  const Work({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.type,
    required this.title,
    this.coverUrl,
    this.summary,
    this.tags = const [],
    this.author,
    this.extra = const {},
  });

  factory Work.fromJson(Map<String, dynamic> json) => Work(
        id: json['id'] as String,
        sourceId: json['sourceId'] as String,
        sourceName: json['sourceName'] as String,
        type: WorkType.values.byName(json['type'] as String),
        title: json['title'] as String,
        coverUrl: json['coverUrl'] as String?,
        summary: json['summary'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        author: json['author'] as String?,
        extra: json['extra'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'sourceName': sourceName,
        'type': type.name,
        'title': title,
        'coverUrl': coverUrl,
        'summary': summary,
        'tags': tags,
        'author': author,
        'extra': extra,
      };
}
```

- [ ] **Step 3: Write Chapter model**

Create `lib/core/models/chapter.dart`:

```dart
class Chapter {
  final String id;
  final String workId;
  final String title;
  final int index;
  final String? url;
  final Map<String, dynamic> extra;

  const Chapter({
    required this.id,
    required this.workId,
    required this.title,
    required this.index,
    this.url,
    this.extra = const {},
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: json['id'] as String,
        workId: json['workId'] as String,
        title: json['title'] as String,
        index: json['index'] as int,
        url: json['url'] as String?,
        extra: json['extra'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workId': workId,
        'title': title,
        'index': index,
        'url': url,
        'extra': extra,
      };
}
```

- [ ] **Step 4: Write SourceInfo model**

Create `lib/core/models/source.dart`:

```dart
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
```

- [ ] **Step 5: Write SearchResult model**

Create `lib/core/models/search_result.dart`:

```dart
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
```

- [ ] **Step 6: Write tests**

Create `test/core/models/work_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/models/work.dart';

void main() {
  group('Work', () {
    test('fromJson and toJson roundtrip', () {
      final json = {
        'id': 'test_1',
        'sourceId': 'src_1',
        'sourceName': 'TestSource',
        'type': 'anime',
        'title': 'Test Anime',
        'coverUrl': 'https://example.com/cover.jpg',
        'summary': 'A test anime',
        'tags': ['action', 'comedy'],
        'author': 'Test Author',
        'extra': {'year': 2024},
      };
      final work = Work.fromJson(json);
      expect(work.toJson(), json);
    });

    test('default values', () {
      final work = Work(
        id: '1',
        sourceId: 's1',
        sourceName: 'S',
        type: WorkType.anime,
        title: 'T',
      );
      expect(work.tags, isEmpty);
      expect(work.extra, isEmpty);
      expect(work.coverUrl, isNull);
    });
  });
}
```

- [ ] **Step 7: Run tests**

```bash
flutter test test/core/models/work_test.dart
```

Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/core/models/ test/core/models/
git commit -m "feat(core): add data models Work, Chapter, SourceInfo, SearchResult"
```

---

### Task 3: Create SourceAdapter interface and SourceManager

**Files:**
- Create: `lib/core/source/source_adapter.dart`
- Create: `lib/core/source/source_manager.dart`
- Create: `test/core/source/source_manager_test.dart`

**Interfaces:**
- Consumes: `Work`, `Chapter`, `SearchResult`, `SourceInfo`, `WorkType` from Task 2
- Produces: `SourceAdapter` abstract class, `SourceManager` class

- [ ] **Step 1: Create directory**

```bash
mkdir -p lib\core\source
mkdir -p test\core\source
```

- [ ] **Step 2: Write SourceAdapter interface**

Create `lib/core/source/source_adapter.dart`:

```dart
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
```

- [ ] **Step 3: Write SourceManager**

Create `lib/core/source/source_manager.dart`:

```dart
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
```

- [ ] **Step 4: Write tests**

Create `test/core/source/source_manager_test.dart`:

```dart
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
    return Work(id: workId, sourceId: id, sourceName: name, type: type, title: 'Mock');
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
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/core/source/source_manager_test.dart
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/source/ test/core/source/
git commit -m "feat(core): add SourceAdapter interface and SourceManager"
```

---

### Task 4: Create HttpClient service

**Files:**
- Create: `lib/core/services/http_client.dart`

**Interfaces:**
- Consumes: `dio` package
- Produces: `HttpClient` class with `get`, `post`, `getHtml` methods

- [ ] **Step 1: Create directory**

```bash
mkdir -p lib\core\services
```

- [ ] **Step 2: Write HttpClient**

Create `lib/core/services/http_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class HttpClient {
  static final HttpClient _instance = HttpClient._();
  factory HttpClient() => _instance;
  HttpClient._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    },
  ));

  Future<Response> get(String url, {Map<String, String>? headers}) async {
    return _dio.get(url, options: Options(headers: headers));
  }

  Future<Response> post(String url, {dynamic data, Map<String, String>? headers}) async {
    return _dio.post(url, data: data, options: Options(headers: headers));
  }

  Future<dom.Document> getHtml(String url, {Map<String, String>? headers}) async {
    final response = await get(url, headers: headers);
    return html_parser.parse(response.data.toString());
  }

  void setCookie(String url, String name, String value) {
    _dio.options.headers['Cookie'] = '$name=$value';
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/
git commit -m "feat(core): add HttpClient service with dio"
```

---

### Task 5: Create CacheManager and Database

**Files:**
- Create: `lib/core/services/cache_manager.dart`
- Create: `lib/core/storage/database.dart`

**Interfaces:**
- Consumes: `flutter_cache_manager`, `isar`, `path_provider`
- Produces: `AppCacheManager`, `AppDatabase` classes

- [ ] **Step 1: Create directories**

```bash
mkdir -p lib\core\storage
```

- [ ] **Step 2: Write AppCacheManager**

Create `lib/core/services/cache_manager.dart`:

```dart
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'acgnhub_cache';

  static final AppCacheManager _instance = AppCacheManager._();
  factory AppCacheManager() => _instance;
  AppCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 500,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ));
}
```

- [ ] **Step 3: Write AppDatabase**

Create `lib/core/storage/database.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

class AppDatabase {
  static AppDatabase? _instance;
  late final SharedPreferences _prefs;

  AppDatabase._();

  static Future<AppDatabase> init() async {
    if (_instance != null) return _instance!;
    _instance = AppDatabase._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  factory AppDatabase() {
    if (_instance == null) {
      throw StateError('AppDatabase not initialized. Call AppDatabase.init() first.');
    }
    return _instance!;
  }

  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  List<String> getStringList(String key) => _prefs.getStringList(key) ?? [];
  Future<bool> setStringList(String key, List<String> value) => _prefs.setStringList(key, value);

  Future<bool> remove(String key) => _prefs.remove(key);
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/cache_manager.dart lib/core/storage/
git commit -m "feat(core): add AppCacheManager and AppDatabase"
```

---

### Task 6: Create FavoriteManager and SearchEngine

**Files:**
- Create: `lib/core/services/favorite_manager.dart`
- Create: `lib/core/services/search_engine.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 5), `SourceManager` (Task 3), `Work`, `WorkType` (Task 2)
- Produces: `FavoriteManager`, `SearchEngine` classes

- [ ] **Step 1: Write FavoriteManager**

Create `lib/core/services/favorite_manager.dart`:

```dart
import 'dart:convert';
import '../models/work.dart';
import '../storage/database.dart';

class FavoriteManager {
  static const _key = 'favorites';

  List<Work> getFavorites({WorkType? type}) {
    final jsonList = AppDatabase().getStringList(_key);
    final works = jsonList.map((j) => Work.fromJson(json.decode(j) as Map<String, dynamic>)).toList();
    if (type != null) {
      return works.where((w) => w.type == type).toList();
    }
    return works;
  }

  Future<void> addFavorite(Work work) async {
    final favorites = getFavorites();
    if (favorites.any((w) => w.id == work.id)) return;
    favorites.add(work);
    await _save(favorites);
  }

  Future<void> removeFavorite(String workId) async {
    final favorites = getFavorites();
    favorites.removeWhere((w) => w.id == workId);
    await _save(favorites);
  }

  bool isFavorite(String workId) {
    return getFavorites().any((w) => w.id == workId);
  }

  Future<void> _save(List<Work> works) async {
    final jsonList = works.map((w) => json.encode(w.toJson())).toList();
    await AppDatabase().setStringList(_key, jsonList);
  }
}
```

- [ ] **Step 2: Write SearchEngine**

Create `lib/core/services/search_engine.dart`:

```dart
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/favorite_manager.dart lib/core/services/search_engine.dart
git commit -m "feat(core): add FavoriteManager and SearchEngine"
```

---

### Task 7: Create common UI widgets

**Files:**
- Create: `lib/core/widgets/work_card.dart`
- Create: `lib/core/widgets/loading_widget.dart`
- Create: `lib/core/widgets/error_widget.dart`

**Interfaces:**
- Consumes: `Work` (Task 2), `cached_network_image`
- Produces: `WorkCard`, `AppLoadingWidget`, `AppErrorWidget` widgets

- [ ] **Step 1: Create directory**

```bash
mkdir -p lib\core\widgets
```

- [ ] **Step 2: Write WorkCard widget**

Create `lib/core/widgets/work_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/work.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onTap;
  final double width;
  final double imageHeight;

  const WorkCard({
    super.key,
    required this.work,
    this.onTap,
    this.width = 150,
    this.imageHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: width,
                height: imageHeight,
                child: work.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: work.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.grey[800]),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.image, color: Colors.grey, size: 48),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              work.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (work.sourceName.isNotEmpty)
              Text(
                work.sourceName,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Write LoadingWidget and ErrorWidget**

Create `lib/core/widgets/loading_widget.dart`:

```dart
import 'package:flutter/material.dart';

class AppLoadingWidget extends StatelessWidget {
  final String? message;
  const AppLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}
```

Create `lib/core/widgets/error_widget.dart`:

```dart
import 'package:flutter/material.dart';

class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/
git commit -m "feat(core): add common UI widgets WorkCard, LoadingWidget, ErrorWidget"
```

---

### Task 8: Create XPath rule model and parser

**Files:**
- Create: `lib/modules/anime/anime_rule.dart`
- Create: `test/modules/anime/anime_rule_test.dart`

**Interfaces:**
- Consumes: `xml`, `html` packages
- Produces: `AnimeRule` model with JSON parsing, `XPathParser` utility class

- [ ] **Step 1: Create directories**

```bash
mkdir -p lib\modules\anime
mkdir -p test\modules\anime
```

- [ ] **Step 2: Write AnimeRule model**

Create `lib/modules/anime/anime_rule.dart`:

```dart
import 'dart:convert';

class RuleSection {
  final String url;
  final String list;
  final String title;
  final String cover;
  final String link;
  final String? nextPage;

  const RuleSection({
    required this.url,
    required this.list,
    required this.title,
    required this.cover,
    required this.link,
    this.nextPage,
  });

  factory RuleSection.fromJson(Map<String, dynamic> json) => RuleSection(
        url: json['url'] as String,
        list: json['list'] as String,
        title: json['title'] as String,
        cover: json['cover'] as String,
        link: json['link'] as String,
        nextPage: json['nextPage'] as String?,
      );
}

class DetailRule {
  final String summary;
  final String? tags;
  final String? cover;
  final String? author;
  final String chapters;
  final String chapterTitle;
  final String chapterLink;

  const DetailRule({
    required this.summary,
    this.tags,
    this.cover,
    this.author,
    required this.chapters,
    required this.chapterTitle,
    required this.chapterLink,
  });

  factory DetailRule.fromJson(Map<String, dynamic> json) => DetailRule(
        summary: json['summary'] as String,
        tags: json['tags'] as String?,
        cover: json['cover'] as String?,
        author: json['author'] as String?,
        chapters: json['chapters'] as String,
        chapterTitle: json['chapterTitle'] as String,
        chapterLink: json['chapterLink'] as String,
      );
}

class VideoRule {
  final String playUrl;
  final String? resolutions;

  const VideoRule({required this.playUrl, this.resolutions});

  factory VideoRule.fromJson(Map<String, dynamic> json) => VideoRule(
        playUrl: json['playUrl'] as String,
        resolutions: json['resolutions'] as String?,
      );
}

class AnimeRule {
  final String name;
  final String baseUrl;
  final RuleSection search;
  final DetailRule detail;
  final VideoRule video;

  const AnimeRule({
    required this.name,
    required this.baseUrl,
    required this.search,
    required this.detail,
    required this.video,
  });

  factory AnimeRule.fromJson(Map<String, dynamic> json) => AnimeRule(
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        search: RuleSection.fromJson(json['search'] as Map<String, dynamic>),
        detail: DetailRule.fromJson(json['detail'] as Map<String, dynamic>),
        video: VideoRule.fromJson(json['video'] as Map<String, dynamic>),
      );

  factory AnimeRule.fromJsonString(String jsonString) {
    return AnimeRule.fromJson(json.decode(jsonString) as Map<String, dynamic>);
  }

  String toJsonString() {
    return json.encode({
      'name': name,
      'baseUrl': baseUrl,
      'search': {
        'url': search.url,
        'list': search.list,
        'title': search.title,
        'cover': search.cover,
        'link': search.link,
        if (search.nextPage != null) 'nextPage': search.nextPage,
      },
      'detail': {
        'summary': detail.summary,
        if (detail.tags != null) 'tags': detail.tags,
        if (detail.cover != null) 'cover': detail.cover,
        if (detail.author != null) 'author': detail.author,
        'chapters': detail.chapters,
        'chapterTitle': detail.chapterTitle,
        'chapterLink': detail.chapterLink,
      },
      'video': {
        'playUrl': video.playUrl,
        if (video.resolutions != null) 'resolutions': video.resolutions,
      },
    });
  }
}

class XPathParser {
  /// Extract text from HTML node using XPath-like selector.
  /// Supports: //tag[@attr='value']/text(), .//tag/text(), //tag/@attr
  static String? extractText(
    dynamic node,
    String xpath,
  ) {
    if (node == null) return null;
    // Use xml package for XPath evaluation
    return null; // Stub - implemented in Task 9
  }

  /// Find all nodes matching XPath selector
  static List<dynamic> findNodes(dynamic root, String xpath) {
    // Stub - implemented in Task 9
    return [];
  }
}
```

- [ ] **Step 3: Write tests**

Create `test/modules/anime/anime_rule_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/modules/anime/anime_rule.dart';

void main() {
  group('AnimeRule', () {
    final json = {
      'name': 'TestSource',
      'baseUrl': 'https://test.com',
      'search': {
        'url': '/search?keyword={keyword}&page={page}',
        'list': '//div[@class="list"]/div',
        'title': './/h3/text()',
        'cover': './/img/@src',
        'link': './/a/@href',
      },
      'detail': {
        'summary': '//div[@class="desc"]/text()',
        'tags': '//span[@class="tag"]/text()',
        'chapters': '//ul[@class="ep"]/li',
        'chapterTitle': './/a/text()',
        'chapterLink': './/a/@href',
      },
      'video': {
        'playUrl': '//video/source/@src',
        'resolutions': '//select[@class="res"]/option/@value',
      },
    };

    test('fromJson parses correctly', () {
      final rule = AnimeRule.fromJson(json);
      expect(rule.name, 'TestSource');
      expect(rule.baseUrl, 'https://test.com');
      expect(rule.search.title, './/h3/text()');
      expect(rule.detail.summary, '//div[@class="desc"]/text()');
      expect(rule.video.playUrl, '//video/source/@src');
    });

    test('toJsonString and fromJsonString roundtrip', () {
      final rule = AnimeRule.fromJson(json);
      final rule2 = AnimeRule.fromJsonString(rule.toJsonString());
      expect(rule2.name, rule.name);
      expect(rule2.baseUrl, rule.baseUrl);
    });

    test('optional fields are null when missing', () {
      final minimalJson = {
        'name': 'Minimal',
        'baseUrl': 'https://min.com',
        'search': {
          'url': '/s',
          'list': '//div',
          'title': './/h3/text()',
          'cover': './/img/@src',
          'link': './/a/@href',
        },
        'detail': {
          'summary': '//div/text()',
          'chapters': '//li',
          'chapterTitle': './/a/text()',
          'chapterLink': './/a/@href',
        },
        'video': {
          'playUrl': '//video/@src',
        },
      };
      final rule = AnimeRule.fromJson(minimalJson);
      expect(rule.search.nextPage, isNull);
      expect(rule.detail.tags, isNull);
      expect(rule.video.resolutions, isNull);
    });
  });
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/modules/anime/anime_rule_test.dart
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/anime/anime_rule.dart test/modules/anime/anime_rule_test.dart
git commit -m "feat(anime): add AnimeRule model and XPathParser stub"
```

---

### Task 9: Implement XPathParser and AnimeSource adapter

**Files:**
- Modify: `lib/modules/anime/anime_rule.dart` (implement XPathParser)
- Create: `lib/modules/anime/anime_source.dart`
- Create: `test/modules/anime/anime_source_test.dart`

**Interfaces:**
- Consumes: `AnimeRule`, `XPathParser` (Task 8), `SourceAdapter` (Task 3), `HttpClient` (Task 4), `Work`, `Chapter`, `SearchResult` (Task 2)
- Produces: `AnimeSource` class implementing `SourceAdapter`

- [ ] **Step 1: Implement XPathParser**

Replace the stub methods in `lib/modules/anime/anime_rule.dart` with real implementations.

Modify the `XPathParser` class in `lib/modules/anime/anime_rule.dart`:

```dart
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart' as xml;

class XPathParser {
  static String? extractText(dynamic node, String xpath) {
    if (node == null) return null;
    if (xpath.endsWith('/text()')) {
      final attrXpath = xpath.replaceAll('/text()', '');
      final attr = _extractAttribute(node, attrXpath);
      if (attr != null) return attr;
    }
    if (xpath.startsWith('@')) {
      return _extractAttribute(node, xpath);
    }
    if (xpath.endsWith('/@src')) {
      final attrPath = xpath;
      return _extractAttribute(node, attrPath);
    }
    if (xpath.endsWith('/@href')) {
      return _extractAttribute(node, xpath);
    }
    final found = _findNode(node, xpath);
    if (found != null) {
      if (found is dom.Element) {
        return found.text.trim();
      }
    }
    if (node is dom.Element) {
      return node.text.trim();
    }
    return null;
  }

  static String? _extractAttribute(dynamic node, String xpath) {
    if (node is dom.Element) {
      if (xpath.contains('/@src')) {
        return node.attributes['src'];
      }
      if (xpath.contains('/@href')) {
        return node.attributes['href'];
      }
      if (xpath.startsWith('@')) {
        final attrName = xpath.substring(1);
        return node.attributes[attrName];
      }
    }
    return null;
  }

  static List<dom.Element> findNodes(dynamic root, String xpath) {
    if (root == null) return [];
    if (root is dom.Document) {
      return _queryAll(root, xpath);
    }
    if (root is dom.Element) {
      return _queryAll(root, xpath);
    }
    return [];
  }

  static List<dom.Element> _queryAll(dynamic parent, String xpath) {
    final results = <dom.Element>[];
    String selector = xpath;

    // Handle relative selectors starting with .//
    if (selector.startsWith('.//')) {
      selector = selector.substring(1);
    }

    // Handle //tag[@attr='value']/child pattern
    if (selector.startsWith('//')) {
      selector = selector.substring(2);
    }

    // Simple tag-only selector
    if (!selector.contains('[') && !selector.contains('/')) {
      if (parent is dom.Element) {
        results.addAll(parent.querySelectorAll(selector));
      }
      if (parent is dom.Document) {
        results.addAll(parent.querySelectorAll(selector));
      }
      return results;
    }

    // Tag with attribute filter: tag[@attr='value']
    final attrMatch = RegExp(r"^(\w+)\[@(\w+)='([^']*)'\]$").firstMatch(selector);
    if (attrMatch != null) {
      final tag = attrMatch.group(1)!;
      final attr = attrMatch.group(2)!;
      final value = attrMatch.group(3)!;
      if (parent is dom.Element) {
        results.addAll(parent.querySelectorAll(tag).where((e) => e.attributes[attr] == value));
      }
      if (parent is dom.Document) {
        results.addAll(parent.querySelectorAll(tag).where((e) => e.attributes[attr] == value));
      }
      return results;
    }

    // Nested: tag[@attr='value']/child
    final nestedMatch = RegExp(r"^(\w+)\[@(\w+)='([^']*)'\]/(\w+)$").firstMatch(selector);
    if (nestedMatch != null) {
      final parentTag = nestedMatch.group(1)!;
      final parentAttr = nestedMatch.group(2)!;
      final parentValue = nestedMatch.group(3)!;
      final childTag = nestedMatch.group(4)!;
      List<dom.Element> parents;
      if (parent is dom.Element) {
        parents = parent.querySelectorAll(parentTag).where((e) => e.attributes[parentAttr] == parentValue).toList();
      } else if (parent is dom.Document) {
        parents = parent.querySelectorAll(parentTag).where((e) => e.attributes[parentAttr] == parentValue).toList();
      } else {
        return [];
      }
      for (final p in parents) {
        results.addAll(p.querySelectorAll(childTag));
      }
      return results;
    }

    return results;
  }
}
```

- [ ] **Step 2: Write AnimeSource adapter**

Create `lib/modules/anime/anime_source.dart`:

```dart
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/source/source_adapter.dart';
import '../../core/models/work.dart';
import '../../core/models/chapter.dart';
import '../../core/models/search_result.dart';
import '../../core/services/http_client.dart';
import 'anime_rule.dart';

class AnimeSource extends SourceAdapter {
  final AnimeRule rule;
  final HttpClient _http = HttpClient();
  final _uuid = const Uuid();

  AnimeSource(this.rule);

  @override
  String get id => 'anime_${rule.name.hashCode}';

  @override
  String get name => rule.name;

  @override
  WorkType get type => WorkType.anime;

  @override
  String get baseUrl => rule.baseUrl;

  String _buildUrl(String template, {String keyword = '', int page = 1}) {
    return template
        .replaceAll('{keyword}', Uri.encodeComponent(keyword))
        .replaceAll('{page}', page.toString());
  }

  @override
  Future<SearchResult> search(String keyword, {int page = 1}) async {
    final url = baseUrl + _buildUrl(rule.search.url, keyword: keyword, page: page);
    final document = await _http.getHtml(url);
    final nodes = XPathParser.findNodes(document, rule.search.list);

    final works = <Work>[];
    for (final node in nodes) {
      final title = XPathParser.extractText(node, rule.search.title) ?? '';
      final cover = XPathParser.extractText(node, rule.search.cover);
      final link = XPathParser.extractText(node, rule.search.link) ?? '';
      if (title.isEmpty) continue;

      final workId = link.replaceAll(RegExp(r'[^\w]'), '_');
      works.add(Work(
        id: '$id-$workId',
        sourceId: id,
        sourceName: name,
        type: WorkType.anime,
        title: title,
        coverUrl: cover != null ? _resolveUrl(cover) : null,
        extra: {'link': link},
      ));
    }

    return SearchResult(
      works: works,
      totalPages: works.isEmpty ? 1 : page + 1,
      currentPage: page,
    );
  }

  @override
  Future<Work> fetchDetail(String workId) async {
    final link = ''; // Extract from workId or fetch from search
    final url = baseUrl + link;
    final document = await _http.getHtml(url);

    final summary = XPathParser.extractText(document, rule.detail.summary) ?? '';
    final tagsText = rule.detail.tags != null ? XPathParser.extractText(document, rule.detail.tags!) : null;
    final coverUrl = rule.detail.cover != null ? XPathParser.extractText(document, rule.detail.cover!) : null;
    final author = rule.detail.author != null ? XPathParser.extractText(document, rule.detail.author!) : null;

    return Work(
      id: workId,
      sourceId: id,
      sourceName: name,
      type: WorkType.anime,
      title: '', // Will be filled from the page
      coverUrl: coverUrl != null ? _resolveUrl(coverUrl) : null,
      summary: summary,
      tags: tagsText?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList() ?? [],
      author: author,
      extra: {'link': link},
    );
  }

  @override
  Future<List<Chapter>> fetchChapters(String workId) async {
    final link = ''; // Extract from workId or fetch
    final url = baseUrl + link;
    final document = await _http.getHtml(url);
    final nodes = XPathParser.findNodes(document, rule.detail.chapters);

    final chapters = <Chapter>[];
    for (var i = 0; i < nodes.length; i++) {
      final title = XPathParser.extractText(nodes[i], rule.detail.chapterTitle) ?? '第${i + 1}集';
      final chLink = XPathParser.extractText(nodes[i], rule.detail.chapterLink) ?? '';
      chapters.add(Chapter(
        id: '$workId-ch$i',
        workId: workId,
        title: title,
        index: i,
        url: chLink,
      ));
    }
    return chapters;
  }

  @override
  Future<String?> fetchContent(String chapterId) async {
    // Extract the actual video URL
    // For now, return the chapter URL directly
    // The video player will handle the actual stream extraction
    return null;
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$url';
    }
    return '$baseUrl/$url';
  }
}
```

- [ ] **Step 3: Write tests**

Create `test/modules/anime/anime_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/modules/anime/anime_rule.dart';
import 'package:acgnhub/modules/anime/anime_source.dart';

void main() {
  group('AnimeSource', () {
    final rule = AnimeRule.fromJson({
      'name': 'TestSource',
      'baseUrl': 'https://test.com',
      'search': {
        'url': '/search?keyword={keyword}&page={page}',
        'list': '//div[@class="list"]/div',
        'title': './/h3/text()',
        'cover': './/img/@src',
        'link': './/a/@href',
      },
      'detail': {
        'summary': '//div[@class="desc"]/text()',
        'chapters': '//ul[@class="ep"]/li',
        'chapterTitle': './/a/text()',
        'chapterLink': './/a/@href',
      },
      'video': {
        'playUrl': '//video/source/@src',
      },
    });

    test('source has correct properties', () {
      final source = AnimeSource(rule);
      expect(source.type, WorkType.anime);
      expect(source.name, 'TestSource');
      expect(source.baseUrl, 'https://test.com');
    });

    test('_resolveUrl resolves relative paths', () {
      final source = AnimeSource(rule);
      expect(source._resolveUrl('http://example.com/img.jpg'), 'http://example.com/img.jpg');
      expect(source._resolveUrl('//cdn.com/img.jpg'), 'https://cdn.com/img.jpg');
      expect(source._resolveUrl('/img.jpg'), 'https://test.com/img.jpg');
    });

    test('_buildUrl replaces placeholders', () {
      final source = AnimeSource(rule);
      final url = source._buildUrl('/search?keyword={keyword}&page={page}', keyword: 'test', page: 2);
      expect(url, '/search?keyword=test&page=2');
    });
  });
}
```

Note: The `_resolveUrl` and `_buildUrl` methods need to be public for testing. Add `@visibleForTesting` annotations or make them public.

To fix, modify `anime_source.dart` to make these methods public:

```dart
  @visibleForTesting
  String resolveUrl(String url) { ... }

  @visibleForTesting
  String buildUrl(String template, {String keyword = '', int page = 1}) { ... }
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/modules/anime/anime_source_test.dart
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/anime/ test/modules/anime/
git commit -m "feat(anime): implement XPathParser and AnimeSource adapter"
```

---

### Task 10: Create first built-in anime rule

**Files:**
- Create: `assets/rules/yhdm.json`

**Interfaces:**
- Produces: A working built-in anime source rule

- [ ] **Step 1: Write built-in rule**

Create `assets/rules/yhdm.json` (樱花的动漫 - a commonly available source):

```json
{
  "name": "樱花动漫",
  "baseUrl": "https://www.yhdmp.cc",
  "search": {
    "url": "/s_all?ex=1&kw={keyword}&page={page}",
    "list": "//ul[@id='list_li']/li",
    "title": ".//a/@title",
    "cover": ".//img/@src",
    "link": ".//a/@href"
  },
  "detail": {
    "summary": "//div[@class='info']/text()",
    "tags": "//div[@class='sinfo']/span/text()",
    "cover": "//img[@class='pic']/@src",
    "chapters": "//ul[@id='playlist']/li[contains(@class,'episode')]",
    "chapterTitle": ".//a/text()",
    "chapterLink": ".//a/@href"
  },
  "video": {
    "playUrl": "//iframe[@id='playbox']/@src",
    "resolutions": "//select[@class='res']/option/@value"
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add assets/rules/yhdm.json
git commit -m "feat(anime): add built-in anime source rule"
```

---

### Task 11: Create anime home page with Riverpod

**Files:**
- Create: `lib/modules/anime/anime_providers.dart`
- Create: `lib/modules/anime/anime_home.dart`

**Interfaces:**
- Consumes: `SourceManager` (Task 3), `AnimeSource` (Task 9), `WorkCard` (Task 7)
- Produces: `animeSourceListProvider`, `AnimeHomePage` widget

- [ ] **Step 1: Write providers**

Create `lib/modules/anime/anime_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/source/source_manager.dart';
import '../../core/models/work.dart';
import 'anime_source.dart';
import 'anime_rule.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

final sourceManagerProvider = Provider<SourceManager>((ref) {
  return SourceManager();
});

final animeSourceListProvider = FutureProvider<List<AnimeSource>>((ref) async {
  final manager = ref.read(sourceManagerProvider);

  // Load built-in rules
  final manifest = await rootBundle.loadString('AssetManifest.json');
  final ruleFiles = <String>[];
  if (manifest.contains('assets/rules/')) {
    final lines = manifest.split('\n');
    for (final line in lines) {
      if (line.contains('assets/rules/') && line.contains('.json')) {
        final key = line.split('"')[1];
        if (key != null) ruleFiles.add(key);
      }
    }
  }

  // Load default rule if no files found in manifest
  for (final file in ruleFiles) {
    final jsonString = await rootBundle.loadString(file);
    final rule = AnimeRule.fromJsonString(jsonString);
    final source = AnimeSource(rule);
    manager.register(source);
  }

  return manager.getByType(WorkType.anime).cast<AnimeSource>();
});
```

- [ ] **Step 2: Write AnimeHomePage**

Create `lib/modules/anime/anime_home.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';

class AnimeHomePage extends ConsumerWidget {
  const AnimeHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(animeSourceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('动漫'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnimeSearchPage()),
              );
            },
          ),
        ],
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
        data: (sources) {
          if (sources.isEmpty) {
            return const Center(child: Text('没有可用的动漫源'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(animeSourceListProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '已加载的动漫源',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...sources.map((s) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.tv),
                        title: Text(s.name),
                        subtitle: Text(s.baseUrl),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    )),
                const SizedBox(height: 24),
                const Text(
                  '使用搜索查找你想看的动漫',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AnimeSearchPage extends StatelessWidget {
  const AnimeSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索动漫')),
      body: const Center(child: Text('搜索功能开发中')),
    );
  }
}
```

- [ ] **Step 3: Run build to verify**

```bash
flutter build windows --debug
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/anime/
git commit -m "feat(anime): add anime home page with Riverpod providers"
```

---

### Task 12: Create anime search and detail pages

**Files:**
- Create: `lib/modules/anime/anime_search.dart`
- Create: `lib/modules/anime/anime_detail.dart`

**Interfaces:**
- Consumes: `SourceManager`, `SearchEngine`, `AnimeSource`, `WorkCard` (Tasks 3, 6, 7, 9)
- Produces: `AnimeSearchPage`, `AnimeDetailPage` widgets

- [ ] **Step 1: Write AnimeSearchPage**

Create `lib/modules/anime/anime_search.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/work.dart';
import '../../core/services/search_engine.dart';
import '../../core/widgets/work_card.dart';
import 'anime_providers.dart';
import 'anime_detail.dart';

class AnimeSearchPage extends ConsumerStatefulWidget {
  const AnimeSearchPage({super.key});

  @override
  ConsumerState<AnimeSearchPage> createState() => _AnimeSearchPageState();
}

class _AnimeSearchPageState extends ConsumerState<AnimeSearchPage> {
  final _controller = TextEditingController();
  final _searchEngine = SearchEngine(SourceManager());
  List<Work> _results = [];
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final manager = ref.read(sourceManagerProvider);
      final engine = SearchEngine(manager);
      final results = await engine.getAggregatedResults(WorkType.anime, keyword);
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索动漫...',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _search, child: const Text('重试')),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? const Center(child: Text('输入关键词搜索动漫'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final work = _results[index];
                        return WorkCard(
                          work: work,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnimeDetailPage(work: work),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
}
```

- [ ] **Step 2: Write AnimeDetailPage**

Create `lib/modules/anime/anime_detail.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/work.dart';
import '../../core/models/chapter.dart';
import 'anime_player.dart';

class AnimeDetailPage extends StatefulWidget {
  final Work work;

  const AnimeDetailPage({super.key, required this.work});

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  List<Chapter> _chapters = [];
  bool _loadingChapters = false;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() => _loadingChapters = true);
    try {
      // TODO: Fetch chapters from source in Task 13
      setState(() => _loadingChapters = false);
    } catch (e) {
      setState(() => _loadingChapters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    return Scaffold(
      appBar: AppBar(title: Text(work.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (work.coverUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: work.coverUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[900]),
                  errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(work.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (work.author != null)
                    Text('作者: ${work.author}', style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(height: 4),
                  Text('来源: ${work.sourceName}', style: TextStyle(color: Colors.grey[500])),
                  if (work.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: work.tags.map((tag) => Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                    ),
                  ],
                  if (work.summary != null && work.summary!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(work.summary!, style: const TextStyle(fontSize: 14, height: 1.5)),
                  ],
                  const SizedBox(height: 24),
                  const Text('剧集列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_loadingChapters)
                    const Center(child: CircularProgressIndicator())
                  else if (_chapters.isEmpty)
                    const Text('暂无剧集信息', style: TextStyle(color: Colors.grey))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _chapters.length,
                      itemBuilder: (context, index) {
                        final ch = _chapters[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(ch.title),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnimePlayerPage(
                                  chapterTitle: ch.title,
                                  videoUrl: ch.url ?? '',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update anime_home.dart to use the new search page**

Replace the inline `AnimeSearchPage` stub in `lib/modules/anime/anime_home.dart` with an import:

```dart
import 'anime_search.dart';
```

Remove the stub `AnimeSearchPage` class from `anime_home.dart`.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/anime/
git commit -m "feat(anime): add search and detail pages"
```

---

### Task 13: Create video player page

**Files:**
- Create: `lib/modules/anime/anime_player.dart`

**Interfaces:**
- Consumes: `media_kit`, `media_kit_video`, `media_kit_libs_windows_video`
- Produces: `AnimePlayerPage` widget with video playback controls

- [ ] **Step 1: Write AnimePlayerPage**

Create `lib/modules/anime/anime_player.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class AnimePlayerPage extends StatefulWidget {
  final String chapterTitle;
  final String videoUrl;

  const AnimePlayerPage({
    super.key,
    required this.chapterTitle,
    required this.videoUrl,
  });

  @override
  State<AnimePlayerPage> createState() => _AnimePlayerPageState();
}

class _AnimePlayerPageState extends State<AnimePlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _isReady = false;
  bool _showControls = true;
  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.open(Media(widget.videoUrl));
      setState(() => _isReady = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _changeSpeed() {
    final currentIndex = _speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _speeds.length;
    setState(() {
      _playbackSpeed = _speeds[nextIndex];
    });
    _player.setRate(_playbackSpeed);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.chapterTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(
              child: _isReady
                  ? Video(controller: _controller)
                  : const CircularProgressIndicator(color: Colors.white),
            ),
            if (_showControls && _isReady)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fast_rewind, color: Colors.white),
                        onPressed: () => _player.seek(
                          _player.state.position - const Duration(seconds: 10),
                        ),
                      ),
                      StreamBuilder(
                        stream: _player.stream.playing,
                        builder: (context, snapshot) {
                          final playing = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              playing ? Icons.pause_circle : Icons.play_circle,
                              color: Colors.white,
                              size: 48,
                            ),
                            onPressed: () => _player.playOrPause(),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.fast_forward, color: Colors.white),
                        onPressed: () => _player.seek(
                          _player.state.position + const Duration(seconds: 10),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _changeSpeed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white54),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/modules/anime/anime_player.dart
git commit -m "feat(anime): add video player page with playback controls"
```

---

### Task 14: Create app shell and main entry point

**Files:**
- Create: `lib/shell/main_shell.dart`
- Create: `lib/shell/settings_page.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AnimeHomePage` (Task 11), `AppDatabase` (Task 5)
- Produces: `MainShell` with bottom navigation, `main.dart` entry point

- [ ] **Step 1: Create directories**

```bash
mkdir -p lib\shell
```

- [ ] **Step 2: Write SettingsPage**

Create `lib/shell/settings_page.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/storage/database.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader(title: '缓存'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清除图片缓存'),
            onTap: () async {
              // TODO: Clear cache
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清除')),
                );
              }
            },
          ),
          const Divider(),
          const _SectionHeader(title: '关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('ACGNhub'),
            subtitle: Text('v0.1.0 - 动漫聚合应用'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Write MainShell**

Create `lib/shell/main_shell.dart`:

```dart
import 'package:flutter/material.dart';
import '../modules/anime/anime_home.dart';
import 'settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = <Widget>[
    const AnimeHomePage(),
    const _PlaceholderPage(title: '漫画', icon: Icons.menu_book, message: '漫画模块将在阶段2实现'),
    const _PlaceholderPage(title: '轻小说', icon: Icons.auto_stories, message: '轻小说模块将在阶段3实现'),
    const _PlaceholderPage(title: '游戏', icon: Icons.games, message: '游戏模块将在阶段4实现'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv),
            label: '动漫',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '漫画',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '轻小说',
          ),
          NavigationDestination(
            icon: Icon(Icons.games_outlined),
            selectedIcon: Icon(Icons.games),
            label: '游戏',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const _PlaceholderPage({
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write main.dart**

Replace the content of `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'core/storage/database.dart';
import 'shell/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await AppDatabase.init();
  runApp(const ProviderScope(child: ACGNhubApp()));
}

class ACGNhubApp extends StatelessWidget {
  const ACGNhubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACGNhub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      home: const MainShell(),
    );
  }
}
```

- [ ] **Step 5: Build and verify**

```bash
flutter build windows --debug
```

Expected: Build succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/shell/ lib/main.dart
git commit -m "feat(shell): add MainShell with bottom navigation and app entry point"
```

---

### Task 15: Integration test and final verification

**Files:**
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: All previous tasks
- Produces: Working app with navigation

- [ ] **Step 1: Update widget test**

Replace `test/widget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acgnhub/main.dart';

void main() {
  testWidgets('App launches with bottom navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ACGNhubApp()));
    await tester.pumpAndSettle();

    expect(find.text('动漫'), findsWidgets);
    expect(find.text('漫画'), findsWidgets);
    expect(find.text('轻小说'), findsWidgets);
    expect(find.text('游戏'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run all tests**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Run the app**

```bash
flutter run -d windows
```

Expected: App launches with dark theme, 4-tab navigation, anime home page showing loaded sources.

- [ ] **Step 4: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: add integration test for app shell"
```

---

## Phase 1 Completion Checklist

- [ ] App launches on Windows
- [ ] Bottom navigation with 4 tabs (动漫, 漫画, 轻小说, 游戏)
- [ ] 动漫 tab shows loaded sources
- [ ] 动漫 search page accepts input and searches
- [ ] 动漫 detail page shows work info
- [ ] 动漫 video player plays video with controls
- [ ] Placeholder pages for comic, novel, game tabs
- [ ] Settings page accessible
- [ ] All tests pass