import 'package:flutter/material.dart';
import '../models/work.dart';
import 'dio_image.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onTap;

  const WorkCard({super.key, required this.work, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 0.65,
              child: work.coverUrl != null && work.coverUrl!.isNotEmpty
                  ? DioImage(
                      url: work.coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: () => _placeholder(work),
                      errorWidget: () => _placeholder(work),
                    )
                  : _placeholder(work),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              work.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(Work work) {
    final hash = work.title.hashCode.abs();
    final colors = [
      Colors.teal.shade700,
      Colors.indigo.shade700,
      Colors.deepPurple.shade700,
      Colors.cyan.shade700,
      Colors.blueGrey.shade700,
    ];
    final color = colors[hash % colors.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.3)],
        ),
      ),
      child: Center(
        child: Text(
          work.title.isNotEmpty ? work.title.characters.first : '?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 40, fontWeight: FontWeight.w300),
        ),
      ),
    );
  }
}