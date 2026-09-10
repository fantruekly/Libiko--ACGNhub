### Task 15: Integration test and final verification

**Files:**
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: All previous tasks
- Produces: Working app with navigation

- [ ] **Step 1: Update widget test**

Replace `test/widget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acgnhub/main.dart';

void main() {
  testWidgets('App launches with bottom navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ACGNhubApp()));
    await tester.pumpAndSettle();

    expect(find.text('鍔ㄦ极'), findsWidgets);
    expect(find.text('婕敾'), findsWidgets);
    expect(find.text('杞诲皬璇?), findsWidgets);
    expect(find.text('娓告垙'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run all tests**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Run the app**

```bash
flutter run -d windows
```

Expected: App launches with dark theme, 4-tab navigation, anime home page showing loaded sources.

- [ ] **Step 4: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: add integration test for app shell"
```

---

## Phase 1 Completion Checklist

- [ ] App launches on Windows
- [ ] Bottom navigation with 4 tabs (鍔ㄦ极, 婕敾, 杞诲皬璇? 娓告垙)
- [ ] 鍔ㄦ极 tab shows loaded sources
- [ ] 鍔ㄦ极 search page accepts input and searches
- [ ] 鍔ㄦ极 detail page shows work info
- [ ] 鍔ㄦ极 video player plays video with controls
- [ ] Placeholder pages for comic, novel, game tabs
- [ ] Settings page accessible
- [ ] All tests pass
