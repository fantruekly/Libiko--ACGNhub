import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account/sync_service.dart';
import '../../core/services/watch_history.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/work_card.dart';
import 'anime_detail_page.dart';

class AnimeHistoryView extends ConsumerWidget {
  const AnimeHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(watchHistoryProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                '历史记录',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.4),
              ),
              const Spacer(),
              TextButton(
                onPressed:
                    records.isEmpty ? null : () => _confirmClear(context, ref),
                child: const Text('清空历史'),
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const EmptyState(
                  icon: Icons.history_rounded, message: '还没有观看记录')
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.60,
                  ),
                  itemCount: records.length,
                  itemBuilder: (_, i) {
                    final record = records[i];
                    return WorkCard(
                      work: record.work,
                      subtitle: '看到 ${record.episodeTitle}',
                      onTap: () => Navigator.push(
                          context,
                          smoothRoute(
                              AnimeDetailPage(work: record.work))),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史记录？'),
        content: const Text('将删除全部观看记录，且不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('清空')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(watchHistoryProvider.notifier).clear();
    ref.read(syncProvider).schedule();
  }
}
