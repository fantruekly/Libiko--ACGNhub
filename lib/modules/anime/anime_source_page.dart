import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sources/source_preferences.dart';
import '../../core/sources/source_management_widgets.dart';
import '../../core/video/rule_store.dart';
import '../../core/video/source_rule.dart';
import '../../core/video/video_sources.dart';

class AnimeSourcePage extends ConsumerStatefulWidget {
  const AnimeSourcePage({super.key});
  @override
  ConsumerState<AnimeSourcePage> createState() => _AnimeSourcePageState();
}

class _AnimeSourcePageState extends ConsumerState<AnimeSourcePage> {
  List<SourceRule> _rules = const [];
  Set<String> _imported = {};
  Map<String, RuleMetadata> _metadata = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = ref.read(ruleStoreProvider);
      final builtIn = await store.loadBuiltIn();
      final imported = await store.loadImported();
      final rules = RuleStore.mergeRules(builtIn, imported);
      final metadata = <String, RuleMetadata>{};
      for (final rule in rules) {
        metadata[rule.name] = await store.metadata(rule.name);
      }
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _metadata = metadata;
        _imported = imported.map((r) => r.name).toSet();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '源列表加载失败，请重试';
        });
      }
    }
  }

  Future<void> _mutate(
      Future<void> Function(RuleStore) action, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(ruleStoreProvider));
      ref.invalidate(allVideoSourcesProvider);
      ref.invalidate(videoSourcesProvider);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('规则无效：${error.message}')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('规则操作失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromFile() async {
    const typeGroup = XTypeGroup(label: 'Kazumi 规则', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;
    await _mutate((store) async {
      await store.importJson(await file.readAsString());
    }, '规则已导入，已有版本可回退');
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcePreferencesProvider).apply(
        SourceKind.anime, _rules, (rule) => rule.id,
        includeDisabled: true);
    final order = sources.map((rule) => rule.id).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('动漫源管理'), actions: [
        IconButton(
            tooltip: '导入规则',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _busy ? null : _importFromFile),
      ]),
      body: SourceManagementBody(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ]))
                  : ListView(padding: const EdgeInsets.all(20), children: [
                      const SourceManagementHint(
                          '禁用后不参与搜索。状态来自实际请求；导入替换前自动保留上一版本。'),
                      for (final rule in sources)
                        SourceManagementTile(
                            kind: SourceKind.anime,
                            sourceId: rule.id,
                            name: rule.name,
                            order: order,
                            subtitle: [
                              rule.baseUrl,
                              _imported.contains(rule.name) ? '已导入' : '内置规则',
                              if (_metadata[rule.name]?.version
                                  case final String version)
                                '规则版本：$version',
                              if (_metadata[rule.name]?.updatedAt
                                  case final DateTime updated)
                                '本地更新：${sourceLocalTime(updated)}',
                            ].join('\n'),
                            actions: [
                              if (_metadata[rule.name]?.hasPrevious == true)
                                TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _mutate((store) async {
                                              await store.rollback(rule.name);
                                            }, '已回退到上一版本'),
                                    icon: const Icon(Icons.restore_rounded),
                                    label: const Text('回退上一版本')),
                              if (_imported.contains(rule.name))
                                TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _mutate(
                                            (store) => store.remove(rule.name),
                                            '已删除导入规则'),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('删除导入')),
                            ]),
                    ])),
    );
  }
}
