# Default Playback Sources — Design

> Date: 2026-09-12
> Status: Approved (design)
> Scope: Bundling more default rule sources + a row-relative XPath fix. Account sync, home-page rework and watch history are separate specs.

## 1. Goal

1. Fix rule evaluation so **upstream Kazumi rules work as intended** (row-scoped XPath).
2. Bundle **5 calibrated default sources** from `Predidit/KazumiRules`, each verified against its live site (search → episodes → playback).

## 2. Background / Findings

- `Predidit/KazumiRules` (`index.json`) is the official Kazumi rules repository: 16 curated rules. 13 sites are reachable from this machine; `dalvdm` (403), `DM84` (522) and `xfdmneo` (unreachable) are dead; `aafun` and `moonci` point at the same site.
- **Upstream rules use `//`-prefixed row sub-selectors** (e.g. `searchName: "//div/div[2]/a/h3"`), meaning "relative to this result row". But `document.evaluate(xpath, row, ...)` treats a leading `//` as **document-root**, so every row resolves to the same first match. Measured on `akianime`: 10 rows all returned the identical title/href.
- Rewriting a row sub-selector's leading `//` to `.//` yields correct, distinct results: verified on `akianime` (10 rows, distinct titles + `/bgmplay/...` hrefs) and `gugu3` (10 rows, distinct titles + `/index.php/vod/detail/id/...` hrefs).
- Some upstream rules are also **stale** (positional paths that no longer match the site DOM), e.g. `7sefun`'s original `//div[2]/div[2]/div[2]/div[2]/div` matched 16 nodes with empty names. Those need per-site recalibration.
- Playback pages are JS-driven on these sites, so the existing `StreamResolver` headless-WebView path applies (same as `agedm`/`gimy`).

## 3. Row-relative XPath fix

`lib/core/video/webview_scraper.dart` generates the extraction JS. Add a helper to the generated script:

```js
function __rel(x) { return x.indexOf('//') === 0 ? '.' + x : x; }
```

Apply it to the **row/road-scoped** selectors only:

- `buildSearchScript`: `searchName` and `searchResult` are evaluated against each result row → wrap with `__rel(...)`.
- `buildEpisodesScript`: `chapterResult` is evaluated against a road node → wrap with `__rel(...)`.

`searchList` and `chapterRoads` stay global (evaluated against `document`).

`__rel` leaves an already-relative selector (`.//a`) unchanged and leaves a non-`//` selector unchanged, so existing calibrated rules (e.g. the bundled `7sefun`) keep working.

## 4. Bundled sources

`assets/source_rules/` gains 4 rules alongside the existing `7sefun.json`:

| File | Rule name | baseURL | Status |
|---|---|---|---|
| `7sefun.json` | 七色番 | `https://www.7sefun.top/` | already bundled + calibrated |
| `akianime.json` | akianime | `https://www.akianime.cc/` | row-relative fix verified |
| `gugu3.json` | gugu3 | `https://www.gugu3.com/` | row-relative fix verified |
| `ezdmw.json` | ezdmw | `https://m.ezdmw.org/` | to calibrate |
| `MXdm.json` | MXdm | `https://www.dcc3.com/` | to calibrate |

Rules are taken from `https://raw.githubusercontent.com/Predidit/KazumiRules/main/<name>.json` and kept as-is unless calibration shows the site DOM has changed, in which case the XPaths are corrected against the live DOM. If a candidate cannot be calibrated it is replaced by `baimao` (`https://www.baimaodm.com/`) or `moonci` (`https://www.moonci.com/`).

The final bundled set must be exactly 5 rule sources; the source count is a design constraint because every source is searched on each detail-page open.

## 5. Calibration procedure (per source)

1. Fetch the search URL (`searchURL` with `@keyword` replaced by `进击的巨人`) and evaluate the rule's XPaths with headless Chrome; require non-empty, **distinct** titles and detail hrefs.
2. Fetch a detail page from step 1 and evaluate `chapterRoads`/`chapterResult`; require non-empty episode titles and `/…play…` hrefs.
3. Fetch one episode's play page and confirm the stream is resolved by JS (no static `.m3u8`/`.mp4`), i.e. the existing `StreamResolver` path applies.
4. On any failure: correct the rule's XPaths against the live DOM, or drop the source.

## 6. Testing

- `test/core/video/xpath_js_test.dart`: `buildSearchScript` wraps `searchName`/`searchResult` with `__rel(` and does **not** wrap `searchList`; `buildEpisodesScript` wraps `chapterResult` and not `chapterRoads`.
- `test/core/video/rule_store_test.dart`: replace the single-file bundled-rule test with one that reads every `assets/source_rules/*.json` from disk and asserts each parses via `SourceRule.fromJsonString` (and that the directory has 5 files).
- The WebView path and playback remain manual/integration-tested.
- Re-run `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 7. Files

**New**

- `assets/source_rules/akianime.json`
- `assets/source_rules/gugu3.json`
- `assets/source_rules/ezdmw.json`
- `assets/source_rules/MXdm.json`

**Modified**

- `lib/core/video/webview_scraper.dart` (the `__rel` helper + wrapping)
- `test/core/video/xpath_js_test.dart`
- `test/core/video/rule_store_test.dart`
- `assets/source_rules/7sefun.json` (only if re-calibration changes it)

## 8. Out of Scope

- A source-management UI (enable/disable), an online rule browser, or auto-updating rules.
- Special handling for upstream rules marked `antiCrawlerEnabled` (no such rule is in the bundled 5).
- Search concurrency stays at 3; the resource section already shows `搜索中 n/m`.
- Account login/sync, home-page tab rework and watch history (separate specs).
