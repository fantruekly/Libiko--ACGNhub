# 设置页移除登录系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从设置页移除「账号」区块（服务器地址 + 登录/注册/退出），设置页只保留「缓存」「关于」。

**Architecture:** 仅改 `lib/shell/settings_page.dart`：删除账号区块与相关类/import；新增一个 widget 测试断言登录 UI 已消失、其余区块仍在。底层 account/sync 服务与动漫同步不动。

**Tech Stack:** Flutter (Dart 3.6)（无新增依赖）。

## Global Constraints

- 仅改动 `lib/shell/settings_page.dart` + 新增 `test/shell/settings_page_test.dart`。
- 不改 `main.dart`、`lib/core/account/*`、动漫模块的同步引用、相关测试。
- 无新增依赖。不添加代码注释（除非下方给定代码已含）。
- 在 `dev` 分支开发；完成后提交。
- 测试命令：`C:\flutter\bin\flutter.bat test <path>`；静态检查：`C:\flutter\bin\flutter.bat analyze`。

---

## Task 1: 移除设置页「账号」区块

**Files:**
- Modify: `lib/shell/settings_page.dart`
- Test: `test/shell/settings_page_test.dart`

### Step 1: 写测试（先失败）

Create `test/shell/settings_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/shell/settings_page.dart';

void main() {
  testWidgets('settings page no longer shows the account/login UI',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('账号'), findsNothing);
    expect(find.text('服务器地址'), findsNothing);
    expect(find.text('登录'), findsNothing);
    expect(find.text('注册'), findsNothing);
    expect(find.text('退出登录'), findsNothing);

    expect(find.text('缓存'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
  });
}
```

Run: `C:\flutter\bin\flutter.bat test test/shell/settings_page_test.dart`
Expected: FAIL —— 当前设置页含「账号」「服务器地址」「登录」等。

### Step 2: 移除账号区块

在 `lib/shell/settings_page.dart`：

1) 删除 `body` 中的这三行（第 15–17 行）：

```dart
          const _SectionHeader(title: '账号'),
          const _AccountSection(),
          const Divider(),
```

2) 删除 `_AccountSection` 与 `_AccountSectionState` 两个类（第 43–204 行）。

3) 删除不再使用的 import（第 2–4 行）：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```
```dart
import '../core/account/account_service.dart';
```

删除后 `lib/shell/settings_page.dart` 应为：

```dart
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
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
```

### Step 3: 运行测试确认通过

Run:
- `C:\flutter\bin\flutter.bat test test/shell/settings_page_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: PASS；analyze `No issues found!`。

### Step 4: 全量回归 + 提交

Run: `C:\flutter\bin\flutter.bat test`
Expected: 全部 PASS。

```bash
git add lib/shell/settings_page.dart test/shell/settings_page_test.dart
git commit -m "feat(settings): remove the account/login section"
```

---

## 手动验证（合并前，由用户执行）

运行应用 → 打开「设置」：不再有「账号」区块（服务器地址/登录/注册/退出）；「缓存」「关于」仍在。

## 自查记录（Self-Review）

- **Spec 覆盖**：删除账号区块 + 两个类 + 两个 import → Task 1；回归测试 → Step 1。
- **类型一致性**：`SettingsPage` 仍为 `StatelessWidget`；`_SectionHeader` 保留；删除后无 `ref`/`AccountState` 引用。
- **占位符**：无 TBD/TODO；给出完整目标文件内容与命令。
