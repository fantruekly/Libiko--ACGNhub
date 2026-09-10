## Task 11 Report: Anime home page with Riverpod providers

**Status:** COMPLETED

**Commits:**
- `796da70` feat(anime): add anime home page with Riverpod providers

**Build Result:** SUCCESS (Flutter build windows --debug)

**Files Created:**
- `lib/modules/anime/anime_providers.dart` — `sourceManagerProvider` and `animeSourceListProvider` (FutureProvider loading rules from `assets/rules/` via AssetManifest.json)
- `lib/modules/anime/anime_home.dart` — `AnimeHomePage` (ConsumerWidget with source list, pull-to-refresh, search stub) and `AnimeSearchPage` (placeholder)

**Concerns:**
- `line.split('"')[1]` in the provider will throw `RangeError` if a manifest line contains fewer than 2 quote-delimited segments. The `if (key != null)` check is always true in Dart 3 (non-nullable `String`) and does not guard against index-out-of-bounds.