import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class DioImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function()? placeholder;
  final Widget Function()? errorWidget;

  const DioImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<DioImage> createState() => _DioImageState();
}

class _DioImageState extends State<DioImage> {
  static final _cache = <String, Uint8List>{};
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://bgm.tv/',
    },
  ));

  Uint8List? _data;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DioImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _data = null;
      _loading = true;
      _error = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (_cache.containsKey(widget.url)) {
      if (mounted) setState(() { _data = _cache[widget.url]; _loading = false; });
      return;
    }
    try {
      final response = await _dio.get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null && mounted) {
        final bytes = Uint8List.fromList(response.data!);
        _cache[widget.url] = bytes;
        setState(() { _data = bytes; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.placeholder?.call() ?? Container(color: Colors.grey[900]);
    }
    if (_error || _data == null) {
      return widget.errorWidget?.call() ?? Container(color: Colors.grey[900], child: const Icon(Icons.broken_image, color: Colors.grey));
    }
    return Image.memory(
      _data!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit ?? BoxFit.cover,
      gaplessPlayback: true,
    );
  }
}