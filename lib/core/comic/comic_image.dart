import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'comic_source.dart';

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
    final source = manager.sources.where((s) => s.key == sourceKey).firstOrNull;
    if (source != null) {
      try {
        final config = await manager.onImageLoad(source, url, comicId, chapterId);
        effective = config.url ?? url;
        headers = config.headers;
      } catch (_) {
        // Fall back to a plain request when the source hook fails.
      }
    }
    return CachedNetworkImageProvider(effective, headers: headers);
  }
}
