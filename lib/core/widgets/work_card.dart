import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/work.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onTap;

  const WorkCard({super.key, required this.work, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 0.7,
child: work.coverUrl != null && work.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: work.coverUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      fadeOutDuration: const Duration(milliseconds: 100),
                      placeholder: (_, __) => _placeholder(work, colorScheme),
                      errorWidget: (_, url, error) {
                        debugPrint('[IMG_ERR] $url => $error');
                        return _placeholder(work, colorScheme);
                      },
                    )
                  : _placeholder(work, colorScheme),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            work.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: colorScheme.onSurface.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(Work work, ColorScheme colorScheme) {
    final hash = work.title.hashCode.abs();
    final colors = [
      const Color(0xFFF3E5F5), const Color(0xFFEDE7F6), const Color(0xFFE8EAF6),
      const Color(0xFFE0F2F1), const Color(0xFFFCE4EC),
    ];
    final textColors = [
      const Color(0xFF7B1FA2), const Color(0xFF5E35B1), const Color(0xFF283593),
      const Color(0xFF00695C), const Color(0xFFC2185B),
    ];
    final bgColor = colors[hash % colors.length];
    final textColor = textColors[hash % textColors.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgColor, bgColor.withValues(alpha: 0.6)],
        ),
      ),
      child: Center(
        child: Text(
          work.title.characters.first,
          style: TextStyle(color: textColor.withValues(alpha: 0.35), fontSize: 28, fontWeight: FontWeight.w200),
        ),
      ),
    );
  }
}