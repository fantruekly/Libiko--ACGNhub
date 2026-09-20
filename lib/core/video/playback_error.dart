import 'stream_resolver.dart';

/// The message shown when resolving a stream fails, prefixed with the source
/// name when known.
String resolveFailureMessage(String sourceName, ResolveFailure? failure) {
  final prefix = sourceName.isEmpty ? '' : '$sourceName：';
  return switch (failure) {
    ResolveFailure.notFound => '$prefix未找到可播放地址，源站可能已下架或改版',
    ResolveFailure.timeout => '$prefix解析超时，请重试',
    ResolveFailure.loadFailed => '$prefix播放页加载失败，源站可能不可用',
    ResolveFailure.network => '网络异常，请检查网络后重试',
    _ => '$prefix解析失败，请重试',
  };
}

/// A short label for a media_kit playback error, recognising the common causes.
String playbackErrorLabel(String raw) {
  final s = raw.toLowerCase();
  if (s.contains('403') || s.contains('forbidden')) return '被源站拒绝（防盗链）';
  if (s.contains('404') || s.contains('not found')) return '播放地址已失效';
  if (s.contains('timeout') || s.contains('timed out')) return '播放超时';
  return '无法打开播放地址';
}
