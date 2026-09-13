import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_source.dart';
import 'comic_providers.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF8E8E93);

class ComicSourcePage extends ConsumerStatefulWidget {
  const ComicSourcePage({super.key});

  @override
  ConsumerState<ComicSourcePage> createState() => _ComicSourcePageState();
}

class _ComicSourcePageState extends ConsumerState<ComicSourcePage> {
  final _urlCtrl = TextEditingController();
  final _listCtrl = TextEditingController();
  String? _importError;
  bool _importing = false;
  String? _listError;
  bool _loadingList = false;
  List<Map<String, dynamic>> _remoteEntries = const [];
  bool _reordering = false;
  List<ComicSource> _draft = const [];

  @override
  void initState() {
    super.initState();
    _listCtrl.text = ref.read(comicSourceListUrlProvider);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  ComicSourceManager get _manager => ref.read(comicSourceManagerProvider);

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(comicSourcesProvider);
    final hasSources = (sourcesAsync.valueOrNull ?? const []).isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('源管理'),
        actions: [
          if (hasSources)
            IconButton(
              tooltip: _reordering ? '完成' : '排序',
              icon: Icon(
                  _reordering ? Icons.check_rounded : Icons.sort_rounded),
              onPressed: _toggleReorder,
            ),
        ],
      ),
      body: _reordering
          ? _reorderBody()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ..._sourceSection(sourcesAsync),
                const SizedBox(height: 24),
                _addSection(),
                const SizedBox(height: 24),
                _remoteListSection(),
              ],
            ),
    );
  }

  Future<void> _toggleReorder() async {
    if (_reordering) {
      await _manager.saveOrder(_draft.map((s) => s.key).toList());
      ref.invalidate(comicSourcesProvider);
      if (mounted) setState(() => _reordering = false);
      return;
    }
    final sources = ref.read(comicSourcesProvider).valueOrNull ?? const [];
    setState(() {
      _draft = List.of(sources);
      _reordering = true;
    });
  }

  Widget _reorderBody() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      buildDefaultDragHandles: false,
      itemCount: _draft.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _draft.removeAt(oldIndex);
          _draft.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final source = _draft[index];
        return _sourceTile(source,
            key: ValueKey(source.key), reorderIndex: index);
      },
    );
  }

  List<Widget> _sourceSection(AsyncValue<List<ComicSource>> async) {
    return async.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (_, __) => [
        Row(
          children: [
            const Text('加载失败', style: TextStyle(fontSize: 14, color: _muted)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => ref.invalidate(comicSourcesProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ],
      data: (sources) {
        if (sources.isEmpty) {
          return const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('还没有添加漫画源',
                  style: TextStyle(fontSize: 14, color: _muted)),
            ),
          ];
        }
        return [
          const _SectionTitle('已加载的源'),
          for (final source in sources) _sourceTile(source),
        ];
      },
    );
  }

  Widget _sourceTile(ComicSource source, {Key? key, int? reorderIndex}) {
    final caps = <String>[
      if (source.canSearch) '搜索',
      if (source.canExplore) '发现',
      if (source.canLoadInfo) '详情',
      if (source.canLoadEp) '章节',
    ];
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(source.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('${source.key} · v${source.version}'),
            if (caps.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final cap in caps) _capChip(cap)],
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
        trailing: reorderIndex != null
            ? ReorderableDragStartListener(
                index: reorderIndex,
                child: const Icon(Icons.drag_handle_rounded, color: _muted),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _loginBadge(source),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'account') _openAccount(source);
                      if (value == 'refresh') _refresh(source);
                      if (value == 'delete') _confirmDelete(source);
                    },
                    itemBuilder: (_) => [
                      if (source.hasLogin || source.hasCookieLogin)
                        const PopupMenuItem(
                            value: 'account', child: Text('账号')),
                      PopupMenuItem(
                        value: 'refresh',
                        enabled: source.url.isNotEmpty,
                        child: const Text('刷新'),
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _capChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11, color: _accent, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _addSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('添加源'),
        TextField(
          controller: _urlCtrl,
          decoration: const InputDecoration(
            hintText: 'https://example.com/source.js',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _importing ? null : _importFromUrl,
          child: _importing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('从 URL 导入'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _importing ? null : _importFromFile,
          child: const Text('从文件导入'),
        ),
        if (_importError != null) ...[
          const SizedBox(height: 8),
          Text(_importError!,
              style: const TextStyle(fontSize: 13, color: Colors.red)),
        ],
      ],
    );
  }

  Widget _remoteListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('远程规则列表'),
        TextField(
          controller: _listCtrl,
          decoration: const InputDecoration(
            hintText: 'https://example.com/sources.json',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) =>
              ref.read(comicSourceListUrlProvider.notifier).set(value),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _loadingList ? null : _fetchRemoteList,
          child: _loadingList
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('获取列表'),
        ),
        if (_listError != null) ...[
          const SizedBox(height: 8),
          Text(_listError!,
              style: const TextStyle(fontSize: 13, color: Colors.red)),
        ],
        const SizedBox(height: 12),
        for (final entry in _remoteEntries) _remoteEntryTile(entry),
      ],
    );
  }

  Widget _remoteEntryTile(Map<String, dynamic> entry) {
    final name = entry['name']?.toString() ?? entry['key']?.toString() ?? '';
    final url = entry['url']?.toString() ?? '';
    final description = entry['description']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(name),
        subtitle: description == null ? null : Text(description),
        trailing: TextButton(
          onPressed: url.isEmpty ? null : () => _addRemote(url),
          child: const Text('添加'),
        ),
      ),
    );
  }

  Future<void> _importFromUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _importing = true;
      _importError = null;
    });
    try {
      final source = await _manager.importFromUrl(url);
      ref.invalidate(comicSourcesProvider);
      if (!mounted) return;
      setState(() => _importing = false);
      messenger.showSnackBar(SnackBar(content: Text('已导入：${source.name}')));
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importError = e.toString();
      });
    }
  }

  Future<void> _importFromFile() async {
    const typeGroup = XTypeGroup(label: 'JS 源', extensions: ['js']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _importing = true;
      _importError = null;
    });
    try {
      final source = await _manager.importFromFile(file.path);
      ref.invalidate(comicSourcesProvider);
      if (!mounted) return;
      setState(() => _importing = false);
      messenger.showSnackBar(SnackBar(content: Text('已导入：${source.name}')));
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importError = e.toString();
      });
    }
  }

  Future<void> _fetchRemoteList() async {
    final url = _listCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      final response = await Dio().get<String>(url,
          options: Options(responseType: ResponseType.plain));
      final data = jsonDecode(response.data ?? '');
      if (data is! List) throw const FormatException('列表格式无效');
      final entries = data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (!mounted) return;
      setState(() {
        _remoteEntries = entries;
        _loadingList = false;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = e.toString();
      });
    }
  }

  Future<void> _addRemote(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final source = await _manager.importFromUrl(url);
      ref.invalidate(comicSourcesProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('已导入：${source.name}')));
    } on FormatException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导入失败：${e.message}')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  void _openAccount(ComicSource source) {
    showDialog<void>(
      context: context,
      builder: (_) => _AccountDialog(source: source),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _loginBadge(ComicSource source) {
    return FutureBuilder<bool>(
      future: _manager.isLogged(source),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        final username = _manager.savedUsername(source);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (username != null && username.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(username,
                    style: const TextStyle(fontSize: 12, color: _muted)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('已登录',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF34C759))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refresh(ComicSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final refreshed = await _manager.refresh(source);
      ref.invalidate(comicSourcesProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('已刷新：${refreshed.name}')));
    } on FormatException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('刷新失败：${e.message}')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('刷新失败，请重试')));
    }
  }

  Future<void> _confirmDelete(ComicSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${source.name}」？'),
        content: const Text('将移除该漫画源及其本地文件。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _manager.remove(source);
      ref.invalidate(comicSourcesProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('已删除：${source.name}')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

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
                        : const Color(0xFF8E8E93))),
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
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('登录'),
          ),
      ],
    );
  }
}
