# Task 3 Report: Dependencies + `MediaKit` init + `StreamResolver`

## Status: DONE_WITH_CONCERNS

## What I did
1. Added four dependencies under `dependencies:` in `pubspec.yaml`:
   - `flutter_inappwebview: ^6.1.5`
   - `media_kit: ^1.2.0`
   - `media_kit_video: ^1.2.0`
   - `media_kit_libs_windows_video: ^1.0.9`
   Ran `flutter pub get` → `Changed 26 dependencies!` (flutter_inappwebview 6.1.5, media_kit 1.2.6, media_kit_video 1.3.1, media_kit_libs_windows_video 1.0.11).
2. Added `import 'package:media_kit/media_kit.dart';` and `MediaKit.ensureInitialized();` (after `WidgetsFlutterBinding.ensureInitialized()`) in `lib/main.dart`.
3. Created `lib/core/video/stream_resolver.dart` verbatim from the brief (headless webview capturing `.m3u8`/`.mp4` via `shouldInterceptRequest` + injected JS hooks on XHR/fetch/`<video>`).
4. Committed the 4 files listed in the brief.
5. Self-review: file contents match the brief exactly; committed diff is only the 4 intended files.

## Analyze output
```
$ flutter analyze lib
Analyzing lib...
No issues found! (ran in 5.1s)
```

## Build output
```
$ flutter build windows --debug
...
Building Windows application...                                   178.3s
√ Built build\windows\x64\runner\Debug\acgnhub.exe
EXIT_CODE=0
ELAPSED_SECONDS=182.1
```
`build\windows\x64\runner\Debug\acgnhub.exe` exists.

## Download / environment issues encountered
1. **mpv + ANGLE integrity failure (first two build attempts).** CMake's `file(DOWNLOAD)` produced 0-byte archives and failed the MD5 check:
   ```
   CMake Error at .../media_kit_libs_windows_video/windows/CMakeLists.txt:43 (message):
     D:/ACGNhub/build/windows/x64/mpv-dev-x86_64-20230924-git-652a1dd.7z
     Integrity check failed, please try to re-build project again.
   ```
   Cause: CMake `file(DOWNLOAD)` does not honor the Windows system proxy. Fix: manually downloaded both archives through the system proxy (`http://127.0.0.1:10888`) into `build/windows/x64/` and verified MD5s:
   - `mpv-dev-x86_64-20230924-git-652a1dd.7z` → `a832ef24b3a6ff97cd2560b5b9d04cd8` (expected match)
   - `ANGLE.7z` → `e866f13e8d552348058afaafe869b1ed` (expected match)
2. **NuGet CLI missing (third build attempt).** `flutter_inappwebview_windows` requires `nuget` to fetch its native deps:
   ```
   error MSB3073: NUGET-NOTFOUND install Microsoft.Windows.ImplementationLibrary -Version 1.0.231216.1 ...
   error MSB3073: NUGET-NOTFOUND install Microsoft.Web.WebView2 -Version 1.0.2792.45 ...
   error MSB3073: NUGET-NOTFOUND install nlohmann.json -Version 3.11.2 ...
   ... exited with code 9009.
   ```
   Fix: downloaded `nuget.exe` (7.9.0.83) to `C:\Users\26568\AppData\Local\Temp\opencode\nuget.exe` and prepended that directory to `PATH` for the build command. The successful build was run with:
   ```powershell
   $env:Path = "C:\flutter\bin;C:\Users\26568\AppData\Local\Temp\opencode;$env:Path"; flutter build windows --debug
   ```
   `nuget.exe` itself was fetched via the proxy; NuGet then used the system proxy automatically to pull the packages into `build/windows/x64/packages`.

## Files changed (commit `6cb8766`)
- `pubspec.yaml` (+4)
- `pubspec.lock` (+208)
- `lib/main.dart` (+2)
- `lib/core/video/stream_resolver.dart` (new, 66 lines)

## Concerns
- **NuGet CLI is a hard prerequisite** for `flutter build windows` now that `flutter_inappwebview_windows` is a dependency. It is not installed system-wide; I only put it on `PATH` for the build invocation via a temp copy. A future build from a clean shell (without that PATH) will fail with `MSB3073 / 9009`. Recommend installing NuGet system-wide (`winget install Microsoft.NuGet` or dropping `nuget.exe` on `PATH`) or documenting it in the build setup.
- **CMake does not use the Windows system proxy.** Future clean builds / CI will re-fail the mpv+ANGLE download unless `http_proxy`/`https_proxy` env vars are set for CMake or the archives are pre-seeded. The archives currently live in `build/` (gitignored), so they will not persist across `flutter clean`.
- **Generated plugin registrant files were modified but not committed**, per the brief's exact file list: `linux/flutter/generated_plugin_registrant.cc`, `linux/flutter/generated_plugins.cmake`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `windows/flutter/generated_plugin_registrant.cc`, `windows/flutter/generated_plugins.cmake`. They regenerate on `flutter pub get`/build, but consider committing them so the Windows plugin wiring is present without a regen step.
- Non-fatal CMake `CMP0175` warnings and MSVC C4819/C4244/C4458 warnings from the plugins; no action needed.
- Pre-existing unrelated working-tree changes (`tool/gen_seed.dart` deletion, `.superpowers/sdd/*` edits, untracked `docs/superpowers/*`) were left untouched.

## Final review fixes

Final code-review pass on the UI polish feature (`lib/modules/anime/anime_detail_page.dart` + `pubspec.yaml`).

1. **Glass info/summary cards (Important).** Wrapped the info `Row(...)` in `_infoSection` and the summary `Column(...)` in `_summarySection` in `GlassSurface` (radius 16, padding 16, `0xFFE5E5EA` border, `0x0F000000` shadow), keeping the outer `Padding`s.
2. **Episode button hover lift (Important).** Each episode button is now a transparent `Material` + `InkWell` with `hoverColor` primary@12% and `splashColor` primary@16%; fill changed to primary@6% with the border kept.
3. **Source chip restyle (Minor).** `ChoiceChip` now uses `showCheckmark: false`, `selectedColor` primary@14%, `backgroundColor` primary@5%, a conditional primary-alpha `side`, and radius-10 shape.
4. **Drop `url_launcher` (Minor).** Removed `url_launcher: ^6.3.1` from `pubspec.yaml`; `flutter pub get` reported the 8 `url_launcher*` packages as "no longer being depended on".
5. **Formatting (Minor).** Ran `dart format lib test` (new Dart 3.9 tall style reformatted 51 files).
6. **Pre-existing lint infos fixed** (needed for the expected `No issues found!`): added braces to `if (mounted)` in `_load()` and `if (feed == AnimeFeed.today)` in `lib/core/metadata/jikan_provider.dart`.

### Command outputs

`flutter pub get`:
```
Resolving dependencies...
Downloading packages...
These packages are no longer being depended on:
- url_launcher 6.3.2
- url_launcher_android 6.3.29
- url_launcher_ios 6.3.6
- url_launcher_linux 3.2.2
- url_launcher_macos 3.2.5
- url_launcher_platform_interface 2.3.2
- url_launcher_web 2.4.1
- url_launcher_windows 3.1.5
Changed 8 dependencies!
```

`dart format lib test`:
```
Formatted 52 files (51 changed) in 0.42 seconds.
```

`flutter analyze lib test`:
```
Analyzing 2 items...
No issues found! (ran in 4.1s)
```

`flutter test`:
```
00:05 +44: All tests passed!
```

`flutter build windows --debug`:
```
Building Windows application...                                    26.6s
√ Built build\windows\x64\runner\Debug\acgnhub.exe
```
