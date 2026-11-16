import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/watch_record.dart';

import '../../core/services/cache_manager.dart';

/// No Hero here: the same work can also appear in the catalog grid.
class AnimeResumeCard extends StatelessWidget {
  const AnimeResumeCard({
    super.key,
    required this.record,
    required this.onResume,
  });
  final WatchRecord record;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = record.durationMs > 0
        ? (record.positionMs / record.durationMs).clamp(0.0, 1.0)
        : null;
    final subtitle = progress == null
        ? '${record.episodeTitle} · 已看 ${record.positionMs ~/ 60000} 分钟'
        : '${record.episodeTitle} · ${(progress * 100).round()}%';
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onResume,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 60,
                height: 76,
                child: record.work.coverUrl?.isNotEmpty == true
                    ? CachedNetworkImage(
                        imageUrl: record.work.coverUrl!,
                        cacheManager: AppCacheManager(),
                        memCacheWidth: 240,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(cs),
                      )
                    : _placeholder(cs),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.work.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  if (progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.play_circle_outline_rounded,
                color: cs.primary, size: 24),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.live_tv_rounded, color: cs.onSurfaceVariant, size: 22));
}
