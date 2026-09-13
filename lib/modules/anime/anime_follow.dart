import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/follow_manager.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/work_card.dart';
import 'anime_detail_page.dart';

class AnimeFollowView extends ConsumerWidget {
  const AnimeFollowView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(followProvider);

    if (records.isEmpty) {
      return const EmptyState(icon: Icons.favorite_border_rounded, message: '还没有追番');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 20,
        crossAxisSpacing: 16,
        childAspectRatio: 0.60,
      ),
      itemCount: records.length,
      itemBuilder: (_, i) {
        final work = records[i].work;
        return WorkCard(
          work: work,
          onTap: () =>
              Navigator.push(context, smoothRoute(AnimeDetailPage(work: work))),
        );
      },
    );
  }
}
