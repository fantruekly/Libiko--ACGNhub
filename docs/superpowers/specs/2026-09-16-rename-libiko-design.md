# 项目改名 acgnhub → libiko 设计

日期：2026-09-16
状态：已与用户确认

## 背景

用户要求把项目从 `ACGNhub` / `acgnhub` 改名为 **libiko**（显示名 **Libiko**）。范围含包标识（B 级）与内部标识。

## 目标

- **显示名**：`ACGNhub` → `Libiko`。
- **包标识**：Dart 包 `acgnhub` → `libiko`；后端 `acgnhub_server` → `libiko_server`；Android `applicationId`/`namespace` → `com.libiko.libiko`；Windows exe → `libiko.exe`；各平台 bundle id / 应用名 → `libiko` / `Libiko`。
- **内部标识**：JS 全局 `__acgnhub_*` → `__libiko_*`；存储键 `acgnhub_cache` → `libiko_cache`；测试源 `acgnhub_test` → `libiko_test`。

## 非目标

- 不改历史文档 `docs/superpowers/**`、`opendesign/**`、草稿 `.superpowers/**`。
- 不改远程仓库名、文件夹名 `D:\ACGNhub`（由用户手动）。
- 不新增依赖。

## 替换映射（区分大小写，按此顺序执行）

1. `package:acgnhub_server/` → `package:libiko_server/`
2. `acgnhub_server` → `libiko_server`
3. `package:acgnhub/` → `package:libiko/`
4. `com.acgnhub.acgnhub` → `com.libiko.libiko`
5. `com.acgnhub` → `com.libiko`
6. `ACGHUB` → `LIBIKO`（含 env `ACGHUB_DB_PATH` → `LIBIKO_DB_PATH`）
7. `ACGNhub` → `Libiko`
8. `Acgnhub` → `Libiko`
9. `acgnhub` → `libiko`

## 处理范围

`lib/**`、`test/**`、`pubspec.yaml`、`android/**`、`windows/**`、`linux/**`、`macos/**`、`ios/**`、`web/**`、`server/**`、`tool/**`、`assets/comic_source/*.js`、`launch.bat`、`run.bat`、`README.md`、`SPEC.md`、`acgnhub.iml`。

## 排除

`docs/superpowers/**`、`opendesign/**`、`.superpowers/**`、`build/**`、`.dart_tool/**`、`pubspec.lock`（改为重新生成）、`ACGNhub.lnk`。

## 显示名收尾（替换后小写处改为 `Libiko`）

- `android/app/src/main/AndroidManifest.xml`：`android:label="libiko"` → `android:label="Libiko"`。
- `windows/runner/main.cpp`：窗口标题 `L"libiko"` → `L"Libiko"`。
- `windows/runner/Runner.rc`：`FileDescription` 与 `ProductName` → `"Libiko"`（`InternalName`/`OriginalFilename` 保持 `libiko` / `libiko.exe`）。
- `linux/runner/my_application.cc`：两处窗口标题 `"libiko"` → `"Libiko"`。
- `web/index.html`：`<title>libiko</title>` → `<title>Libiko</title>`；`apple-mobile-web-app-title` content → `Libiko`。
- `web/manifest.json`：`name` 与 `short_name` → `Libiko`。

## 文件/目录重命名

- `android/app/src/main/kotlin/com/acgnhub/acgnhub/MainActivity.kt` → `android/app/src/main/kotlin/com/libiko/libiko/MainActivity.kt`（`package` 声明由映射 4 变为 `com.libiko.libiko`）。
- `acgnhub.iml` → `libiko.iml`。

## 验证

- 根包：`flutter pub get` → `flutter analyze` → `flutter test`（预期 345 通过 / 1 skip）。
- `server/`：`dart pub get` → `dart test`。
- 抽查：`libiko.exe`、`com.libiko.libiko`、`__libiko_sources`、`libiko_cache`；全库无残留 `package:acgnhub/`。

## 注意

- 存储键 `acgnhub_cache` → `libiko_cache`：已有图片缓存作废（用户已同意）。
- `crypto_util.dart` 无 `acgnhub`（加密密钥不受影响，无数据不可解密风险）。
- 远程仓库名与本地文件夹名 `D:\ACGNhub` 不在本次改动内。
