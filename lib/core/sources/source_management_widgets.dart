import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'source_preferences.dart';

String sourceLocalTime(DateTime value) {
  final t = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

class SourceHealthSummary extends ConsumerWidget {
  const SourceHealthSummary(
      {super.key, required this.kind, required this.sourceId});
  final SourceKind kind;
  final String sourceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(sourceHealthProvider).health(kind, sourceId);
    return Text(
        [
          if (health.lastSuccess == null && health.lastFailure == null)
            '尚无请求记录',
          if (health.lastSuccess != null)
            '最近成功：${sourceLocalTime(health.lastSuccess!)}',
          if (health.lastFailure != null)
            '最近失败：${sourceLocalTime(health.lastFailure!)} · ${sourceFailureLabel(health.failure ?? SourceFailureKind.unknown)}',
        ].join('\n'),
        style: Theme.of(context).textTheme.bodySmall);
  }
}

class SourcePreferenceControls extends ConsumerStatefulWidget {
  const SourcePreferenceControls(
      {super.key,
      required this.kind,
      required this.sourceId,
      required this.order});
  final SourceKind kind;
  final String sourceId;
  final List<String> order;
  @override
  ConsumerState<SourcePreferenceControls> createState() =>
      _SourcePreferenceControlsState();
}

class _SourcePreferenceControlsState
    extends ConsumerState<SourcePreferenceControls> {
  bool _saving = false;
  void _save(Future<void> Function() action) {
    if (_saving) return;
    setState(() => _saving = true);
    unawaited(() async {
      try {
        await action();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('源设置保存失败，请重试')));
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(sourcePreferencesProvider);
    final notifier = ref.read(sourcePreferencesProvider.notifier);
    final index = widget.order.indexOf(widget.sourceId);
    final enabled = config.enabled(widget.kind, widget.sourceId);
    return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Switch.adaptive(
              value: enabled,
              onChanged: _saving
                  ? null
                  : (value) => _save(() => notifier.setEnabled(
                      widget.kind, widget.sourceId, value))),
          Text(enabled ? '已启用' : '已禁用'),
          IconButton(
              tooltip: '上移',
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              onPressed: !_saving && index > 0
                  ? () => _save(() => notifier.move(
                      widget.kind, widget.order, widget.sourceId, -1))
                  : null),
          IconButton(
              tooltip: '下移',
              icon: const Icon(Icons.arrow_downward_rounded, size: 20),
              onPressed:
                  !_saving && index >= 0 && index + 1 < widget.order.length
                      ? () => _save(() => notifier.move(
                          widget.kind, widget.order, widget.sourceId, 1))
                      : null),
        ]);
  }
}

class SourceManagementTile extends StatelessWidget {
  const SourceManagementTile(
      {super.key,
      required this.kind,
      required this.sourceId,
      required this.name,
      required this.subtitle,
      required this.order,
      this.actions = const []});
  final SourceKind kind;
  final String sourceId, name, subtitle;
  final List<String> order;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 8),
            SourceHealthSummary(kind: kind, sourceId: sourceId),
            SourcePreferenceControls(
                kind: kind, sourceId: sourceId, order: order),
            if (actions.isNotEmpty) Wrap(spacing: 8, children: actions),
          ])));
}
