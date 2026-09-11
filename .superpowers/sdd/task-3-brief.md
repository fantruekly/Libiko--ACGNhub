### Task 3: Remove the source label from cards

**Files:**
- Modify: `lib/core/widgets/work_card.dart`

**Interfaces:**
- Produces: `WorkCard({Work work, VoidCallback? onTap})` — no `subtitle`, no source-name line.

- [ ] **Step 1: Remove the subtitle**

In `lib/core/widgets/work_card.dart`:
1. Remove the `final String? subtitle;` field and the `this.subtitle` constructor parameter.
2. Remove the line `final sub = subtitle ?? work.sourceName;`.
3. Remove the conditional `if (sub.isNotEmpty) Text(sub, ...)` widget (and its preceding `const SizedBox`/spacing if it becomes orphaned).

The `build` method's `children` should end with the title `Text` (2-line clamp) only.

- [ ] **Step 2: Verify**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib/core/widgets/work_card.dart`
Expected: No issues found.

- [ ] **Step 3: Commit (only if user asked)**

```bash
git add lib/core/widgets/work_card.dart
git commit -m "style(anime): drop the source label from work cards"
```

---
