# Task 12 Report: 阅读器插图按视口高度显示（两侧留白）

## Status
DONE

## What I implemented
In `lib/modules/novel/novel_reader_page.dart`:

1. Changed the `NovelImage` branch of `_content` so the `CachedNetworkImage`
   (still `fit: BoxFit.contain`, `httpHeaders: novelImageHeaders`) is wrapped in
   a fixed-height `SizedBox(height: _illustrationHeight(context), width: double.infinity)`.
   The previous `ClipRRect` (rounded corners) wrapper was removed, exactly as the
   brief's verbatim snippet specifies.
2. Simplified the placeholder/error widgets to a centered
   `CircularProgressIndicator` / `broken_image_outlined` icon (no fixed 180/80
   heights), per the brief.
3. Added the `_illustrationHeight(BuildContext)` helper:
   `MediaQuery.sizeOf(context).height - 56 - 64 - 24`, clamped to `[200, 4000]`.

Net diff: 15 insertions, 9 deletions, one file.

## What I tested and results
- `flutter analyze lib test` → `No issues found! (ran in 2.1s)`
- `flutter test` → `All tests passed!` (211 passed, 1 pre-existing skip:
  `js_engine_smoke_test` native library not loadable under `flutter test`; this
  is unrelated to this task and was already skipped before the change).
- Reviewed the final diff against the brief's verbatim code: exact match.

## Files changed
- `lib/modules/novel/novel_reader_page.dart`

## Commit / push
- `3d79ee1` fix(novel): size reader illustrations to the viewport height
- Pushed to `origin/dev` (`64df555..3d79ee1`).

## Self-review findings
- Snippet and helper match the brief byte-for-byte (aside from indentation
  context); no other call sites reference `_illustrationHeight`.
- No new dependency added; `environment.sdk >=3.6.0` untouched.
- No `TextStyle` sets `fontFamily`.
- `ClipRRect` removal is intentional per the brief (illustration is now a plain
  rectangular comic-style page).

## Concerns
- The scroll content still has top padding 72 and bottom padding 96, while the
  illustration is `screenHeight - 144`. So one illustration plus its padding is
  `screenHeight + 24` tall, i.e. roughly 24px of scroll remains. This is exactly
  what the brief specifies (56 + 64 + 24 = 144), so I did not deviate. If a
  perfectly non-scrolling single illustration is later desired, the 24px margin
  or the content padding would need reconciling — flagging for the user, not
  changing now.
