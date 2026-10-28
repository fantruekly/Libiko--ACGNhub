import 'package:flutter/material.dart';

import '../../core/video/cancellation.dart';
import '../../core/video/stream_resolver.dart';

typedef ResolveDialogResult = ({ResolveResult? result, bool cancelled});

/// Shows a cancellable spinner while [resolve] runs.
///
/// Returns the resolve result; [ResolveDialogResult.cancelled] is true when the
/// user dismissed the dialog (button / barrier / back) before it finished, in
/// which case [cancel] is triggered and the caller should stop.
Future<ResolveDialogResult> showResolveDialog(
  BuildContext context, {
  required Future<ResolveResult> resolve,
  required CancellationToken cancel,
}) async {
  var completed = false;
  final result = await showDialog<ResolveResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ResolveDialog(
      resolve: resolve,
      onCompleted: () => completed = true,
    ),
  );
  final cancelled = !completed;
  if (cancelled) cancel.cancel();
  return (result: result, cancelled: cancelled);
}

class _ResolveDialog extends StatefulWidget {
  final Future<ResolveResult> resolve;
  final VoidCallback onCompleted;

  const _ResolveDialog({required this.resolve, required this.onCompleted});

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  bool _closed = false;

  void _finish(ResolveResult? result, {required bool completed}) {
    if (_closed || !mounted) return;
    _closed = true;
    if (completed) widget.onCompleted();
    Navigator.of(context).pop(result);
  }

  @override
  void initState() {
    super.initState();
    widget.resolve.then(
      (result) => _finish(result, completed: true),
      onError: (_) => _finish(null, completed: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _closed = true;
      },
      child: AlertDialog(
        key: const ValueKey('resolve-dialog'),
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 16),
            Text('正在解析播放地址…'),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('resolve-cancel'),
            onPressed: () => _finish(null, completed: false),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}
