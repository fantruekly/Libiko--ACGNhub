# UI Polish — Design

> Date: 2026-09-10
> Status: Approved (design)
> Scope: Window chrome, detail-page cleanup, and translucent/premium surfaces.

## 1. Goal

Unify the app's visual style: replace the native Windows title bar with an app-styled frameless one, remove the detail page's bottom CTA bar, and give surfaces/buttons a more premium, translucent look.

## 2. Frameless title bar

- Add `window_manager`.
- In `main()`, after `MediaKit.ensureInitialized()`:
  - `await windowManager.ensureInitialized();`
  - `windowManager.waitUntilReadyToShow(WindowOptions(size: Size(1280, 800), minimumSize: Size(960, 640), center: true, title: 'ACGNhub', titleBarStyle: TitleBarStyle.hidden), () async { await windowManager.show(); await windowManager.focus(); });`
- `MainShell`'s existing 48px top bar becomes the title bar:
  - The whole bar is wrapped in `window_manager`'s `DragToMoveArea` so it drags the window; interactive children (toggle, search, avatar, window controls) capture their own gestures.
  - Right side order: search (anime only), avatar, then **window controls**: minimize, maximize/restore (icon reflects `isMaximized`), close.
  - Controls are 46×48 hit targets with a 36×36 rounded icon area; muted icons (`#1C1C1E` at 55%); hover background `#000` at 5%; the close button's hover background is `#E81123` with a white icon.
- The maximize/restore button updates its icon via a `WindowListener` (`onWindowMaximize`/`onWindowUnmaximize`).

## 3. Detail page cleanup

- Remove `_bottomBar` from `lib/modules/anime/anime_detail_page.dart` (the `Column` no longer has a bottom bar; the `CustomScrollView` fills the body).
- Delete the `_bottomBar` method and the now-unused `url_launcher` import if it becomes unused.

## 4. Translucent / premium surfaces

- **Top bar**: translucent white (`Color(0xF2FFFFFF)`) over a light `BackdropFilter` blur (sigma 18), with a 0.5px `#E5E5EA` bottom border.
- **Cards** (detail info, play section, meta): translucent white (`Color(0xF7FFFFFF)`) + `BackdropFilter` blur (sigma 14) + hairline border + soft shadow (`#000` at 6%, blur 16, offset (0,6)).
- **Buttons**:
  - Filled: accent → a subtle lighter accent gradient, soft shadow, 12px radius.
  - Outlined: translucent accent fill (`accent` at 6%) + accent border at 35%.
  - Episode buttons: translucent accent fill (`accent` at 6%) + accent border at 25%, 10px radius, hover lift (fill 12%).
  - Source chips: translucent fill, rounded.
- A small shared helper `GlassSurface` (`lib/core/widgets/glass_surface.dart`) wraps a child in a blurred translucent rounded container, used by the top bar and cards.

Note: `BackdropFilter` blurs what is painted behind it; on Windows it works over the app's own background. Keep blurs modest to avoid perf issues.

## 5. Dependencies

- `window_manager: ^0.4.3` (or latest 0.4.x).

## 6. Files

**New**
- `lib/core/widgets/glass_surface.dart`

**Modified**
- `lib/main.dart` (window_manager init + frameless window)
- `lib/shell/main_shell.dart` (title bar + window controls + glass top bar)
- `lib/modules/anime/anime_detail_page.dart` (remove bottom bar; glass cards; button styling)
- `pubspec.yaml`

## 7. Testing

- `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.
- Manual: the window can be dragged from the top bar; minimize / maximize-restore / close work; the detail page has no bottom bar; surfaces look translucent.

## 8. Out of scope

- Dark theme.
- Animations beyond hover transitions.
- Comic/novel/game module pages.
