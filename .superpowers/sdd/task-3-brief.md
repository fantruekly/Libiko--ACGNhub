### Task 3: 阅读设置

**Files:**
- Create: `lib/core/novel/novel_reader_settings.dart`
- Test: `test/core/novel/novel_reader_settings_test.dart`

**Interfaces:**
- Produces:
  - `enum NovelReaderTheme { light, sepia, dark }`。
  - `NovelReaderSettings { double fontSize; double lineHeight; NovelReaderTheme theme; }`，默认 `17 / 1.8 / light`；`copyWith`；`fromJson`/`toJson`（`fontSize` clamp 12–28、`lineHeight` clamp 1.2–2.6）。
  - `NovelReaderSettingsManager { NovelReaderSettings read(); Future<void> write(NovelReaderSettings s); }`，key `novel_reader_settings`。
  - `NovelReaderSettingsNotifier extends Notifier<NovelReaderSettings>`，方法 `setFontSize`/`setLineHeight`/`setTheme`。
  - `final novelReaderSettingsProvider = NotifierProvider<NovelReaderSettingsNotifier, NovelReaderSettings>(NovelReaderSettingsNotifier.new);`

- [ ] **Step 1: 写失败测试（纯模型）**

`test/core/novel/novel_reader_settings_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/novel_reader_settings.dart';

void main() {
  test('defaults', () {
    const s = NovelReaderSettings();
    expect(s.fontSize, 17);
    expect(s.lineHeight, 1.8);
    expect(s.theme, NovelReaderTheme.light);
  });

  test('copyWith changes one field', () {
    const s = NovelReaderSettings();
    final s2 = s.copyWith(fontSize: 22, theme: NovelReaderTheme.dark);
    expect(s2.fontSize, 22);
    expect(s2.theme, NovelReaderTheme.dark);
    expect(s2.lineHeight, 1.8);
  });

  test('round-trips through JSON and clamps out-of-range values', () {
    final decoded = NovelReaderSettings.fromJson(
      json.decode(json.encode(const NovelReaderSettings(fontSize: 22).toJson()))
          as Map<String, dynamic>,
    );
    expect(decoded.fontSize, 22);

    final clamped = NovelReaderSettings.fromJson(const {
      'fontSize': 99,
      'lineHeight': 0.1,
      'theme': 'sepia',
    });
    expect(clamped.fontSize, 28);
    expect(clamped.lineHeight, 1.2);
    expect(clamped.theme, NovelReaderTheme.sepia);
  });

  test('unknown theme falls back to light', () {
    final s = NovelReaderSettings.fromJson(const {'theme': 'weird'});
    expect(s.theme, NovelReaderTheme.light);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_reader_settings_test.dart`
Expected: FAIL（文件不存在）

- [ ] **Step 3: 实现 `lib/core/novel/novel_reader_settings.dart`**

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

enum NovelReaderTheme { light, sepia, dark }

class NovelReaderSettings {
  final double fontSize;
  final double lineHeight;
  final NovelReaderTheme theme;

  const NovelReaderSettings({
    this.fontSize = 17,
    this.lineHeight = 1.8,
    this.theme = NovelReaderTheme.light,
  });

  NovelReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    NovelReaderTheme? theme,
  }) =>
      NovelReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        theme: theme ?? this.theme,
      );

  factory NovelReaderSettings.fromJson(Map<String, dynamic> json) =>
      NovelReaderSettings(
        fontSize: ((json['fontSize'] as num?)?.toDouble() ?? 17)
            .clamp(12, 28)
            .toDouble(),
        lineHeight: ((json['lineHeight'] as num?)?.toDouble() ?? 1.8)
            .clamp(1.2, 2.6)
            .toDouble(),
        theme: NovelReaderTheme.values.firstWhere(
          (t) => t.name == json['theme'],
          orElse: () => NovelReaderTheme.light,
        ),
      );

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'theme': theme.name,
      };
}

class NovelReaderSettingsManager {
  static const _key = 'novel_reader_settings';

  NovelReaderSettings read() {
    final raw = AppDatabase().getString(_key);
    if (raw == null || raw.isEmpty) return const NovelReaderSettings();
    try {
      return NovelReaderSettings.fromJson(
          json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const NovelReaderSettings();
    }
  }

  Future<void> write(NovelReaderSettings settings) async {
    await AppDatabase().setString(_key, json.encode(settings.toJson()));
  }
}

class NovelReaderSettingsNotifier extends Notifier<NovelReaderSettings> {
  final _manager = NovelReaderSettingsManager();

  @override
  NovelReaderSettings build() => _manager.read();

  Future<void> _update(NovelReaderSettings next) async {
    await _manager.write(next);
    state = next;
  }

  Future<void> setFontSize(double value) =>
      _update(state.copyWith(fontSize: value.clamp(12, 28).toDouble()));

  Future<void> setLineHeight(double value) =>
      _update(state.copyWith(lineHeight: value.clamp(1.2, 2.6).toDouble()));

  Future<void> setTheme(NovelReaderTheme theme) =>
      _update(state.copyWith(theme: theme));
}

final novelReaderSettingsProvider =
    NotifierProvider<NovelReaderSettingsNotifier, NovelReaderSettings>(
        NovelReaderSettingsNotifier.new);
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_reader_settings_test.dart`
Expected: PASS（4 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/novel_reader_settings.dart test/core/novel/novel_reader_settings_test.dart
git commit -m "feat(novel): add reader settings (font/line-height/theme)"
git push
```

---
