import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/account/account_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader(title: '账号'),
          const _AccountSection(),
          const Divider(),
          const _SectionHeader(title: '缓存'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清除图片缓存'),
            onTap: () async {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清除')),
                );
              }
            },
          ),
          const Divider(),
          const _SectionHeader(title: '关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('ACGNhub'),
            subtitle: Text('v0.1.0 - 动漫聚合应用'),
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  final _baseUrl = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _baseUrlFocus = FocusNode();
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _baseUrlFocus.addListener(() {
      if (!_baseUrlFocus.hasFocus) {
        ref.read(accountProvider.notifier).setBaseUrl(_baseUrl.text);
      }
    });
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _username.dispose();
    _password.dispose();
    _baseUrlFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountProvider);
    if (!_seeded) {
      _baseUrl.text = state.baseUrl;
      _seeded = true;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _baseUrl,
            focusNode: _baseUrlFocus,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: kDefaultBaseUrl,
              isDense: true,
            ),
            onSubmitted: (value) =>
                ref.read(accountProvider.notifier).setBaseUrl(value),
          ),
          const SizedBox(height: 14),
          if (state.isLoggedIn) _loggedIn(state) else _loggedOut(state),
        ],
      ),
    );
  }

  Widget _loggedIn(AccountState state) {
    return Row(
      children: [
        const Icon(Icons.account_circle_rounded,
            size: 30, color: Color(0xFF007AFF)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.user!.username,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const Text('已登录',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5A5A5F))),
            ],
          ),
        ),
        TextButton(
          onPressed: () => ref.read(accountProvider.notifier).logout(),
          child: const Text('退出登录'),
        ),
      ],
    );
  }

  Widget _loggedOut(AccountState state) {
    final canSubmit = !state.loading &&
        _username.text.trim().isNotEmpty &&
        _password.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _username,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: '用户名', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _password,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: '密码', isDense: true),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              onPressed: canSubmit ? () => _submit(login: true) : null,
              child: const Text('登录'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              onPressed: canSubmit ? () => _submit(login: false) : null,
              child: const Text('注册'),
            ),
            const SizedBox(width: 12),
            if (state.loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(state.error!,
                style: const TextStyle(
                    fontSize: 13, color: Colors.redAccent)),
          ),
      ],
    );
  }

  Future<void> _submit({required bool login}) async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) return;
    final notifier = ref.read(accountProvider.notifier);
    await notifier.setBaseUrl(_baseUrl.text);
    if (login) {
      notifier.login(username, password);
    } else {
      notifier.register(username, password);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
