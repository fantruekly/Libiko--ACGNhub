import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'comic_source.dart';
import 'models.dart';

/// Maximum number of processed pages kept in memory before the oldest is
/// evicted (and its [ui.Image] disposed).
const int maxCachedPages = 12;

/// Cache key for a processed page. Pure so it can be unit-tested.
String pageCacheKey(
  String sourceKey,
  String comicId,
  String chapterId,
  String url,
) =>
    '$sourceKey|$comicId|$chapterId|$url';

/// Removes the least-recently-used entry of [cache], handing it to [onEvict].
/// A no-op on an empty cache.
void evictOldest<K, V>(
    LinkedHashMap<K, V> cache, void Function(V value) onEvict) {
  if (cache.isEmpty) return;
  final oldest = cache.keys.first;
  final value = cache.remove(oldest);
  if (value != null) onEvict(value);
}

/// Trims [cache] down to at most [max] entries, evicting oldest-first.
void trimCache<K, V>(
    LinkedHashMap<K, V> cache, int max, void Function(V value) onEvict) {
  while (cache.length > max) {
    evictOldest(cache, onEvict);
  }
}

class _ProcessedPage {
  final ui.Image image;
  final double ratio;
  _ProcessedPage(this.image, this.ratio);
}

/// Bounded LRU cache of processed pages plus a per-URL aspect ratio map.
class _ProcessedImageCache {
  final LinkedHashMap<String, _ProcessedPage> _pages = LinkedHashMap();
  final Map<String, double> _ratios = {};

  double? ratioOf(String url) => _ratios[url];

  void rememberRatio(String url, double ratio) => _ratios[url] = ratio;

  /// Returns the cached page for [key], marking it most-recently-used.
  _ProcessedPage? get(String key) {
    final page = _pages.remove(key);
    if (page == null) return null;
    _pages[key] = page;
    return page;
  }

  void put(String key, _ProcessedPage page) {
    final previous = _pages.remove(key);
    if (previous != null && !identical(previous, page)) {
      previous.image.dispose();
    }
    _pages[key] = page;
    trimCache(_pages, maxCachedPages, (p) => p.image.dispose());
  }
}

/// Resolves a comic page URL to an [ImageProvider] carrying the per-image
/// headers a source's `onImageLoad` demands (typically a `referer`).
class ComicImageProvider {
  ComicImageProvider(this.manager);

  final ComicSourceManager manager;
  final _ProcessedImageCache _cache = _ProcessedImageCache();

  Future<ImageProvider> resolve(
    String sourceKey,
    String comicId,
    String chapterId,
    String url,
  ) async {
    var effective = url;
    Map<String, String>? headers;
    ImageLoadingConfig? config;
    final source = manager.sources.where((s) => s.key == sourceKey).firstOrNull;
    if (source != null) {
      try {
        config = await manager.onImageLoad(source, url, comicId, chapterId);
        effective = config.url ?? url;
        headers = config.headers;
      } catch (_) {
        // Fall back to a plain request when the source hook fails.
      }
    }
    final script = config?.modifyImage;
    if (script == null || script.trim().isEmpty) {
      return CachedNetworkImageProvider(effective, headers: headers);
    }
    return _ModifyImageProvider(
      sourceKey: sourceKey,
      comicId: comicId,
      chapterId: chapterId,
      url: effective,
      requestUrl: url,
      headers: headers,
      script: script,
      engine: manager,
      cache: _cache,
    );
  }

  /// Warms [url]'s processed frame without waiting for it to be displayed.
  ///
  /// Best-effort: any failure is swallowed so reading is never disturbed.
  Future<void> prefetch(
    String sourceKey,
    String comicId,
    String chapterId,
    String url,
  ) async {
    try {
      final provider = await resolve(sourceKey, comicId, chapterId, url);
      provider.resolve(ImageConfiguration.empty);
    } catch (_) {
      // Prefetch must not disturb reading.
    }
  }

  /// The aspect ratio (width / height) of a previously processed page, or null
  /// when it has not been loaded yet.
  double? ratioOf(String url) => _cache.ratioOf(url);
}

/// An [ImageProvider] that downloads a page, reassembles it through the
/// source's `modifyImage` script, and displays the processed [ui.Image]
/// without a PNG re-encoding round trip.
class _ModifyImageProvider extends ImageProvider<_ModifyImageProvider> {
  _ModifyImageProvider({
    required this.sourceKey,
    required this.comicId,
    required this.chapterId,
    required this.url,
    required this.requestUrl,
    this.headers,
    required this.script,
    required this.engine,
    required this.cache,
  });

  final String sourceKey;
  final String comicId;
  final String chapterId;

  /// The effective URL (after `onImageLoad`).
  final String url;

  /// The URL originally requested, used to remember the ratio under both.
  final String requestUrl;

  final Map<String, String>? headers;
  final String script;
  final ComicSourceManager engine;
  final _ProcessedImageCache cache;

  @override
  Future<_ModifyImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_ModifyImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
      _ModifyImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_load(key));
  }

  Future<ImageInfo> _load(_ModifyImageProvider key) async {
    final cacheKey = pageCacheKey(sourceKey, comicId, chapterId, url);
    final cached = cache.get(cacheKey);
    if (cached != null) {
      return ImageInfo(image: cached.image.clone(), scale: 1.0);
    }
    Uint8List? bytes;
    try {
      bytes = await engine.fetchImageBytes(url, headers);
      final processed = await engine.processImage(bytes, script);
      final ratio =
          processed.height == 0 ? 0.0 : processed.width / processed.height;
      cache.put(cacheKey, _ProcessedPage(processed, ratio));
      cache.rememberRatio(url, ratio);
      if (requestUrl != url) cache.rememberRatio(requestUrl, ratio);
      return ImageInfo(image: processed.clone(), scale: 1.0);
    } catch (_) {
      // Fall back to the raw page so a broken script still shows something.
      if (bytes == null) rethrow;
      final raw = await _decodeRaw(bytes);
      return ImageInfo(image: raw, scale: 1.0);
    }
  }

  Future<ui.Image> _decodeRaw(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _ModifyImageProvider &&
      other.sourceKey == sourceKey &&
      other.comicId == comicId &&
      other.chapterId == chapterId &&
      other.url == url &&
      other.script == script;

  @override
  int get hashCode =>
      Object.hash(sourceKey, comicId, chapterId, url, script);
}
