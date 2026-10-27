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
import '../core/services/update_controller.dart';
import '../core/services/update_service.dart';
import '../core/theme/theme_mode.dart';
import '../core/ui/update_dialog.dart';
import '../core/ui/open_url.dart';
import '../core/widgets/content_panel.dart';
import 'source_hub_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _version = '';
  int _cacheBytes = -1;
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
    final controller = ref.read(updateControllerProvider);
    if (controller.checking) return;
    final result = await controller.check(manual: true);
    if (!mounted) return;
    if (result == UpdateCheckResult.available) {
      await showUpdateDialog(context, controller.update!, controller);
    } else if (result == UpdateCheckResult.upToDate) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已是最新正式版本')));
    } else if (result == UpdateCheckResult.failed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(controller.error!),
        action: SnackBarAction(label: '重试', onPressed: _checkForUpdate),
      ));
    }
  }

  Future<void> _setAutomaticUpdate(bool value) async {
    try {
      await ref.read(updateControllerProvider).setAutomatic(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('更新设置保存失败，请重试')));
      }
    }
  }

  Future<void> _openReleasePage() async {
    final opened = await openExternalUrl(UpdateService.releasesUrl);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开浏览器，请稍后重试')));
    }
  }

  String _updateStatus(UpdateController controller) {
    if (controller.checking) return '正在获取最新正式版本…';
    if (controller.error != null) return controller.error!;
    if (controller.update != null) {
      final version = controller.update!.version;
      return '发现 v$version${controller.skippedVersion == version ? '（已跳过自动提醒）' : ''}';
    }
    final checked = controller.lastChecked?.toLocal();
    if (checked == null) return '查看最新版本与更新说明';
    String two(int value) => value.toString().padLeft(2, '0');
    return '上次检查 ${checked.year}-${two(checked.month)}-${two(checked.day)} ${two(checked.hour)}:${two(checked.minute)}';
  }

  String get _cacheLabel => _cacheBytes < 0
      ? '清除图片缓存'
      : '清除图片缓存（约 ${(_cacheBytes / 1024 / 1024).toStringAsFixed(1)} MB）';

  List<Widget> _section(String title, List<Widget> children) => [
        _SectionHeader(title: title),
        ContentPanel(child: Column(children: children)),
      ];

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appThemeModeProvider);
    final updates = ref.watch(updateControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
            width: 920,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                ..._section('外观', [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (value, label) in const [
                              (ThemeMode.system, '跟随系统'),
                              (ThemeMode.light, '浅色'),
                              (ThemeMode.dark, '深色'),
                            ])
                              ChoiceChip(
                                  label: Text(label),
                                  selected: mode == value,
                                  labelStyle: const TextStyle(
                                      fontFamily: 'NotoSansSC',
                                      fontWeight: FontWeight.w400),
                                  onSelected: (_) => ref
                                      .read(appThemeModeProvider.notifier)
                                      .set(value)),
                          ],
                        )),
                  ),
                ]),
                ..._section('缓存', [
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text(_cacheLabel),
                    onTap: _clearCache,
                  ),
                ]),
                ..._section('资料备份', [
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
                ]),
                ..._section('关于与更新', [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('版本'),
                    subtitle: Text(_version.isEmpty ? '—' : _version),
                  ),
                  ListTile(
                    leading: const Icon(Icons.system_update_alt_rounded),
                    title: const Text('检查更新'),
                    subtitle: Text(_updateStatus(updates)),
                    trailing: updates.checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : updates.error != null
                            ? IconButton(
                                tooltip: '打开发布页',
                                icon: const Icon(Icons.open_in_new_rounded),
                                onPressed: _openReleasePage)
                            : null,
                    onTap: updates.checking ? null : _checkForUpdate,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.update_rounded),
                    title: const Text('自动检查更新'),
                    subtitle: const Text('启动时检查，12 小时内不重复；关闭后仍可手动检查'),
                    value: updates.automatic,
                    onChanged: _setAutomaticUpdate,
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('开源许可'),
                    onTap: () => showLicensePage(
                        context: context, applicationName: 'Libiko'),
                  ),
                ]),
                ..._section('源', [
                  ListTile(
                    leading: const Icon(Icons.add_link_rounded),
                    title: const Text('添加源'),
                    subtitle: const Text('为动漫 / 漫画 / 轻小说 / 游戏添加资源来源'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SourceHubPage())),
                  ),
                ]),
              ],
            )),
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
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}
