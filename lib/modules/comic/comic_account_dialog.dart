import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_source.dart';
import 'comic_providers.dart';

class ComicAccountDialog extends ConsumerStatefulWidget {
  final ComicSource source;

  const ComicAccountDialog({super.key, required this.source});

  @override
  ConsumerState<ComicAccountDialog> createState() => ComicAccountDialogState();
}

class ComicAccountDialogState extends ConsumerState<ComicAccountDialog> {
  late final List<TextEditingController> _controllers;
  bool _logged = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final count = widget.source.hasCookieLogin
        ? widget.source.cookieFields.length
        : 2;
    _controllers =
        List.generate(count, (_) => TextEditingController());
    _refreshStatus();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    bool logged = false;
    try {
      logged =
          await ref.read(comicSourceManagerProvider).isLogged(widget.source);
    } catch (_) {}
    if (mounted) setState(() => _logged = logged);
  }

  String _label(int index) {
    if (widget.source.hasCookieLogin) {
      return widget.source.cookieFields[index];
    }
    return index == 0 ? '账号 / 邮箱' : '密码';
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    var ok = false;
    try {
      final manager = ref.read(comicSourceManagerProvider);
      if (widget.source.hasCookieLogin) {
        ok = await manager.loginWithCookies(
            widget.source, _controllers.map((c) => c.text.trim()).toList());
      } else {
        ok = await manager.login(widget.source, _controllers[0].text.trim(),
            _controllers[1].text);
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _logged = ok;
      _error = ok ? null : '登录失败';
    });
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await ref.read(comicSourceManagerProvider).logout(widget.source);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _logged = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.source.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_logged ? '已登录' : '未登录',
                style: TextStyle(
                    fontSize: 13,
                    color: _logged
                        ? const Color(0xFF34C759)
                        : cs.onSurfaceVariant)),
            if (!_logged) ...[
              const SizedBox(height: 12),
              for (var i = 0; i < _controllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _controllers[i],
                    obscureText: !widget.source.hasCookieLogin && i == 1,
                    decoration: InputDecoration(
                      labelText: _label(i),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
            ],
            if (_error != null)
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFE81123))),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        if (_logged)
          TextButton(
            onPressed: _busy ? null : _logout,
            child: const Text('退出登录'),
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('登录'),
            ),
          ),
      ],
    );
  }
}
