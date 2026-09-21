import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/video/rule_store.dart';
import '../../core/video/source_rule.dart';
import '../../core/video/video_sources.dart';

class AnimeSourcePage extends ConsumerStatefulWidget {
  const AnimeSourcePage({super.key});

  @override
  ConsumerState<AnimeSourcePage> createState() => _AnimeSourcePageState();
}

class _AnimeSourcePageState extends ConsumerState<AnimeSourcePage> {
  List<SourceRule> _builtIn = const [];
  List<SourceRule> _imported = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = ref.read(ruleStoreProvider);
    final builtIn = await store.loadBuiltIn();
    final imported = await store.loadImported();
    if (!mounted) return;
    setState(() {
      _builtIn = builtIn;
      _imported = imported;
      _loading = false;
    });
  }

  Future<void> _importFromFile() async {
    const typeGroup = XTypeGroup(label: 'Kazumi 规则', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final rule = await ref
          .read(ruleStoreProvider)
          .importJson(await file.readAsString());
      ref.invalidate(videoSourcesProvider);
      await _load();
      messenger.showSnackBar(SnackBar(content: Text('已导入规则：${rule.name}')));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('规则无效：${e.message}')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('导入失败，请重试')));
    }
  }

  Future<void> _remove(SourceRule rule) async {
    await ref.read(ruleStoreProvider).remove(rule.name);
    ref.invalidate(videoSourcesProvider);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('动漫源管理'),
        actions: [
          IconButton(
            tooltip: '导入规则',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _importFromFile,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const _Header('已导入'),
                if (_imported.isEmpty)
                  const ListTile(
                      dense: true, title: Text('还没有导入规则'))
                else
                  for (final r in _imported)
                    ListTile(
                      title: Text(r.name),
                      subtitle: Text(r.baseUrl),
                      trailing: IconButton(
                        tooltip: '删除',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(r),
                      ),
                    ),
                const Divider(),
                const _Header('内置规则'),
                for (final r in _builtIn)
                  ListTile(
                      dense: true, title: Text(r.name), subtitle: Text(r.baseUrl)),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}
