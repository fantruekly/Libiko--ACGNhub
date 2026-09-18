import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storage/database.dart';
import 'builtin_sources.dart';
import 'explore_result.dart';
import 'js_engine.dart';
import 'models.dart';

class ComicSourceSection {
  final String title;
  final String type;
  final bool usesLoadNext;

  const ComicSourceSection(
      {required this.title, required this.type, this.usesLoadNext = false});
}

/// One group of category options from a source's `categoryComics.optionList`.
///
/// [showWhen] / [notShowWhen] name the categories the group applies to; a null
/// list means "no restriction" for that side.
class ComicCategoryOptionGroup {
  final List<String> options;
  final List<String>? showWhen;
  final List<String>? notShowWhen;

  const ComicCategoryOptionGroup(
      {required this.options, this.showWhen, this.notShowWhen});

  bool visibleFor(String category) =>
      (showWhen == null || showWhen!.contains(category)) &&
      (notShowWhen == null || !notShowWhen!.contains(category));
}

class ComicSource {
  final String name;
  final String key;
  final String version;
  final String url;
  final String fileName;
  final String? description;
  final bool canSearch;
  final bool canExplore;
  final bool canLoadInfo;
  final bool canLoadEp;
  final bool canOnImageLoad;
  final List<ComicSourceSection> sections;
  final bool hasCategoryComics;
  final String categoryDefault;
  final String categoryParam;
  final List<String> categoryOptions;
  final List<ComicCategoryOptionGroup> categoryOptionGroups;
  final bool hasLogin;
  final bool hasCookieLogin;
  final List<String> cookieFields;

  const ComicSource({
    required this.name,
    required this.key,
    required this.version,
    this.url = '',
    this.fileName = '',
    this.description,
    this.canSearch = false,
    this.canExplore = false,
    this.canLoadInfo = false,
    this.canLoadEp = false,
    this.canOnImageLoad = false,
    this.sections = const [],
    this.hasCategoryComics = false,
    this.categoryDefault = '',
    this.categoryParam = '',
    this.categoryOptions = const [],
    this.categoryOptionGroups = const [],
    this.hasLogin = false,
    this.hasCookieLogin = false,
    this.cookieFields = const [],
  });

  static final _classRe =
      RegExp(r'class\s+(\w+)\s+extends\s+ComicSource\b');

  static String _classNameOf(String script) {
    final match = _classRe.firstMatch(script);
    if (match == null) {
      throw const FormatException('not a ComicSource script');
    }
    return match.group(1)!;
  }

  /// Parses source metadata from the script text. `flags` come from evaluating
  /// the script; the pure part (name/key/version) is testable on its own.
  static ComicSource fromMetadata(
    Map<dynamic, dynamic> meta, {
    String fileName = '',
    String url = '',
  }) {
    String req(String k) {
      final v = meta[k]?.toString();
      if (v == null || v.trim().isEmpty) {
        throw FormatException('comic source is missing "$k"');
      }
      return v.trim();
    }

    final category = meta['category'];
    final account = meta['account'];
    final defaultCategory = _categoryStr(category, 'category');
    final optionGroups = _categoryOptionGroups(category);
    final legacyOptions = _categoryList(category, 'options');

    return ComicSource(
      name: req('name'),
      key: req('key'),
      version: req('version'),
      url: meta['url']?.toString() ?? url,
      fileName: fileName,
      description: meta['description']?.toString(),
      canSearch: meta['search'] == true,
      canExplore: meta['explore'] == true,
      canLoadInfo: meta['loadInfo'] == true,
      canLoadEp: meta['loadEp'] == true,
      canOnImageLoad: meta['onImageLoad'] == true,
      sections: _sectionsFrom(meta['sections']),
      hasCategoryComics: _hasCategory(category),
      categoryDefault: defaultCategory,
      categoryParam: _categoryStr(category, 'param'),
      categoryOptionGroups: optionGroups,
      categoryOptions: optionGroups.isEmpty
          ? legacyOptions
          : _optionsFor(optionGroups, defaultCategory),
      hasLogin: account is Map && account['hasLogin'] == true,
      hasCookieLogin: account is Map && account['hasCookieLogin'] == true,
      cookieFields: account is Map && account['cookieFields'] is List
          ? (account['cookieFields'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }

  /// The default option value of every [categoryOptionGroups] group that applies
  /// to [category], in order. Falls back to the flat [categoryOptions] when the
  /// source supplied no per-group metadata.
  List<String> categoryOptionsFor(String category) => categoryOptionGroups.isEmpty
      ? categoryOptions
      : _optionsFor(categoryOptionGroups, category);

  static List<String> _optionsFor(
      List<ComicCategoryOptionGroup> groups, String category) =>
      [
        for (final group in groups)
          if (group.options.isNotEmpty && group.visibleFor(category))
            group.options.first.split('-').first,
      ];

  static List<ComicCategoryOptionGroup> _categoryOptionGroups(dynamic raw) {
    if (raw is! Map) return const [];
    final groups = raw['optionGroups'];
    if (groups is! List) return const [];
    return [
      for (final group in groups)
        if (group is Map)
          ComicCategoryOptionGroup(
            options: ((group['options'] as List?) ?? const [])
                .map((e) => e.toString())
                .toList(),
            showWhen:
                (group['showWhen'] as List?)?.map((e) => e.toString()).toList(),
            notShowWhen: (group['notShowWhen'] as List?)
                ?.map((e) => e.toString())
                .toList(),
          ),
    ];
  }

  static List<ComicSourceSection> _sectionsFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ComicSourceSection(
              title: e['title']?.toString() ?? '',
              type: e['type']?.toString() ?? '',
              usesLoadNext: e['usesLoadNext'] == true,
            ))
        .toList();
  }

  static bool _hasCategory(dynamic raw) => raw is Map && raw['hasComics'] == true;

  static String _categoryStr(dynamic raw, String key) =>
      raw is Map ? (raw[key]?.toString() ?? '') : '';

  static List<String> _categoryList(dynamic raw, String key) {
    if (raw is! Map) return const [];
    final list = raw[key];
    if (list is! List) return const [];
    return list.map((e) => e.toString()).toList();
  }

  /// Pure text check used by the parser tests and before evaluation.
  static void assertLooksLikeSource(String script) {
    if (!_classRe.hasMatch(script)) {
      throw const FormatException('not a ComicSource script');
    }
  }

  @visibleForTesting
  static ComicSource parseForTest(String script) {
    assertLooksLikeSource(script);
    // Minimal metadata extraction without a JS engine (test-only): pull the
    // string fields and the capability keys with regexes.
    String? str(String field) =>
        RegExp('$field\\s*=\\s*"([^"]*)"').firstMatch(script)?.group(1);
    final name = str('name');
    final key = str('key');
    final version = str('version');
    if (name == null || key == null || version == null) {
      throw const FormatException('missing name/key/version');
    }
    return ComicSource(
      name: name,
      key: key,
      version: version,
      url: str('url') ?? '',
      canSearch: RegExp(r'search\s*=\s*\{').hasMatch(script),
      canExplore: RegExp(r'explore\s*=\s*\[').hasMatch(script),
      canLoadInfo: RegExp(r'loadInfo\s*:').hasMatch(script),
      canLoadEp: RegExp(r'loadEp\s*:').hasMatch(script),
      canOnImageLoad: RegExp(r'onImageLoad\s*:').hasMatch(script),
    );
  }
}

/// A live, synchronous [Map] view over the app's [AppDatabase] preferences.
///
/// The JS bridge reads settings with `store[key]` and writes them with
/// `store[key] = value`; routing both through [AppDatabase] means
/// `loadSetting`/`saveSetting` round-trip against the same flat string store
/// used by the rest of the app.
class _DbSettings extends MapBase<String, String> {
  AppDatabase get _db => AppDatabase();

  @override
  String? operator [](Object? key) => _db.getString(key.toString());

  @override
  void operator []=(String key, String value) {
    unawaited(_db.setString(key, value));
  }

  @override
  Iterable<String> get keys => const [];

  @override
  String? remove(Object? key) {
    unawaited(_db.remove(key.toString()));
    return null;
  }

  @override
  void clear() {}
}

const _registryJs = r'''
globalThis.__libiko_sources = globalThis.__libiko_sources || {};
globalThis.__libiko_pending = globalThis.__libiko_pending || {};
// Pass 1: instantiate just enough to read the declared metadata, without
// calling init(). The manager allow-lists the key this returns before pass 2.
globalThis.__libiko_declareSource = function (cls) {
  const s = new cls();
  globalThis.__libiko_pending[s.key] = cls;
  return {
    name: s.name, key: s.key, version: s.version, url: s.url,
    description: s.description
  };
};
// Pass 2: instantiate, run init(), and register. The key is already allowed.
globalThis.__libiko_registerSource = function (key) {
  const cls = globalThis.__libiko_pending[key];
  if (!cls) throw new Error('comic source not declared: ' + key);
  const s = new cls();
  if (s.settings) s.__libiko_origSettings = Object.assign({}, s.settings);
  const finish = function () {
    globalThis.__libiko_sources[s.key] = s;
    delete globalThis.__libiko_pending[s.key];
    return {
      name: s.name, key: s.key, version: s.version, url: s.url,
      description: s.description,
      search: !!s.search, explore: !!s.explore,
      loadInfo: !!(s.comic && s.comic.loadInfo),
      loadEp: !!(s.comic && s.comic.loadEp),
      onImageLoad: !!(s.comic && s.comic.onImageLoad),
      sections: (Array.isArray(s.explore) ? s.explore : []).map(function (e) {
        return {
          title: e.title || '',
          type: e.type || '',
          usesLoadNext: typeof e.loadNext === 'function' && typeof e.load !== 'function'
        };
      }),
      category: (function () {
        const c = s.category;
        const cc = s.categoryComics;
        const parts = c && Array.isArray(c.parts) ? c.parts : [];
        const part = parts.length ? parts[0] : null;
        const cats = part && Array.isArray(part.categories) ? part.categories : [];
        const params = part && Array.isArray(part.categoryParams) ? part.categoryParams : [];
        const optList = cc && Array.isArray(cc.optionList) ? cc.optionList : [];
        const optionGroups = optList.map(function (o) {
          return {
            options: o && Array.isArray(o.options) ? o.options.map(String) : [],
            showWhen: o && Array.isArray(o.showWhen) ? o.showWhen.map(String) : null,
            notShowWhen: o && Array.isArray(o.notShowWhen) ? o.notShowWhen.map(String) : null
          };
        });
        return {
          hasComics: !!(cc && typeof cc.load === 'function'),
          category: cats.length ? String(cats[0]) : '',
          param: params.length ? String(params[0]) : '',
          optionGroups: optionGroups
        };
      })(),
      account: (function () {
        const a = s.account;
        const cw = a && a.loginWithCookies;
        return {
          hasLogin: !!(a && typeof a.login === 'function'),
          hasCookieLogin: !!(cw && typeof cw.validate === 'function'),
          cookieFields: cw && Array.isArray(cw.fields) ? cw.fields.map(String) : []
        };
      })()
    };
  };
  if (typeof s.init === 'function') {
    return Promise.resolve(s.init()).then(finish);
  }
  return finish();
};
globalThis.__libiko_instance = function (key) {
  const s = globalThis.__libiko_sources[key];
  if (!s) throw new Error('comic source not registered: ' + key);
  return Promise.resolve(s);
};
''';

class ComicSourceManager {
  ComicSourceManager({
    JsEngine? engine,
    Dio? dio,
    BuiltinSourceInstaller? builtinInstaller,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (_) => true,
            )),
        _builtinInstaller = builtinInstaller ?? BuiltinSourceInstaller() {
    _engine = engine ?? JsEngine(settings: _appSettings);
  }

  late final JsEngine _engine;
  final Dio _dio;
  final BuiltinSourceInstaller _builtinInstaller;
  final List<ComicSource> _sources = [];
  Future<void>? _initFuture;

  List<ComicSource> get sources => List.unmodifiable(_sources);

  static Map<String, String> _appSettings() => _DbSettings();

  Future<void> _ensureInitialized() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    _engine.installBridge();
    final lib = await rootBundle.loadString('assets/comic_source/init.js');
    await _engine.evaluate(lib);
    await _engine.evaluate(_registryJs);
  }

  static final _fileNameRe = RegExp(r'^[A-Za-z0-9_.-]+\.js$');
  static final _reservedNames = <String>{
    'CON', 'PRN', 'AUX', 'NUL',
    for (var i = 1; i <= 9; i++) 'COM$i',
    for (var i = 1; i <= 9; i++) 'LPT$i',
  };

  /// Reduces [raw] to a safe file name inside the source directory, rejecting
  /// anything that could escape it, that is not a `.js` file, or that is a
  /// Windows reserved device name (with or without an extension).
  String _safeFileName(String raw) {
    final name = p.basename(raw);
    if (!_fileNameRe.hasMatch(name)) {
      throw FormatException('invalid comic source file name: $raw');
    }
    final stem = name.split('.').first.toUpperCase();
    if (_reservedNames.contains(stem)) {
      throw FormatException('reserved comic source file name: $raw');
    }
    return name;
  }

  /// Resolves [raw] to a file inside the source directory, rejecting names that
  /// fail [_safeFileName] or that would escape the directory.
  File _sourceFile(Directory dir, String raw) {
    final name = _safeFileName(raw);
    final file = File(p.join(dir.path, name));
    if (!p.isWithin(dir.path, file.path)) {
      throw FormatException('source path escapes the source directory: $name');
    }
    return file;
  }

  Future<Directory> _dir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'comic_source'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> load() async {
    await _ensureInitialized();
    try {
      await _builtinInstaller.install();
    } catch (e) {
      debugPrint('[ComicSourceManager] builtin install failed: $e');
    }
    _sources.clear();
    await _engine.evaluate(
        'globalThis.__libiko_sources = {}; globalThis.__libiko_pending = {};');
    final dir = await _dir();
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.js')) continue;
      try {
        final source = await _evaluateSource(
            await entity.readAsString(), p.basename(entity.path));
        _sources.add(source);
      } catch (e) {
        debugPrint('[ComicSourceManager] skipped ${entity.path}: $e');
      }
    }
    _applyOrder(AppDatabase().getStringList(_orderKey));
  }

  static const _orderKey = 'comic_source_order';

  void _applyOrder(List<String> order) {
    if (order.isEmpty) return;
    _sources.sort((a, b) {
      final ia = order.indexOf(a.key);
      final ib = order.indexOf(b.key);
      if (ia == -1 && ib == -1) return 0;
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
  }

  Future<void> saveOrder(List<String> keys) async {
    await AppDatabase().setStringList(_orderKey, keys);
    _applyOrder(keys);
  }

  Future<ComicSource> _evaluateSource(String script, String fileName) async {
    ComicSource.assertLooksLikeSource(script);
    final className = ComicSource._classNameOf(script);
    // Evaluate inside an IIFE so the top-level `class` binding is
    // function-local. QuickJS keeps top-level lexical bindings in a persistent
    // global environment, so re-evaluating the same class would otherwise
    // throw `SyntaxError: redeclaration of '<Class>'`.
    //
    // Pass 1 declares the source (reading its metadata, not running `init()`)
    // and stashes its class under `__libiko_pending[key]`; pass 2 instantiates
    // it, runs `init()`, and registers it. Source settings are namespaced by a
    // fixed prefix (`source_setting.`), so no per-source allow-listing is
    // needed before `init()` runs.
    final declared = await _engine.evaluate('(function(){\n$script\n;'
        'return globalThis.__libiko_declareSource($className);\n})()');
    if (declared is! Map) throw const FormatException('source metadata missing');
    final key = declared['key']?.toString().trim() ?? '';
    if (key.isEmpty) throw const FormatException('comic source is missing "key"');
    try {
      final meta = await _engine.evaluate(
          'globalThis.__libiko_registerSource(${jsonEncode(key)})');
      if (meta is! Map) {
        throw const FormatException('source metadata missing');
      }
      return ComicSource.fromMetadata(meta, fileName: fileName);
    } catch (_) {
      try {
        await _engine.evaluate(
            'delete globalThis.__libiko_pending[${jsonEncode(key)}];');
      } catch (_) {
        // Best-effort cleanup; keep the original registration failure.
      }
      rethrow;
    }
  }

  Future<ComicSource> importFromUrl(String url) async {
    await _ensureInitialized();
    final response = await _dio.get<String>(url,
        options: Options(responseType: ResponseType.plain));
    final script = response.data ?? '';
    ComicSource.assertLooksLikeSource(script);
    final dir = await _dir();
    final file = _sourceFile(dir, Uri.parse(url).path);
    await file.writeAsString(script);
    final source = await _evaluateSource(script, p.basename(file.path));
    _sources.removeWhere((s) => s.key == source.key);
    _sources.add(source);
    return source;
  }

  Future<ComicSource> importFromFile(String path) async {
    await _ensureInitialized();
    final script = await File(path).readAsString();
    ComicSource.assertLooksLikeSource(script);
    final dir = await _dir();
    final file = _sourceFile(dir, path);
    await file.writeAsString(script);
    final source = await _evaluateSource(script, p.basename(file.path));
    _sources.removeWhere((s) => s.key == source.key);
    _sources.add(source);
    return source;
  }

  Future<ComicSource> refresh(ComicSource source) async {
    await _ensureInitialized();
    final dir = await _dir();
    final file = _sourceFile(dir, source.fileName);
    final String script;
    if (source.url.isNotEmpty) {
      final response = await _dio.get<String>(source.url,
          options: Options(responseType: ResponseType.plain));
      script = response.data ?? '';
      ComicSource.assertLooksLikeSource(script);
      await file.writeAsString(script);
    } else {
      if (!await file.exists()) {
        throw StateError('source file not found: ${source.fileName}');
      }
      script = await file.readAsString();
    }
    final refreshed = await _evaluateSource(script, p.basename(file.path));
    final index = _sources.indexWhere((s) => s.key == source.key);
    if (index >= 0) {
      _sources[index] = refreshed;
    } else {
      _sources.add(refreshed);
    }
    return refreshed;
  }

  Future<void> remove(ComicSource source) async {
    await _ensureInitialized();
    final dir = await _dir();
    final file = _sourceFile(dir, source.fileName);
    if (await file.exists()) await file.delete();
    await _engine.evaluate(
        'delete globalThis.__libiko_sources[${jsonEncode(source.key)}];');
    _sources.removeWhere((s) => s.key == source.key);
  }

  Future<List<Comic>> search(ComicSource source, String keyword,
      {int page = 1}) async {
    await _ensureInitialized();
    if (!source.canSearch) return const [];
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__libiko_instance(${jsonEncode(source.key)});
        return s.search.load(${jsonEncode(keyword)}, {}, $page);
      })()
    ''');
    return parseExploreResult(result).comics;
  }

  Future<ExplorePage> explore(ComicSource source, int sectionIndex,
      {int page = 1, String? cursor}) async {
    await _ensureInitialized();
    if (!source.canExplore) return const ExplorePage(comics: []);
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__libiko_instance(${jsonEncode(source.key)});
        const sec = (s.explore || [])[$sectionIndex];
        if (!sec) return { comics: [], maxPage: 1 };
        if (typeof sec.load === 'function') return await sec.load($page);
        if (typeof sec.loadNext === 'function') {
          return await sec.loadNext(${cursor == null ? 'undefined' : jsonEncode(cursor)});
        }
        return { comics: [], maxPage: 1 };
      })()
    ''');
    return parseExploreResult(result);
  }

  Future<ExplorePage> category(ComicSource source, int page,
      {String? category, String? param, List<String>? options}) async {
    await _ensureInitialized();
    if (!source.hasCategoryComics) return const ExplorePage(comics: []);
    final cat = category ?? source.categoryDefault;
    final par = param ?? source.categoryParam;
    final opts = options ?? source.categoryOptionsFor(cat);
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__libiko_instance(${jsonEncode(source.key)});
        if (!s.categoryComics || typeof s.categoryComics.load !== 'function') {
          return { comics: [], maxPage: 1 };
        }
        return await s.categoryComics.load(${jsonEncode(cat)}, ${jsonEncode(par)},
          ${jsonEncode(opts)}, $page);
      })()
    ''');
    return parseExploreResult(result);
  }

  Future<bool> login(
      ComicSource source, String username, String password) async {
    await _ensureInitialized();
    if (!source.hasLogin) return false;
    try {
      final ok = await _engine.evaluate('''
        (async () => {
          const s = await globalThis.__libiko_instance(${jsonEncode(source.key)});
          const result = await s.account.login(${jsonEncode(username)}, ${jsonEncode(password)});
          return result !== false;
        })()
      ''');
      if (ok == true) {
        await AppDatabase()
            .setString('source_data.${source.key}.username', username);
        await AppDatabase()
            .setString('source_data.${source.key}.logged_in', '1');
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> loginWithCookies(
      ComicSource source, List<String> values) async {
    await _ensureInitialized();
    if (!source.hasCookieLogin) return false;
    try {
      final ok = await _engine.evaluate('''
        (async () => {
          const s = await globalThis.__libiko_instance(${jsonEncode(source.key)});
          return await s.account.loginWithCookies.validate(${jsonEncode(values)});
        })()
      ''');
      if (ok == true) {
        await AppDatabase()
            .setString('source_data.${source.key}.logged_in', '1');
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout(ComicSource source) async {
    await _ensureInitialized();
    try {
      await _engine.evaluate('''
        (async () => {
          const s = await globalThis.__libiko_instance(${jsonEncode(source.key)});
          if (s.account && typeof s.account.logout === 'function') {
            await s.account.logout();
          }
          return true;
        })()
      ''');
      await AppDatabase().remove('source_data.${source.key}.logged_in');
      await AppDatabase().remove('source_data.${source.key}.username');
    } catch (_) {
      // Best-effort logout.
    }
  }

  String? savedUsername(ComicSource source) =>
      AppDatabase().getString('source_data.${source.key}.username');

  Future<bool> isLogged(ComicSource source) async {
    await _ensureInitialized();
    if (AppDatabase().getString('source_data.${source.key}.logged_in') ==
        '1') {
      return true;
    }
    try {
      final result = await _engine.evaluate('''
        (async () => {
          const s = await globalThis.__libiko_instance(${jsonEncode(source.key)});
          return !!s.isLogged;
        })()
      ''');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<ComicDetails> loadInfo(ComicSource source, String id) async {
    await _ensureInitialized();
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__libiko_instance(${jsonEncode(source.key)});
        return s.comic.loadInfo(${jsonEncode(id)});
      })()
    ''');
    if (result is! Map) {
      throw StateError('loadInfo returned ${result.runtimeType}');
    }
    return ComicDetails.fromJs(result);
  }

  Future<ComicEp> loadEp(
      ComicSource source, String comicId, String epId) async {
    await _ensureInitialized();
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__libiko_instance(${jsonEncode(source.key)});
        return s.comic.loadEp(${jsonEncode(comicId)}, ${jsonEncode(epId)});
      })()
    ''');
    if (result is! Map) {
      throw StateError('loadEp returned ${result.runtimeType}');
    }
    return ComicEp.fromJs(result);
  }

  Future<ImageLoadingConfig> onImageLoad(
      ComicSource source, String url, String comicId, String epId) async {
    await _ensureInitialized();
    if (!source.canOnImageLoad) return ImageLoadingConfig(url: url);
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__libiko_instance(${jsonEncode(source.key)});
        return s.comic.onImageLoad(${jsonEncode(url)}, ${jsonEncode(comicId)}, ${jsonEncode(epId)});
      })()
    ''');
    if (result is! Map) return ImageLoadingConfig(url: url);
    return ImageLoadingConfig.fromJs(result);
  }

  /// Downloads [url] with [headers] for image display.
  Future<Uint8List> fetchImageBytes(
      String url, Map<String, String>? headers) async {
    final response = await _dio.get<List<int>>(url,
        options: Options(responseType: ResponseType.bytes, headers: headers));
    return Uint8List.fromList(response.data ?? const []);
  }

  /// Decodes [bytes], runs the source's `modifyImage` [script] over the pixels,
  /// and re-encodes the result as a PNG.
  Future<Uint8List> modifyImage(Uint8List bytes, String script) async {
    await _ensureInitialized();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final raw =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();
    if (raw == null) throw StateError('could not read image pixels');
    final rgba = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    final processed = await _engine.runModifyImage(script, width, height, rgba);
    if (processed.length != width * height * 4) {
      throw StateError('modifyImage changed the image size');
    }
    final decoded = Completer<ui.Image>();
    ui.decodeImageFromPixels(processed, width, height, ui.PixelFormat.rgba8888,
        (image) => decoded.complete(image));
    final result = await decoded.future;
    final png = await result.toByteData(format: ui.ImageByteFormat.png);
    result.dispose();
    if (png == null) throw StateError('could not encode image');
    return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  }

  void dispose() => _engine.dispose();
}
