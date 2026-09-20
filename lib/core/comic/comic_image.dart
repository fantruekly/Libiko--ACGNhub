import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../services/cache_manager.dart';
import 'comic_source.dart';
import 'models.dart';

/// Maximum number of processed pages kept in memory before the oldest is
/// evicted (and its [ui.Image] disposed).
const int maxCachedPages = 12;

/// Upper bound for a comic page's decoded width (px). Tall webtoon strips are
/// otherwise decoded at full source width, which is costly in memory.
const int kMaxComicDecodeWidth = 1600;

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

int _be32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

/// Parses the pixel dimensions of a PNG, JPEG or WebP image from its leading
/// bytes, without decoding the whole image. Returns null when the format is
/// unknown or the header is incomplete. Pure so it can be unit-tested.
Size? parseImageSize(Uint8List bytes) {
  // PNG: 89 50 4E 47 0D 0A 1A 0A, then IHDR width/height at 16..24.
  if (bytes.length >= 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    final width = _be32(bytes, 16);
    final height = _be32(bytes, 20);
    return width > 0 && height > 0
        ? Size(width.toDouble(), height.toDouble())
        : null;
  }

  // JPEG: FF D8, then scan segments for an SOF0/1/2 marker.
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    var offset = 2;
    while (offset + 1 < bytes.length) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }
      final marker = bytes[offset + 1];
      if (marker == 0xFF) {
        offset++;
        continue;
      }
      // Standalone markers without a length field.
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9)) {
        offset += 2;
        continue;
      }
      if (offset + 3 >= bytes.length) return null;
      final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
      if (length < 2) return null;
      if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
        if (offset + 8 >= bytes.length) return null;
        final height = (bytes[offset + 5] << 8) | bytes[offset + 6];
        final width = (bytes[offset + 7] << 8) | bytes[offset + 8];
        return width > 0 && height > 0
            ? Size(width.toDouble(), height.toDouble())
            : null;
      }
      offset += 2 + length;
    }
    return null;
  }

  // WebP: RIFF....WEBP, then a VP8 /VP8L/VP8X chunk.
  if (bytes.length >= 16 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    final fourcc = String.fromCharCodes(bytes.sublist(12, 16));
    if (fourcc == 'VP8 ') {
      if (bytes.length < 30 ||
          bytes[23] != 0x9D ||
          bytes[24] != 0x01 ||
          bytes[25] != 0x2A) {
        return null;
      }
      final width = bytes[26] | ((bytes[27] & 0x3F) << 8);
      final height = bytes[28] | ((bytes[29] & 0x3F) << 8);
      return width > 0 && height > 0
          ? Size(width.toDouble(), height.toDouble())
          : null;
    }
    if (fourcc == 'VP8L') {
      if (bytes.length < 25 || bytes[20] != 0x2F) return null;
      final b1 = bytes[21];
      final b2 = bytes[22];
      final b3 = bytes[23];
      final b4 = bytes[24];
      final width = 1 + (((b2 & 0x3F) << 8) | b1);
      final height = 1 + (((b4 & 0x0F) << 10) | (b3 << 2) | ((b2 & 0xC0) >> 6));
      return Size(width.toDouble(), height.toDouble());
    }
    if (fourcc == 'VP8X') {
      if (bytes.length < 30) return null;
      final width = 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16));
      final height = 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16));
      return Size(width.toDouble(), height.toDouble());
    }
  }

  return null;
}

/// The median of [ratios], ignoring non-positive/non-finite entries, or
/// [fallback] when none are usable. Pure so it can be unit-tested.
double medianRatio(Iterable<double> ratios, {double fallback = 1.4}) {
  final known = ratios.where((r) => r.isFinite && r > 0).toList()..sort();
  if (known.isEmpty) return fallback;
  final middle = known.length ~/ 2;
  return known.length.isOdd
      ? known[middle]
      : (known[middle - 1] + known[middle]) / 2;
}

/// Cooperative cancellation for [ComicImageProvider.prefetchRatios].
class PrefetchCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
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
      return _CachedPageImageProvider(
        sourceKey: sourceKey,
        comicId: comicId,
        chapterId: chapterId,
        url: effective,
        requestUrl: url,
        headers: headers,
        cache: _cache,
      );
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
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<void>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, __) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) completer.completeError(error, stackTrace);
        },
      );
      stream.addListener(listener);
      try {
        await completer.future.timeout(const Duration(seconds: 20));
      } finally {
        stream.removeListener(listener);
      }
    } catch (_) {
      // Prefetch must not disturb reading.
    }
  }

  /// The aspect ratio (width / height) of a previously processed page, or null
  /// when it has not been loaded yet.
  double? ratioOf(String url) => _cache.ratioOf(url);

  /// Records [ratio] for [url] so later builds can size its placeholder. Used
  /// by the reader once an image resolves without going through `modifyImage`.
  void rememberRatio(String url, double ratio) {
    if (ratio.isFinite && ratio > 0) _cache.rememberRatio(url, ratio);
  }

  late final Dio _ratioDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    validateStatus: (_) => true,
  ));

  /// Fills the ratio cache for every [urls] whose ratio is still unknown, using
  /// a bounded number of concurrent workers.
  ///
  /// Each page's header is fetched with an HTTP `Range: bytes=0-8191` request;
  /// when that is not parseable (or the server ignores the range and the first
  /// bytes are not enough) it falls back to a full download and
  /// [ui.ImageDescriptor]. Best-effort: every failure is swallowed so reading
  /// is never disturbed. Pass [cancelToken] to stop early on a chapter change.
  Future<void> prefetchRatios(
    List<String> urls, {
    String? sourceKey,
    String? comicId,
    String? chapterId,
    int concurrency = 4,
    PrefetchCancelToken? cancelToken,
  }) async {
    // A source with an `onImageLoad` hook is far too expensive to run for every
    // page in the chapter just to learn its ratio. Its pages report the ratio
    // when they actually load (via `onRatio` / the processed image), so skip the
    // all-pages sweep and let the chapter median size the placeholder until then.
    if (sourceKey != null) {
      final source =
          manager.sources.where((s) => s.key == sourceKey).firstOrNull;
      if (source != null && source.canOnImageLoad) return;
    }
    final queue = Queue<String>();
    for (final url in urls) {
      if (cancelToken?.isCancelled ?? false) return;
      if (_cache.ratioOf(url) == null) queue.add(url);
    }
    if (queue.isEmpty) return;
    final lanes = concurrency < 1 ? 1 : concurrency;
    final workers = <Future<void>>[];
    for (var i = 0; i < lanes && queue.isNotEmpty; i++) {
      workers.add(
          _drainRatioQueue(queue, cancelToken, sourceKey, comicId, chapterId));
    }
    await Future.wait(workers);
  }

  Future<void> _drainRatioQueue(
      Queue<String> queue,
      PrefetchCancelToken? cancelToken,
      String? sourceKey,
      String? comicId,
      String? chapterId) async {
    while (queue.isNotEmpty) {
      if (cancelToken?.isCancelled ?? false) return;
      final url = queue.removeFirst();
      if (_cache.ratioOf(url) != null) continue;
      await _loadRatio(url, cancelToken, sourceKey, comicId, chapterId);
    }
  }

  Future<void> _loadRatio(String requestUrl, PrefetchCancelToken? cancelToken,
      String? sourceKey, String? comicId, String? chapterId) async {
    final request =
        await _resolveImageRequest(requestUrl, sourceKey, comicId, chapterId);
    try {
      final response = await _ratioDio.get<List<int>>(
        request.url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {...?request.headers, 'Range': 'bytes=0-8191'},
        ),
      );
      if (cancelToken?.isCancelled ?? false) return;
      final bytes = Uint8List.fromList(response.data ?? const []);
      final size = parseImageSize(bytes);
      if (size != null && size.height > 0) {
        _rememberRatio(requestUrl, request.url, size.width / size.height);
        return;
      }
    } catch (_) {
      // Fall through to a full download.
    }
    if (cancelToken?.isCancelled ?? false) return;
    await _ratioFromFullDownload(requestUrl, request, cancelToken);
  }

  Future<void> _ratioFromFullDownload(String requestUrl, _ImageRequest request,
      PrefetchCancelToken? cancelToken) async {
    if (_cache.ratioOf(requestUrl) != null) return;
    try {
      final response = await _ratioDio.get<List<int>>(
        request.url,
        options:
            Options(responseType: ResponseType.bytes, headers: request.headers),
      );
      if (cancelToken?.isCancelled ?? false) return;
      final bytes = Uint8List.fromList(response.data ?? const []);
      final size = parseImageSize(bytes);
      if (size != null && size.height > 0) {
        _rememberRatio(requestUrl, request.url, size.width / size.height);
        return;
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        final height = descriptor.height;
        if (height > 0) {
          _rememberRatio(requestUrl, request.url, descriptor.width / height);
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
    } catch (_) {
      // Unknown ratio; the reader falls back to the chapter median.
    }
  }

  /// Runs the source's `onImageLoad` for [url] to get the effective URL and
  /// headers its image request needs. Falls back to the raw URL with no
  /// headers when there is no source context or the hook fails.
  Future<_ImageRequest> _resolveImageRequest(
      String url, String? sourceKey, String? comicId, String? chapterId) async {
    if (sourceKey == null) return _ImageRequest(url, null);
    final source = manager.sources.where((s) => s.key == sourceKey).firstOrNull;
    if (source == null) return _ImageRequest(url, null);
    try {
      final config = await manager.onImageLoad(
          source, url, comicId ?? '', chapterId ?? '');
      return _ImageRequest(config.url ?? url, config.headers);
    } catch (_) {
      return _ImageRequest(url, null);
    }
  }

  void _rememberRatio(String requestUrl, String url, double ratio) {
    if (!ratio.isFinite || ratio <= 0) return;
    _cache.rememberRatio(requestUrl, ratio);
    if (url != requestUrl) _cache.rememberRatio(url, ratio);
  }
}

/// The effective URL and headers a ratio prefetch should use for one page.
class _ImageRequest {
  final String url;
  final Map<String, String>? headers;

  const _ImageRequest(this.url, this.headers);
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
      if (ratio.isFinite && ratio > 0) {
        cache.rememberRatio(url, ratio);
        if (requestUrl != url) cache.rememberRatio(requestUrl, ratio);
      }
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

/// Resolves [provider]'s first frame, removing the listener once the frame (or
/// an error) arrives.
Future<ImageInfo> _firstFrame(ImageProvider provider) {
  final completer = Completer<ImageInfo>();
  late final ImageStreamListener listener;
  final stream = provider.resolve(ImageConfiguration.empty);
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete(info);
    },
    onError: (error, stackTrace) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

/// An [ImageProvider] that serves a page from the shared in-memory cache,
/// populating it from a disk-cached [CachedNetworkImageProvider] on first use.
///
/// This gives sources without a `modifyImage` script (ehentai, …) the same
/// fast repeated resolves that processed pages get: the decoded [ui.Image] is
/// cloned into [_ProcessedImageCache], so later resolves skip the decode.
class _CachedPageImageProvider extends ImageProvider<_CachedPageImageProvider> {
  _CachedPageImageProvider({
    required this.sourceKey,
    required this.comicId,
    required this.chapterId,
    required this.url,
    required this.requestUrl,
    required this.cache,
    this.headers,
  });

  final String sourceKey;
  final String comicId;
  final String chapterId;

  /// The effective URL (after `onImageLoad`).
  final String url;

  /// The URL originally requested, used to remember the ratio under both.
  final String requestUrl;

  final Map<String, String>? headers;
  final _ProcessedImageCache cache;

  @override
  Future<_CachedPageImageProvider> obtainKey(
          ImageConfiguration configuration) =>
      SynchronousFuture<_CachedPageImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
      _CachedPageImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_load(key));
  }

  Future<ImageInfo> _load(_CachedPageImageProvider key) async {
    final cacheKey = pageCacheKey(sourceKey, comicId, chapterId, url);
    final cached = cache.get(cacheKey);
    if (cached != null) {
      return ImageInfo(image: cached.image.clone(), scale: 1.0);
    }
    // The disk-cached provider still applies; it is wrapped, not replaced.
    final plain = CachedNetworkImageProvider(
      url,
      headers: headers,
      cacheManager: AppCacheManager(),
      maxWidth: kMaxComicDecodeWidth,
    );
    final info = await _firstFrame(plain);
    try {
      final image = info.image;
      final ratio = image.height == 0 ? 0.0 : image.width / image.height;
      cache.put(cacheKey, _ProcessedPage(image.clone(), ratio));
      if (ratio.isFinite && ratio > 0) {
        cache.rememberRatio(url, ratio);
        if (requestUrl != url) cache.rememberRatio(requestUrl, ratio);
      }
      final served = ImageInfo(image: image.clone(), scale: 1.0);
      info.image.dispose();
      return served;
    } catch (_) {
      // Caching is best-effort: fall back to the plain frame so a page shows.
      return info;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedPageImageProvider &&
      other.sourceKey == sourceKey &&
      other.comicId == comicId &&
      other.chapterId == chapterId &&
      other.url == url;

  @override
  int get hashCode => Object.hash(sourceKey, comicId, chapterId, url);
}
