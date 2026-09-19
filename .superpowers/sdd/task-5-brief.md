### Task 5: Touch controls on Android

**Files:**
- Modify: `lib/modules/anime/video_player_page.dart`

**Interfaces:**
- Consumes: `isDesktop` from `lib/core/platform.dart`.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Add the platform import**

In `lib/modules/anime/video_player_page.dart` add:
```dart
import '../../core/platform.dart';
```

- [ ] **Step 2: Split the controls theme builder by platform**

Rename the existing `_controlsTheme` to `_desktopControlsTheme` (body unchanged) and add:
```dart
  MaterialVideoControlsThemeData _mobileControlsTheme(BuildContext context,
      {bool showEpisodes = true}) {
    return MaterialVideoControlsThemeData(
      topButtonBar: [
        MaterialCustomButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            widget.work.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3),
          ),
        ),
      ],
      bottomButtonBar: [
        const MaterialPositionIndicator(),
        const Spacer(),
        if (showEpisodes)
          MaterialCustomButton(
            icon: const Icon(Icons.list_rounded),
            onPressed: () => setState(() => _panelOpen = !_panelOpen),
          ),
        const MaterialFullscreenButton(),
      ],
    );
  }
```

- [ ] **Step 3: Pick the theme and controls in `build`**

Replace the `Positioned.fill` child in `build` with:
```dart
          Positioned.fill(
            child: isDesktop
                ? MaterialDesktopVideoControlsTheme(
                    normal: _desktopControlsTheme(context),
                    fullscreen:
                        _desktopControlsTheme(context, showEpisodes: false),
                    child: _video(),
                  )
                : MaterialVideoControlsTheme(
                    normal: _mobileControlsTheme(context),
                    fullscreen:
                        _mobileControlsTheme(context, showEpisodes: false),
                    child: _video(),
                  ),
          ),
```
and add this helper to the state class:
```dart
  Widget _video() => Video(
        controller: _controller,
        fit: BoxFit.contain,
        fill: Colors.black,
        controls: isDesktop
            ? MaterialDesktopVideoControls
            : MaterialVideoControls,
      );
```

- [ ] **Step 4: Run analyzer and tests**

Run:
```powershell
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test
```
Expected: `No issues found!`; all tests pass.

- [ ] **Step 5: Verify on the emulator**

Run:
```powershell
C:\flutter\bin\flutter.bat build apk --release
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb install -r build\app\outputs\flutter-apk\app-release.apk
```
Then play an episode and confirm: touch controls appear, tap toggles them, the fullscreen button rotates to landscape, and the episode-list button opens the panel.

- [ ] **Step 6: Verify Windows is untouched**

Run:
```powershell
C:\flutter\bin\flutter.bat build windows --release
```
Launch it and confirm the desktop controls (hover bar, volume, position indicator, min/max/close) are unchanged.

- [ ] **Step 7: Commit**

```powershell
git add lib/modules/anime/video_player_page.dart
git commit -m "feat(player): use touch video controls on android"
```

---

