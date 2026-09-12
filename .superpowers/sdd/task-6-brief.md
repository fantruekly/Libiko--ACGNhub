### Task 6: UI — 追番 button + 追番 tab

**Files:**
- Modify: `lib/modules/anime/anime_detail_page.dart`
- Create: `lib/modules/anime/anime_follow.dart`
- Modify: `lib/modules/anime/anime_home.dart`

**Interfaces:**
- Consumes: `followProvider` (Task 2), `syncProvider` (Task 5), `WorkCard`, `AnimeDetailPage`, `smoothRoute`, `EmptyState`.
- Produces: the header button; `class AnimeFollowView extends ConsumerWidget`; a 5th home tab.

- [ ] **Step 1: Add the follow button to `_header`**

In `lib/modules/anime/anime_detail_page.dart`, add `import 'package:flutter_riverpod/flutter_riverpod.dart';` (already present) and
`import '../../core/services/follow_manager.dart';` plus `import '../../core/account/sync_service.dart';`.

In `_header`, insert immediately before `const WindowControls(),`:

```dart
            Consumer(builder: (context, ref, _) {
              final followed = ref.watch(followProvider).any((r) => r.work.id == w.id);
              return IconButton(
                tooltip: followed ? '已追番' : '追番',
                icon: Icon(
                  followed ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: followed ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
                ),
                onPressed: () {
                  ref.read(followProvider.notifier).toggle(w);
                  ref.read(syncProvider.notifier).schedule();
                },
              );
            }),
```

- [ ] **Step 2: Create `lib/modules/anime/anime_follow.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/follow_manager.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/work_card.dart';
import 'anime_detail_page.dart';

class AnimeFollowView extends ConsumerWidget {
  const AnimeFollowView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(followProvider);

    if (records.isEmpty) {
      return const EmptyState(icon: Icons.favorite_border_rounded, message: '还没有追番');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.66,
      ),
      itemCount: records.length,
      itemBuilder: (_, i) {
        final work = records[i].work;
        return WorkCard(
          work: work,
          onTap: () =>
              Navigator.push(context, smoothRoute(AnimeDetailPage(work: work))),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Add the 5th tab in `lib/modules/anime/anime_home.dart`**

Add `import 'anime_follow.dart';`, change `length: 4` to `length: 5`, add `Tab(text: '追番')` after 历史记录, and add `_heroTab(controller, 4, const AnimeFollowView()),` to the `TabBarView` children.

- [ ] **Step 4: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/anime/anime_detail_page.dart lib/modules/anime/anime_follow.dart lib/modules/anime/anime_home.dart
git commit -m "feat(follow): add the detail-page follow button and the 追番 tab"
```

---
