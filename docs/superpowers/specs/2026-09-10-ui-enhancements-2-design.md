# UI Enhancements (Tags, Episode Picker, Card Transition) — Design

> Date: 2026-09-10
> Status: Approved (design)
> Scope: Detail-page tags, in-player episode selection, and the home→detail transition.

## 1. Goal

Polish three areas: make detail-page tags larger/frosted with non-blue text; let users pick episodes from inside the player via a vertically scrollable panel; and make tapping a home card smoothly expand its cover into the detail page.

## 2. Detail-page tags

`_tagsRow` in `lib/modules/anime/anime_detail_page.dart`:
- Each tag becomes a frosted pill: white at ~45% over a light `BackdropFilter` blur (sigma 8), a 0.5px white border, radius 12, padding 10×5.
- Text: `#3A3A3C`, fontSize 12.5, `FontWeight.w500` (no blue).
- Spacing 8/8. The tags row remains a sliver under the info card.

## 3. In-player episode selection

### 3.1 Interface change
`VideoPlayerPage` changes from `({title, streamUrl})` to:
```dart
class VideoPlayerPage extends StatefulWidget {
  final String title;
  final List<VideoEpisode> episodes;
  final int initialIndex;
  const VideoPlayerPage({super.key, required this.title, required this.episodes, required this.initialIndex});
}
```
(`VideoEpisode` is `lib/core/video/video_source.dart`: `{id, title, index, playUrl}`.)

The detail page passes `_videoEpisodes!` and the tapped episode's index instead of a resolved URL. The player resolves each episode's `playUrl` via `StreamResolver` on demand.

### 3.2 Playback flow
- On `initState`, call `_playIndex(widget.initialIndex)`.
- `_playIndex(i)`: show a small loading state, `await StreamResolver().resolve(episodes[i].playUrl)`, then `_player.open(Media(url))`; on null, show a snackbar "无法解析播放地址". Track `_currentIndex`.
- Guard against concurrent resolves (a `_resolving` flag) and stale results (an index/generation check).

### 3.3 Episode button & panel
- Override `bottomButtonBar` (keeping the defaults) to insert an episode button before the fullscreen button:
  `[SkipPrevious, PlayOrPause, SkipNext, Volume, PositionIndicator, Spacer, <episode button>, Fullscreen]`, where the episode button is `MaterialDesktopCustomButton(icon: Icon(Icons.list_rounded), onPressed: _togglePanel)`.
- `_togglePanel` shows/hides a right-side panel: a `Positioned` overlay in the player `Stack`, width ~220, full height, dark translucent glass (`#CC000000` + blur), a header "选集", and a vertical `ListView` of episode buttons. The current episode is highlighted (accent). Tapping an episode calls `_playIndex(i)` and closes the panel.
- While the panel is open, keep the controls visible (the panel sits above the controls; it can be closed via the button or by tapping an episode).
- Panel styling matches the player: dark glass, white text, accent highlight, rounded 12.

### 3.4 Layout
The player body becomes a `Stack`:
1. `MaterialDesktopVideoControlsTheme(... child: Video(...))`.
2. The episode panel (when `_panelOpen`).

## 4. Home → detail transition

- `WorkCard` (`lib/core/widgets/work_card.dart`): wrap the cover image in `Hero(tag: 'work_${work.id}', child: <cover>)`.
- `AnimeDetailPage` (`lib/modules/anime/anime_detail_page.dart`): wrap the info section's cover (110×154) in `Hero(tag: 'work_${work.id}', child: <cover>)`.
- Use the default `MaterialPageRoute` transition; no custom route needed. The cover morphs from the card size to the detail size.

Note: the tag must be unique per work id and present on both routes. The detail page shows the passed `work` immediately (before enrichment), so the tag resolves on the first frame.

## 5. Files

**Modified**
- `lib/modules/anime/anime_detail_page.dart` (tags, cover Hero, pass episodes to the player)
- `lib/modules/anime/video_player_page.dart` (episodes + index, episode button/panel)
- `lib/core/widgets/work_card.dart` (cover Hero)

## 6. Testing

- `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.
- Manual: frosted larger tags with dark text; the player's episode button opens a scrollable panel and switching episodes plays them; tapping a home card smoothly expands into the detail page.

## 7. Out of scope

- Multiple play "roads" / source switching inside the player (only the selected source's episode list is shown).
- Remembering the last episode.
- Danmaku/subtitles.
