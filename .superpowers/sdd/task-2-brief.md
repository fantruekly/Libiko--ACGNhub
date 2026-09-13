### Task 2: Account dialog in 源管理

**Files:**
- Modify: `lib/modules/comic/comic_source_page.dart`

**Interfaces:**
- Consumes: `ComicSource.hasLogin`/`hasCookieLogin`/`cookieFields` and the manager's `login`/`loginWithCookies`/`logout`/`isLogged` (Task 1).

- [ ] **Step 1: Add the 账号 menu item**

In `_sourceTile`'s `PopupMenuButton`, add to `onSelected`:

```dart
            if (value == 'account') _openAccount(source);
```

and to `itemBuilder`, before the 刷新 entry:

```dart
            if (source.hasLogin || source.hasCookieLogin)
              const PopupMenuItem(value: 'account', child: Text('账号')),
```

Add the handler near `_refresh`/`_confirmDelete`:

```dart
  void _openAccount(ComicSource source) {
    showDialog<void>(
      context: context,
      builder: (_) => _AccountDialog(source: source),
    );
  }
```

- [ ] **Step 2: Add the `_AccountDialog` widget**

Append at the end of `comic_source_page.dart`:

```dart
class _AccountDialog extends ConsumerStatefulWidget {
  final ComicSource source;

  const _AccountDialog({required this.source});

  @override
  ConsumerState<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<_AccountDialog> {
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
    final logged =
        await ref.read(comicSourceManagerProvider).isLogged(widget.source);
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
    final manager = ref.read(comicSourceManagerProvider);
    final bool ok;
    if (widget.source.hasLogin) {
      ok = await manager.login(widget.source, _controllers[0].text.trim(),
          _controllers[1].text);
    } else {
      ok = await manager.loginWithCookies(
          widget.source, _controllers.map((c) => c.text.trim()).toList());
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
    await ref.read(comicSourceManagerProvider).logout(widget.source);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _logged = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.source.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_logged ? '已登录' : '未登录',
              style: TextStyle(
                  fontSize: 13,
                  color: _logged
                      ? const Color(0xFF34C759)
                      : const Color(0xFF8E8E93))),
          if (!_logged) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _controllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _controllers[i],
                  obscureText: widget.source.hasLogin && i == 1,
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
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('登录'),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 4: Commit and push**

```bash
git add lib/modules/comic/comic_source_page.dart
git commit -m "feat(comic): add the source account dialog"
git push
```

---
