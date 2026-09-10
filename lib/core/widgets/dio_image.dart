import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

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
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://bgm.tv/',
    },
  ));
  static Directory? _cacheDir;

  File? _file;
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
      _loading = true;
      _error = false;
      _load();
    }
  }

  static Future<Directory> _getCacheDir() async {
    _cacheDir ??= Directory('${(await getTemporaryDirectory()).path}/img_cache');
    if (!_cacheDir!.existsSync()) _cacheDir!.createSync(recursive: true);
    return _cacheDir!;
  }

  Future<void> _load() async {
    final cacheDir = await _getCacheDir();
    final fileName = widget.url.hashCode.toRadixString(36);
    final cachedFile = File('${cacheDir.path}/$fileName');

    if (await cachedFile.exists()) {
      if (mounted) setState(() { _file = cachedFile; _loading = false; });
      return;
    }

    try {
      final response = await _dio.get(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data is List<int>) {
        await cachedFile.writeAsBytes(List<int>.from(response.data as List<int>));
        if (mounted) setState(() { _file = cachedFile; _loading = false; });
      } else {
        if (mounted) setState(() { _error = true; _loading = false; });
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
    if (_error || _file == null) {
      return widget.errorWidget?.call() ?? Container(color: Colors.grey[900]);
    }
    return Image.file(
      _file!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit ?? BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: widget.width?.toInt(),
    );
  }
}