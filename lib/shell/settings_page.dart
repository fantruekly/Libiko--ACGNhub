import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/services/cache_manager.dart';
import '../core/services/update_service.dart';
import '../core/theme/theme_mode.dart';
import '../core/ui/open_url.dart';
import 'source_hub_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _version = '';
  int _cacheBytes = -1;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadCacheSize();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = 'v${info.version} (${info.buildNumber})');
      }
    } catch (_) {}
  }

  Future<void> _loadCacheSize() async {
    final bytes = await _cacheBytesOnDisk();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  Future<int> _cacheBytesOnDisk() async {
    try {
      final tmp = await getTemporaryDirectory();
      var total = 0;
      for (final name in [AppCacheManager.key, 'libCachedImageData']) {
        final dir = Directory(p.join(tmp.path, name));
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return -1;
    }
  }

  Future<void> _clearCache() async {
    try {
      await AppCacheManager().emptyCache();
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await _loadCacheSize();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('缓存已清除')));
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final update = await UpdateService().check(info.version);
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已是最新版本')));
      } else {
        await _showUpdateDialog(update);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('检查更新失败')));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo update) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('发现新版本 v${update.version}'),
        content: update.notes.isEmpty
            ? null
            : SingleChildScrollView(child: Text(update.notes)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('稍后')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              unawaited(openExternalUrl(update.url));
            },
            child: const Text('去下载'),
          ),
        ],
      ),
    );
  }

  String get _cacheLabel => _cacheBytes < 0
      ? '清除图片缓存'
      : '清除图片缓存（约 ${(_cacheBytes / 1024 / 1024).toStringAsFixed(1)} MB）';

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appThemeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader(title: '外观'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
                ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
              ],
              selected: {mode},
              onSelectionChanged: (selection) =>
                  ref.read(appThemeModeProvider.notifier).set(selection.first),
            ),
          ),
          const Divider(),
          const _SectionHeader(title: '缓存'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(_cacheLabel),
            onTap: _clearCache,
          ),
          const Divider(),
          const _SectionHeader(title: '关于与更新'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            subtitle: Text(_version.isEmpty ? '—' : _version),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt_rounded),
            title: const Text('检查更新'),
            trailing: _checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _checking ? null : _checkForUpdate,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('开源许可'),
            onTap: () => showLicensePage(context: context, applicationName: 'Libiko'),
          ),
          const Divider(),
          const _SectionHeader(title: '源'),
          ListTile(
            leading: const Icon(Icons.add_link_rounded),
            title: const Text('添加源'),
            subtitle: const Text('为动漫 / 漫画 / 轻小说 / 游戏添加资源来源'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SourceHubPage())),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

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
