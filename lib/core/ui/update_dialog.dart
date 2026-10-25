import 'package:flutter/material.dart';

import '../services/update_controller.dart';
import '../services/update_service.dart';
import 'open_url.dart';

Future<void> showUpdateDialog(
        BuildContext context, UpdateInfo update, UpdateController controller,
        {Future<bool> Function(String) openUrl = openExternalUrl}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _UpdateDialog(
          update: update, controller: controller, openUrl: openUrl),
    );

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog(
      {required this.update, required this.controller, required this.openUrl});
  final UpdateInfo update;
  final UpdateController controller;
  final Future<bool> Function(String) openUrl;
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final opened = await widget.openUrl(widget.update.url);
    if (!mounted) return;
    if (opened) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = '无法打开浏览器，可复制下方链接后手动打开';
      });
    }
  }

  Future<void> _skip() async {
    setState(() => _busy = true);
    try {
      await widget.controller.skipVersion(widget.update.version);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '设置保存失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    return AlertDialog(
      title: Text('发现新版本 v${update.version}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.controller.currentVersion != null)
              Text('当前版本 v${widget.controller.currentVersion}'),
            if (update.publishedAt != null)
              Text(
                  '发布时间 ${update.publishedAt!.toLocal().toString().split(' ').first}'),
            const SizedBox(height: 16),
            Text(update.notes.trim().isEmpty ? '此版本暂无更新说明。' : update.notes),
            const SizedBox(height: 16),
            const Text('前往发布页选择适合当前设备的安装包。'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
              SelectableText(update.url),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : _skip, child: const Text('跳过此版本')),
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('稍后')),
        FilledButton(
            onPressed: _busy ? null : _download,
            child: Text(_busy ? '处理中…' : '前往发布页')),
      ],
    );
  }
}
