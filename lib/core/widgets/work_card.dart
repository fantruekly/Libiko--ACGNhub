import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
                child: work.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: work.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.grey[800]),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.image, color: Colors.grey, size: 48),
                      ),
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