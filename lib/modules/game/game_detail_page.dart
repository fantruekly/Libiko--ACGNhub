import 'package:flutter/material.dart';

class GameDetailPage extends StatelessWidget {
  final String sourceKey;
  final String gameId;
  final String title;
  final String? cover;
  const GameDetailPage({
    super.key,
    required this.sourceKey,
    required this.gameId,
    required this.title,
    this.cover,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
