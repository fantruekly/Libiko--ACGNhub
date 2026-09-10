import 'package:flutter/material.dart';
import 'dio_image.dart';
import '../models/work.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onTap;
  final double width;
  final double imageHeight;

  const WorkCard({
    super.key,
    required this.work,
    this.onTap,
    this.width = 150,
    this.imageHeight = 200,
  });

  static final _colors = [
    Colors.blueGrey,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
    Colors.deepPurple,
    Colors.cyan,
    Colors.pink,
  ];

  Color _cardColor() {
    final hash = work.title.hashCode.abs();
    return _colors[hash % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: width,
                height: imageHeight,
                child: work.coverUrl != null && work.coverUrl!.isNotEmpty
                    ? DioImage(
                        url: work.coverUrl!,
                        width: width,
                        height: imageHeight,
                        fit: BoxFit.cover,
                        placeholder: () => _PlaceholderWidget(title: work.title, color: _cardColor()),
                        errorWidget: () => _PlaceholderWidget(title: work.title, color: _cardColor()),
                      )
                    : _PlaceholderWidget(title: work.title, color: _cardColor()),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              work.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (work.sourceName.isNotEmpty)
              Text(
                work.sourceName,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderWidget extends StatelessWidget {
  final String title;
  final Color color;

  const _PlaceholderWidget({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    final firstChar = title.isNotEmpty ? title.characters.first : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.4)],
        ),
      ),
      child: Center(
        child: Text(
          firstChar,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}