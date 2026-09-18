import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'comic_source.dart';
import 'models.dart';

/// Resolves a comic page URL to an [ImageProvider] carrying the per-image
/// headers a source's `onImageLoad` demands (typically a `referer`).
class ComicImageProvider {
  ComicImageProvider(this.manager);

  final ComicSourceManager manager;

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
      url: effective,
      headers: headers,
      script: script,
      engine: manager,
    );
  }
}

/// An [ImageProvider] that downloads a page, reassembles it through the
/// source's `modifyImage` script, and displays the processed PNG.
class _ModifyImageProvider extends ImageProvider<_ModifyImageProvider> {
  _ModifyImageProvider({
    required this.url,
    this.headers,
    required this.script,
    required this.engine,
  });

  final String url;
  final Map<String, String>? headers;
  final String script;
  final ComicSourceManager engine;

  @override
  Future<_ModifyImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_ModifyImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
      _ModifyImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(_ModifyImageProvider key) async {
    Uint8List? bytes;
    try {
      bytes = await engine.fetchImageBytes(url, headers);
      final processed = await engine.modifyImage(bytes, script);
      return await ui.instantiateImageCodec(processed);
    } catch (_) {
      // Fall back to the raw page so a broken script still shows something.
      if (bytes != null) return ui.instantiateImageCodec(bytes);
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _ModifyImageProvider &&
      other.url == url &&
      other.script == script;

  @override
  int get hashCode => Object.hash(url, script);
}
