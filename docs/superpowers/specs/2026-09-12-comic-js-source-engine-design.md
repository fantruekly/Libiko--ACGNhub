# Comic JS Source Engine — Design (Sub-project C1)

> Date: 2026-09-12
> Status: Approved (design)
> Scope: the JS comic-source engine only. The comic UI, detail page, reader and favorites/history are C2.

## 1. Goal

Load, manage and execute **Venera-style `.js` comic sources** and expose them to Dart as search / explore / detail / chapter-images. C2's UI consumes that API.

## 2. Background

- `WorkType { anime, comic, novel, game }` already exists; the comic module is otherwise a sidebar placeholder with no code.
- Venera (`venera-app/venera`, Flutter, now archived) defines comic sources as a JS class `class X extends ComicSource` in a `.js` file, executed with `flutter_qjs` (QuickJS); the JS side talks to Dart through a global `sendMessage({method, ...})` that Dart dispatches to HTTP / HTML / crypto / cookies handlers. Sources live in a user directory and are imported from a URL, a local file, or a remote list (`venera-configs/index.json`).
- **Risk resolved:** upstream `flutter_qjs` 0.3.7 cannot be used — it depends on `ffi ^1.0.0` while this project's `path_provider` requires `ffi ^2.0.0`, so dependency resolution fails. The engine is therefore **Venera's fork** (`venera-app/flutter_qjs`, `master`), which uses `ffi ^2.0.0` and declares Windows support; it is added as a git dependency. **Task 1 is still a spike** to prove it builds and evaluates JS on Windows; if it fails, STOP and report.
- The app already depends on `dio` and `html`. `crypto` and `pointycastle` will be added for `Convert`.
- The anime module's layering (`lib/core/...` for data/engine, `lib/modules/anime/` for UI) is the pattern to mirror; comic code goes in `lib/core/comic/` (engine) and later `lib/modules/comic/` (UI).

## 3. Architecture

New package folder `lib/core/comic/`:

| File | Responsibility |
|---|---|
| `js_engine.dart` | `JsEngine` — owns a `FlutterQjs`, injects the global `sendMessage`, dispatches `http` / `convert` / `html` / `setting` / `log` |
| `html_bridge.dart` | Dart-side DOM store: `html` package documents/elements behind integer handles + LRU |
| `models.dart` | `Comic`, `ComicDetails`, `ComicEp`, `ImageLoadingConfig` |
| `comic_source.dart` | `ComicSource` model + `ComicSourceManager` (scan / parse / import / update) |

Bundled JS API library: `assets/comic_source/init.js` (declared as an asset).

New dependencies in `pubspec.yaml`: `flutter_qjs`, `crypto`, `pointycastle`, `fast_gbk`.

## 4. JS API library (`assets/comic_source/init.js`)

Re-implemented to match Venera's **API shape** (function names, arguments, return shapes) — not copied from Venera's GPL file.

**Global**: `sendMessage(obj) → dynamic` (the single Dart bridge entry point), `console.log`.

**`class ComicSource`** (the base every source extends) with the fields Venera requires:
`name` (String, required), `key` (String, `[A-Za-z0-9_]+`, required), `version` (String, required), `url` (String, optional update URL); plus optional capability objects. C1 supports exactly these capabilities:
- `init()` — optional.
- `search = { load(keyword, options, page) → {comics, maxPage} | {comics, next} }`.
- `explore = [{ title, load(page) → {comics, maxPage} | {comics, next} }]`.
- `comic = { loadInfo(id) → ComicDetails, loadEp(comicId, epId) → {images: [String]}, onImageLoad(url, comicId, epId) → ImageLoadingConfig }`.
- `settings = { key: { title, type: 'select'|'switch'|'input', ... } }` + `this.loadSetting(key)` / `this.saveSetting(key, value)`.

**`Network`**: `sendRequest(method, url, headers, data, extra) → {status, headers, body}`; sugar `get/post/put/delete`; `fetchBytes(...) → ArrayBuffer`; `setCookies/getCookies` (best-effort; C1 only forwards them to Dart's cookie jar, no WebView login).

**`Convert`**: `utf8`, `utf8Encode`, `gbk` (decode), `base64Encode/Decode`, `hexEncode/Decode`, `md5`, `sha1`, `sha256`, `hmac`. (`aesEcb`/`aesCbc` are **deferred out of C1** — a source needing AES will fail loudly; add them later if a real source requires it.)

**`HtmlDocument` / `HtmlNode`**: `new HtmlDocument(html)`; `querySelector(selector)`, `querySelectorAll(selector)`, `getElementById(id)`, and the accessors `text`, `innerHtml`, `outerHtml`, `attributes`, `attr(name)`, `html`. Every node holds an integer `handle`; all operations call `sendMessage({method: 'html', ...})`.

**`Comic`** / **`ComicDetails`**: plain JS constructors producing the shapes in §6.

## 5. Dart bridge (`sendMessage` dispatch)

Dart installs a global JS function `sendMessage` and dispatches on `method`:

| method | args | returns |
|---|---|---|
| `http` | `{method, url, headers, data, bytes}` | `{status, headers, body}` (`body` is a String, or a `Uint8List` when `bytes` is true) |
| `convert` | `{type, data, key, iv, ...}` | the converted value |
| `html` | `{op, handle, selector, id, ...}` | a handle (int) or a value; ops: `parse`, `querySelector`, `querySelectorAll`, `getElementById`, `text`, `innerHtml`, `outerHtml`, `attributes`, `attr`, `free` |
| `setting` | `{op: 'get'\|'set', key, value}` | the stored value |
| `log` | `{message}` | null |

- `http` uses a dedicated `Dio` (15 s timeouts, `validateStatus: (_) => true`) and injects a default browser `User-Agent` when the JS did not set one. A `DioException` returns `{status: 0, error: '...'}` and the JS `Network` layer throws.
- `html` stores parsed `html.Document`/`html.Element` objects in an LRU keyed by an incrementing int handle (capacity 64); `free` removes one. `querySelectorAll` returns a `List<int>` of handles.
- `convert` implements the §4 list; `gbk` decoding uses the `fast_gbk` package (add it alongside `crypto`/`pointycastle`). If `fast_gbk` cannot be added, drop `gbk` from `Convert` and note it in the spec's out-of-scope rather than shipping a stub.
- `setting` reads/writes the source's `<key>.data` JSON via `AppDatabase`.

## 6. Dart models

```dart
class Comic {
  final String id; final String title; final String? subtitle;
  final String? cover; final List<String> tags; final String? description;
}
class ComicDetails {
  final String id; final String title; final String? subtitle; final String? cover;
  final List<String> tags; final String? description;
  final Map<String, String> chapters;      // chapterId -> title (first road/group only)
  final List<String> recommendIds;
}
class ComicEp { final List<String> images; }
class ImageLoadingConfig {
  final String? url; final String? method; final dynamic data;
  final Map<String, String>? headers;
}
```

## 7. `ComicSource` model + `ComicSourceManager`

`ComicSource` (Dart): `name`, `key`, `version`, `url`, `fileName`, `description`, plus the JS-side capability flags (`canSearch`, `canExplore`, `canLoadInfo`, `canLoadEp`, `canOnImageLoad`).

`ComicSourceManager`:
- `Future<void> load()` — scan `<app support dir>/comic_source/*.js`, parse each in the engine, keep the ones whose `name`/`key`/`version` are present and whose `minAppVersion` (if any) is satisfied.
- `Future<List<ComicSource>> sources()`.
- `Future<ComicSource> importFromUrl(String url)` — download the `.js`, save under the source dir, parse.
- `Future<ComicSource> importFromFile(String path)` — read a local `.js`, save, parse.
- `Future<ComicSource> refresh(ComicSource source)` — re-download from `source.url` when the version changed.
- `Future<void> remove(ComicSource source)` — delete the `.js` and its `.data`.
- `Future<List<Comic>> search(ComicSource s, String keyword, {int page})`, `explore(ComicSource s, int index, int page)`, `loadInfo(ComicSource s, String id)`, `loadEp(ComicSource s, String comicId, String epId)`, `onImageLoad(ComicSource s, String url, String comicId, String epId)` — each evaluates the source's JS with the right arguments and maps the result into the §6 models.

Parsing: read the file text, require a `class <Name> extends ComicSource` declaration, evaluate the whole file in the engine, then read the class's fields. A source that throws during parse is skipped and logged.

**Remote list** (optional): a settings value `comic_source_list_url`; when set, the manager can fetch the JSON list (`[{name, key, url|fileName, version, description}]`) and import selected entries. C1 only provides the fetch + parse; the UI is C2.

## 8. Error Handling

- A source that fails to parse/evaluate is skipped with a `debugPrint`, never crashing the manager.
- A JS exception during `search`/`loadInfo`/`loadEp` is caught, logged, and surfaced as an empty result / `null` to the caller.
- `http` failures return an error object; the JS `Network` layer throws a JS error the source may catch.
- Engine reference leaks: `JsEngine.dispose()` closes the QuickJS runtime; long-lived handles are freed by the LRU.
- The manager must not run two engine evaluations concurrently on one engine (a single-threaded queue).

## 9. Testing

- `test/core/comic/html_bridge_test.dart`: parse HTML, `querySelector`/`querySelectorAll`/`text`/`attr`/`innerHtml`, nested queries, handle LRU eviction.
- `test/core/comic/js_engine_test.dart`: `evaluate('1+1')`; a fake `Dio` adapter drives `http` (status/headers/body + a `bytes` request); `convert` for base64/hex/md5/sha256; a JS snippet that calls `sendMessage` for each.
- `test/core/comic/comic_source_test.dart`: an inline test source string is parsed into a `ComicSource` with the right name/key/version/capability flags; a malformed source is skipped.
- `test/core/comic/comic_source_e2e_test.dart`: with a bundled test source that fetches a local HTML fixture through the `http` bridge, run `search` → `loadInfo` → `loadEp` and assert the mapped models.
- **Spike (Task 1)**: add `flutter_qjs`, build a minimal `JsEngine`, assert `evaluate('1+1') == 2`, then `flutter build windows --debug`. If the build fails, stop and report.
- Re-run `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 10. Files

**New**
- `lib/core/comic/js_engine.dart`
- `lib/core/comic/html_bridge.dart`
- `lib/core/comic/models.dart`
- `lib/core/comic/comic_source.dart`
- `assets/comic_source/init.js`
- `assets/comic_source/test_source.js` (fixture for tests)
- `test/core/comic/html_bridge_test.dart`
- `test/core/comic/js_engine_test.dart`
- `test/core/comic/comic_source_test.dart`
- `test/core/comic/comic_source_e2e_test.dart`

**Modified**
- `pubspec.yaml` (`flutter_qjs`, `crypto`, `pointycastle`, `fast_gbk`; declare `assets/comic_source/`)

## 11. Out of Scope

- The comic UI: home/explore, search page, detail page, reader, favorites/history (C2).
- `account` (WebView login), network `favorites`, `category`, `translation`, a source-settings UI.
- Cookies beyond best-effort forwarding; no WebView-based login in C1.
- Image caching/preloading (C2's reader owns that; C1 only returns `ImageLoadingConfig`).
- Any server component.
