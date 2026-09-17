import 'package:flutter/material.dart';
import '../models/work.dart';
import '../platform.dart';
import 'ratio_cover.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onTap;
  final String? subtitle;

  const WorkCard({super.key, required this.work, this.onTap, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget cover = RatioCover(
      url: work.coverUrl,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholderBuilder: (_) => _placeholder(work, cs),
    );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop)
            Expanded(child: Hero(tag: 'work_${work.id}', child: cover))
          else
            Hero(tag: 'work_${work.id}', child: cover),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
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
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder(Work work, ColorScheme cs) {
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
          style: TextStyle(
              color: cs.primary.withValues(alpha: 0.2),
              fontSize: 28,
              fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
