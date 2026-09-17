import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
  ImageProvider? _provider;
  int _providerWidth = 0;
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
  }

  @override
  void didUpdateWidget(covariant RatioCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url == oldWidget.url && widget.enabled == oldWidget.enabled) {
      return;
    }
    _stopListening();
    _ratio = widget.fallbackRatio;
    _resolved = false;
    _provider = null;
    _providerWidth = 0;
    if (!_active) return;
    _loadCached();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  /// Builds the provider for a decode width in device pixels (already
  /// multiplied by the device pixel ratio).
  void _useWidth(int width) {
    if (_provider != null && _providerWidth == width) return;
    final url = _url;
    _stopListening();
    _providerWidth = width;
    _provider = url.isEmpty
        ? null
        : CachedNetworkImageProvider(
            url,
            maxWidth: width,
            headers: widget.httpHeaders,
          );
    if (_active) _listenForSize();
  }

  void _stopListening() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  Future<void> _loadCached() async {
    if (_resolved) return;
    final url = _url;
    final cached = await _cache.ratioOf(url);
    if (!mounted || _resolved || cached == null || url != _url) return;
    setState(() {
      _ratio = cached;
      _resolved = true;
    });
  }

  void _listenForSize() {
    final provider = _provider;
    if (provider == null) return;
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
    unawaited(_cache.remember(_url, ratio).catchError((Object _) {}));
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _resolved) return;
        setState(() {
          _ratio = ratio;
          _resolved = true;
        });
      });
      return;
    }
    setState(() {
      _ratio = ratio;
      _resolved = true;
    });
  }

  Widget _frameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedSwitcher(
      duration: widget.fadeInDuration,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      child: frame == null
          ? KeyedSubtree(
              key: const ValueKey('placeholder'),
              child: widget.placeholderBuilder(context),
            )
          : KeyedSubtree(key: const ValueKey('image'), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final raw = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).clamp(200, 1600).round()
            : 400;
        final width = (((raw + 127) ~/ 128) * 128).clamp(200, 1600);
        _useWidth(width);

        final provider = _provider;
        final Widget image = provider == null
            ? widget.placeholderBuilder(context)
            : Image(
                image: provider,
                fit: BoxFit.cover,
                frameBuilder: _frameBuilder,
                errorBuilder: (context, _, __) =>
                    widget.placeholderBuilder(context),
              );

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
      },
    );
  }
}
