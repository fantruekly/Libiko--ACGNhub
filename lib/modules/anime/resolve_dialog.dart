import 'package:flutter/material.dart';

import '../../core/video/cancellation.dart';
import '../../core/video/headless_browser.dart';

typedef ResolveDialogResult = ({MediaCandidate? stream, bool cancelled});

/// Shows a cancellable spinner while [resolve] runs.
///
/// Returns the resolved stream; [ResolveDialogResult.cancelled] is true when the
/// user dismissed the dialog (button / barrier / back) before it finished, in
/// which case [cancel] is triggered and the caller should stop.
Future<ResolveDialogResult> showResolveDialog(
  BuildContext context, {
  required Future<MediaCandidate?> resolve,
  required CancellationToken cancel,
}) async {
  var completed = false;
  final stream = await showDialog<MediaCandidate?>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ResolveDialog(
      resolve: resolve,
      onCompleted: () => completed = true,
    ),
  );
  final cancelled = !completed;
  if (cancelled) cancel.cancel();
  return (stream: stream, cancelled: cancelled);
}

class _ResolveDialog extends StatefulWidget {
  final Future<MediaCandidate?> resolve;
  final VoidCallback onCompleted;

  const _ResolveDialog({required this.resolve, required this.onCompleted});

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  void _close(MediaCandidate? stream) {
    if (!mounted) return;
    widget.onCompleted();
    Navigator.of(context).pop(stream);
  }

  @override
  void initState() {
    super.initState();
    widget.resolve.then(_close, onError: (_) => _close(null));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
