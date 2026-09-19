import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'source_hub_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader(title: '源'),
          ListTile(
            leading: const Icon(Icons.add_link_rounded),
            title: const Text('添加源'),
            subtitle: const Text('为动漫 / 漫画 / 轻小说 / 游戏添加资源来源'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SourceHubPage())),
          ),
          const Divider(),
          const _SectionHeader(title: '缓存'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清除图片缓存'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: '关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Libiko'),
            subtitle: Text('v0.1.0 - 动漫聚合应用'),
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
