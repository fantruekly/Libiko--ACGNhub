import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/work.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onTap;
  final String? subtitle;

  const WorkCard({super.key, required this.work, this.onTap, this.subtitle});

  static const _accent = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sub = subtitle ?? work.sourceName;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: work.coverUrl != null && work.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: work.coverUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => _placeholder(work),
                      errorWidget: (_, __, ___) => _placeholder(work),
                    )
                  : _placeholder(work),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            work.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: cs.onSurface,
            ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(Work work) {
    final hash = work.title.hashCode.abs();
    final bgColors = const [
      Color(0xFFF3E5F5),
      Color(0xFFEDE7F6),
      Color(0xFFE8EAF6),
      Color(0xFFE0F2F1),
    ];
    return Container(
      color: bgColors[hash % bgColors.length],
      child: Center(
        child: Text(
          work.title.characters.first,
          style: TextStyle(color: _accent.withValues(alpha: 0.2), fontSize: 28, fontWeight: FontWeight.w200),
        ),
      ),
    );
  }
}