import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/watch_record.dart';
import '../../core/models/work.dart';
import '../../core/services/cache_manager.dart';

/// The artwork and copy always come from the actual catalog entry.
class AnimeFeatureBanner extends StatelessWidget {
  const AnimeFeatureBanner({
    super.key,
    required this.work,
    required this.feedLabel,
    required this.onOpen,
  });

  final Work work;
  final String feedLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = work.bannerUrl ?? work.coverUrl;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 680;
      final padding = wide ? 32.0 : 24.0;
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: wide ? 268 : 228),
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF233B56), Color(0xFF627992)],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
                child: image == null || image.isEmpty
                    ? const SizedBox.expand()
                    : CachedNetworkImage(
                        imageUrl: image,
                        cacheManager: AppCacheManager(),
                        memCacheWidth: 1600,
                        fit: BoxFit.cover,
                        fadeInDuration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        errorWidget: (_, __, ___) => const SizedBox.expand(),
                      ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xEB12243A),
                      Color(0xB812243A),
                      Color(0x5512243A),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(padding),
              child: SizedBox(
                width: wide ? constraints.maxWidth * 0.63 : double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('作品速览 · $feedLabel',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFFD4E5F7),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Text(work.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.35)),
                    const SizedBox(height: 10),
                    Text(
                      work.summary?.trim().isNotEmpty == true
                          ? work.summary!.trim()
                          : '查看作品介绍、剧集与播放来源',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFE0E8F2), height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      iconAlignment: IconAlignment.end,
                      label: const Text('查看详情'),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

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
