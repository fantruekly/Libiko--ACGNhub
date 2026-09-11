# Anime Detail Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the anime detail page reliably show summary, a star rating, and basic info (episodes, year, status, format) — including offline.

**Architecture:** Add a reusable `RatingStars` widget; normalize `Work.extra['score']` to a 0–10 double in the AniList provider; restructure the detail page to use the widget and a single consolidated info area; enrich the bundled offline seed with summaries/scores.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, cached_network_image, flutter_test.

## Global Constraints

- Target platform: Windows first.
- Light theme; do not touch `main.dart` theme or the shell.
- `Work.extra['score']` is always a **0–10 double** (or absent).
- Anime-specific data lives in `Work.extra`; `Work` stays generic.
- No playback/player work in this plan (separate spec).
- Commits: only run the `git commit` steps if the user explicitly asks; otherwise treat them as checkpoints.

---

### Task 1: `RatingStars` widget

**Files:**
- Create: `lib/core/widgets/rating_stars.dart`
- Test: `test/core/widgets/rating_stars_test.dart`

**Interfaces:**
- Produces: `class RatingStars extends StatelessWidget { final double? score; final double size; const RatingStars({super.key, this.score, this.size = 18}); }`

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/rating_stars_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/widgets/rating_stars.dart';

void main() {
  testWidgets('8.5 renders 4 full stars, 1 half star, and the numeric label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RatingStars(score: 8.5))));
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget);
  });

  testWidgets('null renders nothing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RatingStars(score: null))));
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('0 renders no filled stars but the numeric label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RatingStars(score: 0))));
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.text('0.0'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/widgets/rating_stars_test.dart`
Expected: FAIL — `rating_stars.dart` not found.

- [ ] **Step 3: Implement `RatingStars`**

Create `lib/core/widgets/rating_stars.dart`:

```dart
import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double? score; // 0-10 scale
  final double size;

  const RatingStars({super.key, this.score, this.size = 18});

  static const _gold = Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    final s = score;
    if (s == null) return const SizedBox.shrink();

    final scaled = s.clamp(0, 10) / 2; // 0-5 stars
    final full = scaled.floor();
    final hasHalf = (scaled - full) >= 0.25;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < full
                ? Icons.star_rounded
                : (i == full && hasHalf ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: _gold,
          ),
        const SizedBox(width: 6),
        Text(
          s.clamp(0, 10).toStringAsFixed(1),
          style: TextStyle(fontSize: size * 0.8, fontWeight: FontWeight.w600, color: _gold),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/widgets/rating_stars_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/core/widgets/rating_stars.dart test/core/widgets/rating_stars_test.dart
git commit -m "feat(anime): add RatingStars widget"
```

---

### Task 2: Normalize AniList score to 0–10

**Files:**
- Modify: `lib/core/metadata/anilist_provider.dart`
- Test: `test/core/metadata/anilist_provider_test.dart`

**Interfaces:**
- Produces: AniList `Work.extra['score']` is `averageScore / 10` (a 0–10 double), or absent when `averageScore` is null.

- [ ] **Step 1: Update the failing assertion in the existing test**

In `test/core/metadata/anilist_provider_test.dart`, the existing assertion `expect(w.extra['score'], 88);` must become a 0–10 expectation. Replace it with:

```dart
    expect(w.extra['score'], closeTo(8.8, 0.001));
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/anilist_provider_test.dart`
Expected: FAIL — actual `88` is not close to `8.8`.

- [ ] **Step 3: Implement the normalization**

In `lib/core/metadata/anilist_provider.dart`, inside `parseMedia`, change the `'score'` entry from:

```dart
        'score': m['averageScore'],
```
to:
```dart
        'score': _normalizeScore(m['averageScore']),
```

Add this static helper to `AniListProvider` (next to `_strip`):

```dart
  static double? _normalizeScore(dynamic averageScore) {
    if (averageScore is num) return averageScore / 10;
    return null;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/anilist_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/core/metadata/anilist_provider.dart test/core/metadata/anilist_provider_test.dart
git commit -m "fix(metadata): normalize AniList score to a 0-10 scale"
```

---

### Task 3: Detail page uses `RatingStars` and consolidated info

**Files:**
- Modify: `lib/modules/anime/anime_detail_page.dart`
- Test: `test/modules/anime/anime_detail_page_test.dart`

**Interfaces:**
- Consumes: `RatingStars` (Task 1); `Work.extra['score']` is a 0–10 `double?` (Task 2); `metadataServiceProvider`.
- Produces: detail page renders summary + `RatingStars` + basic-info chips; no duplicate meta card.

- [ ] **Step 1: Write the failing widget test**

Create `test/modules/anime/anime_detail_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/metadata/metadata_provider.dart';
import 'package:acgnhub/core/metadata/metadata_service.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/widgets/rating_stars.dart';
import 'package:acgnhub/modules/anime/anime_detail_page.dart';
import 'package:acgnhub/modules/anime/anime_providers.dart';

class _FailingProvider implements MetadataProvider {
  @override
  String get id => 'fail';
  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async => throw Exception('offline');
  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async => throw Exception('offline');
  @override
  Future<Work> detail(Work work) async => throw Exception('offline');
}

MetadataService _offlineService() => MetadataService(
      anilist: _FailingProvider(),
      jikan: _FailingProvider(),
      seedLoader: () async => const [],
      intervals: const {},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows summary and rating when present', (tester) async {
    const work = Work(
      id: 'anilist_1',
      sourceId: 'anilist',
      sourceName: 'AniList',
      type: WorkType.anime,
      title: 'Test Anime',
      summary: 'A short summary.',
      extra: {'anilistId': 1, 'score': 8.5},
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [metadataServiceProvider.overrideWithValue(_offlineService())],
      child: const MaterialApp(home: AnimeDetailPage(work: work)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('A short summary.'), findsOneWidget);
    expect(find.byType(RatingStars), findsOneWidget);
  });

  testWidgets('shows empty text and no stars when missing', (tester) async {
    const work = Work(
      id: 'seed_1',
      sourceId: 'seed',
      sourceName: 'Offline',
      type: WorkType.anime,
      title: 'No Info',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [metadataServiceProvider.overrideWithValue(_offlineService())],
      child: const MaterialApp(home: AnimeDetailPage(work: work)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('暂无简介'), findsOneWidget);
    expect(find.byType(RatingStars), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/anime/anime_detail_page_test.dart`
Expected: FAIL — `RatingStars` not found / `暂无简介` text mismatch (`暂无简介数据` currently).

- [ ] **Step 3: Update the detail page**

In `lib/modules/anime/anime_detail_page.dart`:

1. Add the import:
```dart
import '../../core/widgets/rating_stars.dart';
```

2. In `build`, change the score variable and pass more fields to `_infoSection`, and remove the meta sliver:
```dart
    final score = (w.extra['score'] as num?)?.toDouble();
```
and the slivers list becomes:
```dart
              slivers: [
                _infoSection(w, cs, score, episodes, seasonYear, format, status),
                if (w.tags.isNotEmpty) _tagsRow(w.tags),
                _summarySection(w.summary, cs),
                _playSection(w, cs),
              ],
```

3. Replace the `_infoSection` method with:
```dart
  Widget _infoSection(
    Work w,
    ColorScheme cs,
    double? score,
    int? episodes,
    int? seasonYear,
    String? format,
    String? status,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 110,
                height: 154,
                child: w.coverUrl != null && w.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: w.coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _coverPlaceholder(cs),
                      )
                    : _coverPlaceholder(cs),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                      ),
                    )
                  else ...[
                    if (score != null) ...[
                      RatingStars(score: score),
                      const SizedBox(height: 10),
                    ],
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (episodes != null) _metaChip(Icons.live_tv_rounded, '$episodes 话', const Color(0xFF007AFF)),
                        if (seasonYear != null) _metaChip(Icons.calendar_today_rounded, '$seasonYear', const Color(0xFF5856D6)),
                        if (status != null) _metaChip(Icons.info_outline_rounded, _statusLabel(status), Colors.teal),
                        if (format != null) _metaChip(Icons.movie_outlined, format, Colors.deepPurple),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
```

4. Change the summary empty text from `'暂无简介数据'` to `'暂无简介'`:
```dart
              Text('暂无简介', style: TextStyle(fontSize: 13.5, color: cs.onSurface.withValues(alpha: 0.35)))
```

5. Delete the entire `_metaSection` method (it is no longer referenced).

6. Replace `_statusLabel` with:
```dart
  String _statusLabel(String status) => switch (status) {
        'RELEASING' || 'Currently Airing' => '连载中',
        'FINISHED' || 'Finished Airing' => '已完结',
        'NOT_YET_RELEASED' || 'Not yet aired' => '未播出',
        'CANCELLED' => '已取消',
        'HIATUS' => '停更',
        _ => status,
      };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/anime/anime_detail_page_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/modules/anime/anime_detail_page.dart test/modules/anime/anime_detail_page_test.dart
git commit -m "feat(anime): detail page shows stars and consolidated basic info"
```

---

### Task 4: Enrich the offline seed with summaries and scores

**Files:**
- Create: `tool/enrich_seed.ps1`
- Modify: `assets/anime_seed.json`

**Interfaces:**
- Produces: every resolvable seed entry has a non-empty `summary` and `extra.score` (0–10).

- [ ] **Step 1: Write the enrichment script**

Create `tool/enrich_seed.ps1`:

```powershell
$ErrorActionPreference = "Stop"
$path = "D:\ACGNhub\assets\anime_seed.json"
$json = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$enriched = 0
foreach ($w in $json) {
  $hasSummary = $w.summary -and $w.summary.Length -gt 10
  $hasScore = $w.extra.PSObject.Properties.Name -contains 'score' -and $w.extra.score
  if ($hasSummary -and $hasScore) { continue }
  for ($attempt = 1; $attempt -le 5; $attempt++) {
    try {
      $q = [uri]::EscapeDataString($w.title)
      $r = Invoke-WebRequest -Uri "https://api.jikan.moe/v4/anime?q=$q&limit=1&sfw=true" -TimeoutSec 25 -UseBasicParsing
      $data = ($r.Content | ConvertFrom-Json).data
      if ($data -and $data.Count -gt 0) {
        if ($data[0].synopsis) { $w.summary = $data[0].synopsis }
        if ($data[0].score) { $w.extra | Add-Member -NotePropertyName score -NotePropertyValue ([double]$data[0].score) -Force }
        $enriched++
      }
      break
    } catch {
      Start-Sleep -Milliseconds (700 * $attempt)
    }
  }
  Start-Sleep -Milliseconds 400
}
[System.IO.File]::WriteAllText($path, ($json | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
$withSummary = ($json | Where-Object { $_.summary -and $_.summary.Length -gt 10 }).Count
$withScore = ($json | Where-Object { $_.extra.PSObject.Properties.Name -contains 'score' }).Count
Write-Output "enriched=$enriched total=$($json.Count) withSummary=$withSummary withScore=$withScore"
```

- [ ] **Step 2: Run the script**

Run: `powershell -ExecutionPolicy Bypass -File "D:\ACGNhub\tool\enrich_seed.ps1"`
Expected: prints `enriched=<n> total=24 withSummary=<n> withScore=<n>`. Jikan is flaky; if `withSummary` is low, re-run the script (it skips already-enriched entries).

- [ ] **Step 3: Verify the asset is valid JSON**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/metadata_service_test.dart`
Expected: PASS (the seed is only loaded by the default loader, which the tests don't exercise; this is a sanity check that nothing else broke). Then confirm the file parses:
Run: `powershell -Command "[System.IO.File]::ReadAllText('D:\ACGNhub\assets\anime_seed.json', [System.Text.Encoding]::UTF8) | ConvertFrom-Json | Measure-Object | Select-Object -ExpandProperty Count"`
Expected: `24`.

- [ ] **Step 4: Commit (only if user asked)**

```bash
git add tool/enrich_seed.ps1 assets/anime_seed.json
git commit -m "chore(seed): enrich offline anime seed with summaries and scores"
```

---

### Task 5: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 2: Run the full test suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass.

- [ ] **Step 3: Build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe`.

- [ ] **Step 4: Smoke-run (manual)**

Run: `flutter run -d windows`
Expected: opening a detail page shows the summary, the star rating, and the episodes/year/status/format chips; offline seed items show summary + stars after Task 4.

---

## Self-Review

- **Spec coverage:** `RatingStars` (§3.1) → Task 1; detail layout + consolidated info + status mapping (§3.2, §4) → Task 3; score normalization (§4) → Task 2; seed enrichment (§5) → Task 4; tests (§6) → Tasks 1–3 + Task 5. All spec sections covered.
- **Placeholders:** none.
- **Type consistency:** `RatingStars({double? score, double size})`, `_normalizeScore(dynamic) -> double?`, `Work.extra['score']` as `double?`, `_statusLabel(String) -> String`, `_infoSection(Work, ColorScheme, double?, int?, int?, String?, String?)` are consistent across tasks.
