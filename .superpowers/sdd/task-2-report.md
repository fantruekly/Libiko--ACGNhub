# Task 2 Report: Account dialog in 源管理 (C2e)

**Status:** DONE

## What I implemented

Modified `lib/modules/comic/comic_source_page.dart` only.

1. **账号 menu item** (`_sourceTile`): added `if (value == 'account') _openAccount(source);`
   to `onSelected`, and `if (source.hasLogin || source.hasCookieLogin) const
   PopupMenuItem(value: 'account', child: Text('账号'))` before the 刷新 entry in
   `itemBuilder`. Sources with no account show no 账号 action.
2. **`_openAccount(ComicSource source)`** handler added next to `_refresh` /
   `_confirmDelete`; opens the dialog via `showDialog<void>`.
3. **`_AccountDialog`** (`ConsumerStatefulWidget` + `ConsumerState`) appended at
   the end of the file. It:
   - builds controllers per the account mode (2 for form login, `cookieFields.length`
     for cookie login),
   - reads current status via `comicSourceManagerProvider.isLogged`,
   - submits via `login(source, user, pass)` or `loginWithCookies(source, values)`,
   - logs out via `logout(source)`,
   - shows 已登录/未登录 status, the appropriate fields (password obscured for form
     login), and a 登录失败 error on failure.

The `PopupMenuButton`'s menu now contains 账号 (when applicable), 刷新, 删除.

### Deviation from the brief (self-review fix)

The brief's `_submit` chose the **form** path with `if (widget.source.hasLogin)`,
while `initState` and `_label` both use **cookie** priority (`hasCookieLogin`). For a
source declaring both `login` and `loginWithCookies` where `cookieFields.length < 2`,
the brief's code would size the controller list by cookie fields but then index
`_controllers[1]` in the form path — a `RangeError`. I inverted the `_submit`
condition to `if (widget.source.hasCookieLogin)` so `initState`, `_label`,
`obscureText`, and `_submit` all agree. Behavior for the real cases is unchanged:
哔咔 (form-only) → form path; ehentai (cookie-only) → cookie path. Everything else in
the brief was applied verbatim.

## Verification

| Command | Result |
| --- | --- |
| `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` | `No issues found! (ran in 1.8s)` |
| `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` | `√ Built build\windows\x64\runner\Debug\acgnhub.exe` (only the pre-existing CMake `DEPENDS` policy warning) |

## Files changed + commit

- `lib/modules/comic/comic_source_page.dart` (+145)
- Commit: `e49bae8` — `feat(comic): add the source account dialog`
- Pushed: `5f4f5f9..e49bae8  dev -> dev` (origin `https://github.com/fantruekly/ACGNhub`)

## Self-review findings

- Fixed the `hasLogin`/`hasCookieLogin` priority inconsistency described above.
- Controller list and labels are index-safe because the count, `_label`, and `_submit`
  now derive from the same `hasCookieLogin` predicate.
- `initState` calls `_refreshStatus()` without awaiting; it guards with `mounted`
  before `setState`, so no `setState after dispose` risk.
- `_logout` and `_submit` guard `mounted` after every await.
- No comments added; matches the surrounding file style.

## Concerns

- A source declaring **both** `login` and `loginWithCookies` is treated as cookie-login
  everywhere in the dialog (consistent with the brief's `initState`/`_label`). Task 1's
  `isLogged` takes the engine path when `hasLogin` is true for such a source, so the
  dialog's status read could diverge from the cookie-login DB flag in that rare hybrid
  case. No real source in scope (哔咔/ehentai) has both.
- The dialog was not covered by an automated widget test; verification is analyze +
  debug build + code inspection.

## Task 2 review fix

Addressed three review findings in `lib/modules/comic/comic_source_page.dart` only.

1. **(Important) Dialog could get stuck busy.** `_AccountDialogState._refreshStatus`,
   `_submit`, and `_logout` now wrap the manager calls in `try/catch` and always reset
   `_busy` (and set a result) even when the manager throws (e.g. engine init failure
   inside `isLogged`/`login`/`loginWithCookies`/`logout`). `_refreshStatus` swallows the
   error and leaves `_logged` false; `_submit` sets `_busy = false`, `_logged = ok`, and
   `_error = '登录失败'` on failure; `_logout` sets `_busy = false`, `_logged = false`.
   The submit branch keys on `hasCookieLogin`, matching `initState`/`_label`.
2. **(Minor) Obscure only a real password field.** The password `TextField` now uses
   `obscureText: !widget.source.hasCookieLogin && i == 1`, so cookie sources' fields
   (which are not passwords) are not obscured.
3. **(Minor) Scrollable content.** The `AlertDialog` `content` `Column` is wrapped in a
   `SingleChildScrollView` so a source with many cookie fields cannot overflow.

### Verification

| Command | Result |
| --- | --- |
| `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` | `No issues found! (ran in 1.8s)` |
| `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` | `+166 ~1: All tests passed!` (1 pre-existing skip: flutter_qjs native lib unavailable under `flutter test`) |
| `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` | `√ Built build\windows\x64\runner\Debug\acgnhub.exe` (only the pre-existing CMake `DEPENDS` policy warning) |

### Commit

- `lib/modules/comic/comic_source_page.dart` — commit `cacbc39` `fix(comic): make the account dialog robust to login failures`
- Pushed: `e49bae8..cacbc39  dev -> dev`
