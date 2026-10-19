import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart'
    show SharePlus, ShareParams, ShareResultStatus;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/services/cache_manager.dart';
import '../core/account/sync_service.dart';
import '../core/comic/comic_favorite.dart';
import '../core/comic/comic_history.dart';
import '../core/novel/novel_favorite.dart';
import '../core/novel/novel_history.dart';
import '../core/platform.dart';
import '../core/services/follow_manager.dart';
import '../core/services/watch_history.dart';
import '../core/sources/source_preferences.dart';
import '../core/storage/database.dart';
import '../core/storage/personal_backup.dart';
import 'dart:convert';
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
  bool _backupBusy = false;

  PersonalBackupService get _backup => PersonalBackupService(
        store: AppDatabase().collections,
        readSources: () => ref.read(sourcePreferencesProvider),
        writeSources: (value) => ref
            .read(sourcePreferencesProvider.notifier)
            .restoreSnapshot(value.toJson()),
      );

  Future<void> _exportBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final bytes = utf8.encode(_backup.exportText());
      final date = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final name = 'Libiko-backup-$date.json';
      final file =
          XFile.fromData(bytes, mimeType: 'application/json', name: name);
      if (isDesktop) {
        final location = await getSaveLocation(
            suggestedName: name,
            acceptedTypeGroups: const [
              XTypeGroup(label: 'JSON', extensions: ['json'])
            ]);
        if (location == null) return;
        await file.saveTo(location.path);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('备份已保存')));
        }
      } else {
        final result = await SharePlus.instance.share(ShareParams(
            files: [file],
            fileNameOverrides: [name],
            subject: 'Libiko 个人资料备份'));
        if (mounted && result.status != ShareResultStatus.dismissed) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请选择分享面板中的保存位置，完成备份')));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('备份导出失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _importBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final file = await openFile(acceptedTypeGroups: const [
        XTypeGroup(
            label: 'Libiko 备份',
            extensions: ['json'],
            mimeTypes: ['application/json'])
      ]);
      if (file == null) return;
      if (await file.length() > PersonalBackupService.maxBytes) {
        throw const FormatException('备份文件超过 20 MB');
      }
      final service = _backup;
      final preview = service.preview(await file.readAsString());
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('合并恢复备份'),
                content: Text(
                    '此备份包含 ${preview.records} 条收藏与历史记录。\n\n将合并资料并保留较新的本地进度${preview.sources == null ? "。" : "，同时恢复源开关与排序。"}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('合并恢复')),
                ],
              ));
      if (confirmed != true || !mounted) return;
      final report = await service.restore(preview);
      ref.invalidate(watchHistoryProvider);
      ref.invalidate(followProvider);
      ref.invalidate(comicHistoryProvider);
      ref.invalidate(comicFavoritesProvider);
      ref.invalidate(novelHistoryProvider);
      ref.invalidate(novelFavoritesProvider);
      ref.read(syncProvider).schedule();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '已恢复 ${report.imported} 条记录，保留或跳过 ${report.skipped} 条记录')));
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('无法导入：${error.message}')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('恢复失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

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
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
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
          const _SectionHeader(title: '资料备份'),
          ListTile(
            key: const ValueKey('export-backup'),
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('导出备份'),
            subtitle: const Text('收藏、历史、阅读位置、源开关与顺序；不包含账号凭据和源脚本'),
            onTap: _backupBusy ? null : _exportBackup,
          ),
          ListTile(
            key: const ValueKey('import-backup'),
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('恢复备份'),
            subtitle: const Text('合并导入，保留较新的本地进度'),
            onTap: _backupBusy ? null : _importBackup,
          ),
          if (_backupBusy) const LinearProgressIndicator(),
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
            onTap: () =>
                showLicensePage(context: context, applicationName: 'Libiko'),
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
