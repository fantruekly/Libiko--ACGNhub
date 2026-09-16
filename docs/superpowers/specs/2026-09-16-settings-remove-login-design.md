# 设置页移除登录系统设计

日期：2026-09-16
状态：已与用户确认

## 背景

设置页（`lib/shell/settings_page.dart`）当前有「账号」区块：服务器地址输入框 + 登录/注册/退出。用户要求先在设置界面删除登录系统。

## 目标

- 从设置页移除「账号」区块；设置页只保留「缓存」「关于」。

## 非目标

- 不改 `main.dart` 的账号/同步启动逻辑。
- 不改 `lib/core/account/*`（`account_service` / `account_api` / `sync_service`）。
- 不改动漫模块（`anime_detail_page` / `anime_history` / `video_player_page`）里的同步引用。
- 不删相关测试；不新增 UI。

## 设计

`lib/shell/settings_page.dart`：

1. 移除 body 中的：

```dart
          const _SectionHeader(title: '账号'),
          const _AccountSection(),
          const Divider(),
```

2. 删除 `_AccountSection` 与 `_AccountSectionState` 两个类（第 43–204 行）。
3. 删除不再使用的 import：
   - `import 'package:flutter_riverpod/flutter_riverpod.dart';`
   - `import '../core/account/account_service.dart';`
4. 保留「缓存」「关于」区块。

结果：`SettingsPage` 仍为 `StatelessWidget`，`body` 为 `ListView`，依次为「缓存」标题 + 清除图片缓存项 + `Divider` + 「关于」标题 + ACGNhub 项。

## 影响

- 已登录态（`accountProvider`）与动漫追番/历史同步**不受影响**；只是设置页不再有登录/注册/退出的 UI 入口（后续可再加回）。
- 无测试引用 `SettingsPage`（仅 `test/core/account/account_service_test.dart` 引用 `accountProvider`，与本改动无关）。

## 测试

- `flutter analyze` 无问题（删除后无未使用 import/类）。
- `flutter test` 全量通过（现有测试不涉及设置页）。
