### Task 1: Scaffold Flutter project

**Files:**
- Create: entire Flutter project structure via `flutter create`

**Interfaces:**
- Produces: Standard Flutter project with `lib/main.dart`, `pubspec.yaml`, `test/`, `windows/`

- [ ] **Step 1: Create Flutter project**

```bash
cd D:\ACGNhub
flutter create --org com.acgnhub --project-name acgnhub .
```

- [ ] **Step 2: Configure pubspec.yaml with dependencies**

Replace the generated `pubspec.yaml` with:

```yaml
name: acgnhub
description: ACGNhub - Anime, Comic, Game, Novel aggregation app
publish_to: 'none'
version: 0.1.0

environment:
  sdk: '>=3.6.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  dio: ^5.7.0
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0
  flutter_cache_manager: ^3.4.1
  media_kit: ^1.2.0
  media_kit_video: ^1.2.0
  media_kit_libs_windows_video: ^1.0.9
  html: ^0.15.5
  xml: ^6.5.0
  cached_network_image: ^3.4.1
  shared_preferences: ^2.3.4
  path_provider: ^2.1.5
  path: ^1.9.0
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/rules/
```

- [ ] **Step 3: Create assets directory**

```bash
mkdir -p assets\rules
```

- [ ] **Step 4: Run flutter pub get**

```bash
flutter pub get
```

- [ ] **Step 5: Verify project builds**

```bash
flutter build windows --debug
```

Expected: Build succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter project with dependencies"
```

---


