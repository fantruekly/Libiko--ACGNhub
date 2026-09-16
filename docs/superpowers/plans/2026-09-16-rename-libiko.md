# 项目改名 acgnhub → libiko Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把项目从 `ACGNhub`/`acgnhub` 改名为 `libiko`（显示名 `Libiko`），含 Dart 包名、各平台标识、内部标识与后端包。

**Architecture:** 用同一套「区分大小写、按序」的文本替换作用于三组文件（根 Dart 包 / 平台配置 / server），再做少量显示名收尾与文件/目录重命名，最后分别验证。

**Tech Stack:** Flutter/Dart、PowerShell（无新增依赖）。

## Global Constraints

- **替换映射（区分大小写，严格按此顺序对每个文件执行）**：

  1. `package:acgnhub_server/` → `package:libiko_server/`
  2. `acgnhub_server` → `libiko_server`
  3. `package:acgnhub/` → `package:libiko/`
  4. `com.acgnhub.acgnhub` → `com.libiko.libiko`
  5. `com.acgnhub` → `com.libiko`
  6. `ACGHUB` → `LIBIKO`
  7. `ACGNhub` → `Libiko`
  8. `Acgnhub` → `Libiko`
  9. `acgnhub` → `libiko`

- **不处理**：`docs/superpowers/**`、`opendesign/**`、`.superpowers/**`、`build/**`、`.dart_tool/**`、`pubspec.lock`（改为 `flutter pub get` 重新生成）、`ACGNhub.lnk`。
- 写文件用 **UTF-8 无 BOM**（`.NET UTF8Encoding($false)`），保留原行尾。
- 在 `dev` 分支开发；每个任务结束提交一次。
- 测试命令：`C:\flutter\bin\flutter.bat test <path>`；静态检查：`C:\flutter\bin\flutter.bat analyze`；Dart：`C:\flutter\bin\dart.bat`。

**通用替换脚本（每个任务开头运行，`$Files` 换成该任务的文件列表）：**

```powershell
$utf8 = New-Object System.Text.UTF8Encoding($false)
$map = @(
  @('package:acgnhub_server/','package:libiko_server/'),
  @('acgnhub_server','libiko_server'),
  @('package:acgnhub/','package:libiko/'),
  @('com.acgnhub.acgnhub','com.libiko.libiko'),
  @('com.acgnhub','com.libiko'),
  @('ACGHUB','LIBIKO'),
  @('ACGNhub','Libiko'),
  @('Acgnhub','Libiko'),
  @('acgnhub','libiko')
)
foreach ($f in $Files) {
  $c = [System.IO.File]::ReadAllText($f)
  $o = $c
  foreach ($m in $map) { $c = $c.Replace($m[0], $m[1]) }
  if ($c -ne $o) { [System.IO.File]::WriteAllText($f, $c, $utf8); Write-Output "changed $f" }
}
```

---

## Task 1: 根 Dart 包改名

**Files:**
- Modify: `pubspec.yaml`、`lib/**/*.dart`、`test/**/*.dart`、`assets/comic_source/init.js`、`assets/comic_source/test_source.js`
- Regenerate: `pubspec.lock`

### Step 1: 运行替换

```powershell
$Files = @('pubspec.yaml') + (Get-ChildItem -Recurse -File lib,test -Include *.dart | Select-Object -ExpandProperty FullName) + @('assets/comic_source/init.js','assets/comic_source/test_source.js')
# ...（运行上面的通用替换脚本）
```

### Step 2: 校验替换结果

Run:
- `Select-String -Path (Get-ChildItem -Recurse -File lib,test -Include *.dart).FullName -Pattern 'package:acgnhub/'` → 应无输出。
- `Select-String -Path pubspec.yaml -Pattern '^name:'` → `name: libiko`。
- `Select-String -Path lib\main.dart -Pattern 'ACGNhub|Libiko'` → 应为 `Libiko`。

### Step 3: 重新生成锁文件 + 静态检查 + 测试

Run:
- `C:\flutter\bin\flutter.bat pub get`
- `C:\flutter\bin\flutter.bat analyze`
- `C:\flutter\bin\flutter.bat test`
Expected: analyze `No issues found!`；测试 345 通过 / 1 skip。

### Step 4: 提交

```bash
git add pubspec.yaml pubspec.lock lib test assets/comic_source
git commit -m "refactor: rename the app package to libiko"
```

---

## Task 2: 平台标识 + 显示名 + 文件重命名

**Files:**
- Modify: `android/app/build.gradle.kts`、`android/app/src/main/AndroidManifest.xml`、`android/app/src/main/kotlin/**/MainActivity.kt`、`windows/CMakeLists.txt`、`windows/runner/main.cpp`、`windows/runner/Runner.rc`、`linux/CMakeLists.txt`、`linux/runner/my_application.cc`、`macos/Runner/Configs/AppInfo.xcconfig`、`macos/Runner.xcodeproj/project.pbxproj`、`ios/Runner/Info.plist`、`ios/Runner.xcodeproj/project.pbxproj`、`web/index.html`、`web/manifest.json`、`tool/gen_seed.dart`、`launch.bat`、`run.bat`、`README.md`、`SPEC.md`
- Rename: `android/.../com/acgnhub/acgnhub/MainActivity.kt` → `android/.../com/libiko/libiko/MainActivity.kt`；`acgnhub.iml` → `libiko.iml`

### Step 1: 运行替换

```powershell
$Files = @(
  'android/app/build.gradle.kts','android/app/src/main/AndroidManifest.xml',
  'windows/CMakeLists.txt','windows/runner/main.cpp','windows/runner/Runner.rc',
  'linux/CMakeLists.txt','linux/runner/my_application.cc',
  'macos/Runner/Configs/AppInfo.xcconfig','macos/Runner.xcodeproj/project.pbxproj',
  'ios/Runner/Info.plist','ios/Runner.xcodeproj/project.pbxproj',
  'web/index.html','web/manifest.json','tool/gen_seed.dart',
  'launch.bat','run.bat','README.md','SPEC.md'
) + (Get-ChildItem -Recurse -File android\app\src\main\kotlin -Include MainActivity.kt | Select-Object -ExpandProperty FullName)
# ...（运行通用替换脚本）
```

### Step 2: 显示名收尾

- `android/app/src/main/AndroidManifest.xml`：`android:label="libiko"` → `android:label="Libiko"`。
- `windows/runner/main.cpp`：`L"libiko"` → `L"Libiko"`。
- `windows/runner/Runner.rc`：`"FileDescription", "libiko"` → `"Libiko"`；`"ProductName", "libiko"` → `"Libiko"`。
- `linux/runner/my_application.cc`：两处 `"libiko"` → `"Libiko"`。
- `web/index.html`：`<title>libiko</title>` → `<title>Libiko</title>`；`content="libiko"` → `content="Libiko"`。
- `web/manifest.json`：`"name": "libiko"` → `"Libiko"`；`"short_name": "libiko"` → `"Libiko"`。

### Step 3: 文件/目录重命名

```powershell
New-Item -ItemType Directory -Force -Path "android\app\src\main\kotlin\com\libiko\libiko" | Out-Null
git mv "android/app/src/main/kotlin/com/acgnhub/acgnhub/MainActivity.kt" "android/app/src/main/kotlin/com/libiko/libiko/MainActivity.kt"
Remove-Item -Recurse -Force "android\app\src\main\kotlin\com\acgnhub" -ErrorAction SilentlyContinue
git mv acgnhub.iml libiko.iml
```

（若 `git mv` 对旧目录报错，先用文件系统移动再 `git add -A`。）

### Step 4: 校验

Run:
- `Select-String -Path (Get-ChildItem -Recurse -File android,windows,linux,macos,ios,web,tool -Include *.kts,*.xml,*.txt,*.cpp,*.rc,*.cc,*.xcconfig,*.pbxproj,*.plist,*.html,*.json,*.dart).FullName -Pattern 'acgnhub'` → 应无输出。
- `Select-String -Path android\app\src\main\AndroidManifest.xml,windows\runner\Runner.rc,web\manifest.json -Pattern 'Libiko'` → 命中。
- `C:\flutter\bin\flutter.bat analyze`
Expected: 无残留 `acgnhub`；analyze 无问题。

### Step 5: 提交

```bash
git add -A android windows linux macos ios web tool launch.bat run.bat README.md SPEC.md libiko.iml
git commit -m "chore: rename platform identifiers and display name to Libiko"
```

---

## Task 3: 后端包改名

**Files:**
- Modify: `server/pubspec.yaml`、`server/bin/server.dart`、`server/Dockerfile`、`server/test/*.dart`（及 `server/**` 内其它含 acgnhub 的文件）
- Regenerate: `server/pubspec.lock`

### Step 1: 运行替换

```powershell
$Files = (Get-ChildItem -Recurse -File server | Where-Object { $_.Extension -in '.dart','.yaml','.yml','.md','.txt' -and $_.Name -ne 'pubspec.lock' } | Select-Object -ExpandProperty FullName)
# ...（运行通用替换脚本）
```

### Step 2: 校验 + 测试

Run:
- `Select-String -Path (Get-ChildItem -Recurse -File server -Include *.dart).FullName -Pattern 'acgnhub'` → 应无输出。
- `C:\flutter\bin\dart.bat pub get`（workdir `server`）
- `C:\flutter\bin\dart.bat test`（workdir `server`）
Expected: 无残留；server 测试通过。

### Step 3: 提交

```bash
git add server
git commit -m "refactor(server): rename the backend package to libiko_server"
```

---

## Task 4: 全量回归

- [ ] **Step 1: 根包全量**

Run: `C:\flutter\bin\flutter.bat analyze`；`C:\flutter\bin\flutter.bat test`
Expected: 无问题；345 通过 / 1 skip。

- [ ] **Step 2: 残留检查**

Run: `git grep -il acgnhub` → 只应剩 `docs/superpowers/**`、`opendesign/**`、`.superpowers/**`、`ACGNhub.lnk`（有意保留）。

---

## 手动验证（合并前，由用户执行）

- Windows：`flutter run -d windows`，标题栏/任务栏显示 Libiko。
- 运行后确认漫画 JS 源仍能加载（`__libiko_*` 全局生效）、图片缓存重建正常。

## 自查记录（Self-Review）

- **Spec 覆盖**：根 Dart 包 → Task 1；平台标识/显示名/文件重命名 → Task 2；server → Task 3；回归 → Task 4。
- **类型一致性**：替换映射在三个任务中一致；`MainActivity.kt` 的 `package` 由映射 4 得到 `com.libiko.libiko`，与目录 `com/libiko/libiko` 一致。
- **占位符**：无 TBD/TODO；给出完整脚本与命令。
- **注意**：写文件用 UTF-8 无 BOM，避免 PowerShell 5.1 的 BOM 破坏 CMake/XML/Dart 文件。
