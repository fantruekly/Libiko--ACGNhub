/// Prefer the requested work itself over a newer season sharing its name.
int selectProbeTitle(String keyword, List<String> titles) {
  String normalized(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');
  final exact =
      titles.indexWhere((title) => normalized(title) == normalized(keyword));
  if (exact >= 0) return exact;
  final contains = titles.indexWhere((title) => title.contains(keyword));
  return contains >= 0 ? contains : 0;
}

/// Evidence from actual player position events, measured with a monotonic clock.
/// A single jump, audio-only playback or a first frame alone is not a pass.
class PlaybackObservation {
  PlaybackObservation({this.requiredSeconds = 10});
  final int requiredSeconds;
  Duration? firstAt;
  Duration? lastAt;
  Duration? firstPosition;
  Duration? lastPosition;
  Duration largestGap = Duration.zero;
  int advances = 0;

  void record(Duration position, Duration elapsed) {
    if (position <= Duration.zero ||
        (lastPosition != null && position <= lastPosition!)) {
      return;
    }
    if (lastAt != null) {
      final gap = elapsed - lastAt!;
      if (gap > largestGap) largestGap = gap;
    }
    firstAt ??= elapsed;
    firstPosition ??= position;
    lastAt = elapsed;
    lastPosition = position;
    advances++;
  }

  bool stableAt(Duration elapsed) =>
      firstAt != null &&
      elapsed - firstAt! >= Duration(seconds: requiredSeconds) &&
      advances >= 5 &&
      lastPosition! - firstPosition! >= Duration(seconds: requiredSeconds) &&
      largestGap <= const Duration(seconds: 4) &&
      elapsed - lastAt! <= const Duration(seconds: 4);

  Map<String, Object?> toJson(Duration elapsed) => {
        'progressEvents': advances,
        'positionStartMs': firstPosition?.inMilliseconds,
        'positionEndMs': lastPosition?.inMilliseconds,
        'observedMs': firstAt == null ? 0 : (elapsed - firstAt!).inMilliseconds,
        'largestProgressGapMs': largestGap.inMilliseconds,
        'stableProgress': stableAt(elapsed),
      };
}

String redactProbeText(String text) => text
    .replaceAll(RegExp(r'https?://[^\s"<>]+'), '[URL]')
    .replaceAll(RegExp(r'Bearer\s+[^\s,;]+', caseSensitive: false), '[TOKEN]');

String playbackAuditMarkdown(Map<String, dynamic> report) {
  const labels = {
    'completed': '已完成',
    'running': '检测中',
    'passed': '通过',
    'playback_failed': '起播失败',
    'resolve_failed': '解析失败',
    'no_search_result': '未找到作品',
    'no_episodes': '未找到剧集',
    'timed_out': '超时',
    'request_failed': '请求失败',
    'search': '搜索',
    'episodes': '获取剧集',
    'resolve': '地址解析',
    'playback': '实际播放',
  };
  String cell(Object? value) => (value ?? '—')
      .toString()
      .replaceAll('|', '／')
      .replaceAll(RegExp(r'[\r\n]+'), ' ');
  final rows = (report['samples'] as List).cast<Map<String, dynamic>>();
  final lines = <String>[
    '# 动漫源实际播放检查',
    '',
    '开始时间（UTC）：${report['startedAt']}；状态：${labels[report['status']] ?? report['status']}。',
    '',
    '检查环境：Windows、本机网络、当前内置规则。每个样本独立执行搜索、剧集获取、地址解析和原生播放器测试。',
    '通过标准：视频首帧已渲染、视频尺寸有效，并且至少连续观察 ${report['observeSeconds']} 秒且进度多次推进、无播放错误。仅有 HTTP 响应或播放地址不算通过。',
    '这是抽样结果，不保证该源所有作品、集数及其他网络环境都可用。不会修改应用历史、健康统计或登录信息。',
    '',
    '| 源 | 搜索词 | 抽样作品 | 剧集／线路 | 结果 | 失败阶段 |',
    '| --- | --- | --- | --- | --- | --- |',
    for (final row in rows)
      '| ${cell(row['source'])} | ${cell(row['keyword'])} | ${cell(row['title'])} | ${cell(row['episode'])}／${cell(row['line'])} | ${cell(labels[row['status']] ?? row['status'])} | ${cell(labels[row['failureStage']] ?? row['failureStage'])} |',
    '',
    '| 源 | 作品 | 线路 | 逐线路结果 | 解析失败原因 |',
    '| --- | --- | --- | --- | --- |',
    for (final row in rows)
      for (final line in (row['lineResults'] as List? ?? const []))
        '| ${cell(row['source'])} | ${cell(row['title'])} | ${cell(line['line'])} | ${cell(labels[line['status']] ?? line['status'])} | ${cell(line['resolveFailure'] ?? line['errorType'])} |',
    '',
    '完整阶段耗时、候选尝试、首帧与持续播放证据见同目录的 report.json。报告不保存播放地址、签名参数、请求头值或视频截图。',
  ];
  return '${lines.join('\n')}\n';
}
