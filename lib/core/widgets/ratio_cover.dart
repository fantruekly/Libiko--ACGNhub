import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../images/cover_ratio_cache.dart';
import '../platform.dart';

/// A cover image whose height follows the source image's real aspect ratio.
///
/// On mobile the ratio is taken from [CoverRatioCache] when known, otherwise
/// measured from the decoded image and written back to the cache; the widget
/// animates between the two. On desktop ([enabled] false) it renders a plain
/// image so the surrounding fixed-ratio grid keeps sizing it.
class RatioCover extends StatefulWidget {
  final String? url;
  final Map<String, String>? httpHeaders;
  final double fallbackRatio;
  final Widget Function(BuildContext) placeholderBuilder;
  final bool? enabled;
  final CoverRatioCache? cache;
  final Duration fadeInDuration;

  const RatioCover({
    super.key,
    required this.url,
    required this.placeholderBuilder,
    this.httpHeaders,
    this.fallbackRatio = 2 / 3,
    this.enabled,
    this.cache,
    this.fadeInDuration = Duration.zero,
  });

  @override
  State<RatioCover> createState() => _RatioCoverState();
}

class _RatioCoverState extends State<RatioCover> {
  late double _ratio = widget.fallbackRatio;
  bool _resolved = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  bool get _active => widget.enabled ?? !isDesktop;
  CoverRatioCache get _cache => widget.cache ?? defaultCoverRatioCache;
  String get _url => widget.url ?? '';

  @override
  void initState() {
    super.initState();
    if (!_active) return;
    _loadCached();
    _listenForSize();
  }

  @override
  void dispose() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    super.dispose();
  }

  Future<void> _loadCached() async {
    final cached = await _cache.ratioOf(_url);
    if (!mounted || cached == null) return;
    setState(() {
      _ratio = cached;
      _resolved = true;
    });
  }

  void _listenForSize() {
    if (_url.isEmpty) return;
    final provider =
        CachedNetworkImageProvider(_url, headers: widget.httpHeaders);
    final listener = ImageStreamListener(
      (info, _) => _measure(info),
      onError: (_, __) {},
    );
    _listener = listener;
    _stream = provider.resolve(ImageConfiguration.empty)..addListener(listener);
  }

  void _measure(ImageInfo info) {
    if (_resolved || !_active) return;
    final w = info.image.width;
    final h = info.image.height;
    if (w <= 0 || h <= 0) return;
    final ratio = w / h;
    _cache.remember(_url, ratio);
    if (!mounted) return;
    setState(() {
      _ratio = ratio;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = _url.isNotEmpty;
    final Widget image = hasUrl
        ? CachedNetworkImage(
            imageUrl: _url,
            fit: BoxFit.cover,
            memCacheWidth: 400,
            fadeInDuration: widget.fadeInDuration,
            httpHeaders: widget.httpHeaders,
            placeholder: (_, __) => widget.placeholderBuilder(context),
            errorWidget: (_, __, ___) => widget.placeholderBuilder(context),
          )
        : widget.placeholderBuilder(context);

    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: RepaintBoundary(child: image),
    );
    if (!_active) return framed;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _ratio, end: _ratio),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (context, value, child) =>
          AspectRatio(aspectRatio: value, child: child),
      child: framed,
    );
  }
}
