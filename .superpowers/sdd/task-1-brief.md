### Task 1: Add the Android webview dependency

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock` (generated)

**Interfaces:**
- Consumes: nothing.
- Produces: `flutter_inappwebview` available for later tasks.

- [ ] **Step 1: Add the dependency**

Run:
```powershell
C:\flutter\bin\flutter.bat pub add flutter_inappwebview
```
Expected: `Changed 1 dependency!` and `pubspec.yaml` gains a `flutter_inappwebview:` line.

- [ ] **Step 2: Verify the Android build still succeeds**

Run:
```powershell
C:\flutter\bin\flutter.bat build apk --release
```
Expected: `鉁?Built build\app\outputs\flutter-apk\app-release.apk`

(If Gradle fails on a plugin/AGP mismatch, resolve it here before continuing 鈥?later tasks depend on a working Android build.)

- [ ] **Step 3: Commit**

```powershell
git add pubspec.yaml pubspec.lock
git commit -m "build: add flutter_inappwebview for the android headless browser"
```

---

