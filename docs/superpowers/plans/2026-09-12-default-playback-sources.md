# Default Playback Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make rule sources evaluate row-scoped XPaths the way Kazumi intends, and bundle 5 calibrated default rule sources.

**Architecture:** The extraction scripts already run in the page and use `document.evaluate`. This plan adds a `__rel` helper that rewrites a row/road-scoped selector's leading `//` to `.//` (the upstream rules' intended semantics), then adds 4 more rule JSONs to `assets/source_rules/` and calibrates all 5 against their live sites.

**Tech Stack:** Flutter 3.35, Dart 3, `webview_windows` (Predidit fork), headless Chrome for calibration.

## Global Constraints

- Windows only; package name `acgnhub`.
- Bundled rules live in `assets/source_rules/` (declared in `pubspec.yaml`); the legacy `assets/rules/` is untouched.
- `searchList` and `chapterRoads` are evaluated against `document` (global). `searchName`, `searchResult` and `chapterResult` are row/road-scoped and must go through `__rel`.
- `__rel(x)` returns `'.' + x` when `x` starts with `//`, otherwise `x` unchanged.
- Exactly **5** bundled rule files at the end: `7sefun.json`, `akianime.json`, `gugu3.json`, `ezdmw.json`, `MXdm.json`.
- Search concurrency stays at 3; `StreamResolver` and the player are unchanged.
- Commit after every task.
- Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed.
- Headless Chrome is at `C:\Program Files\Google\Chrome\Application\chrome.exe`.

---

### Task 1: Row-relative XPath normalization (`__rel`)

**Files:**
- Modify: `lib/core/video/webview_scraper.dart`
- Modify: `test/core/video/xpath_js_test.dart`

**Interfaces:**
- Consumes: `SourceRule` (existing).
- Produces: `buildSearchScript` / `buildEpisodesScript` now wrap the row/road-scoped selectors with `__rel(...)`. Signatures unchanged.

- [ ] **Step 1: Update the failing tests**

In `test/core/video/xpath_js_test.dart`, replace the first two tests (the `buildSearchScript` / `buildEpisodesScript` tests) with:

```dart
  test('buildSearchScript wraps row sub-selectors with __rel', () {
    final js = buildSearchScript(_rule);
    expect(js, contains('document.evaluate'));
    expect(js, contains('function __rel('));
    expect(js, contains('__ev("//div[2]/div[2]/div[2]/div[2]/div", document)'));
    expect(js, contains('__txt(__rel("//div[2]/text()"), list[i])'));
    expect(js, contains('__attr(__rel("//a"), list[i], \'href\')'));
    expect(js, contains('return rows;'));
    expect(js, isNot(contains('JSON.stringify')));
  });

  test('buildEpisodesScript wraps the chapter result with __rel', () {
    final js = buildEpisodesScript(_rule);
    expect(js, contains(
        '__ev("//div[2]/div[2]/div[2]/div/div[2]/div[1]//div", document)'));
    expect(js, contains('__ev(__rel("//a"), roads[0])'));
    expect(js, contains('return out;'));
    expect(js, isNot(contains('JSON.stringify')));
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/xpath_js_test.dart`
Expected: FAIL — the generated scripts do not yet contain `__rel(`.

- [ ] **Step 3: Add the `__rel` helper**

In `lib/core/video/webview_scraper.dart`, add to `_helpersJs` (after `__attr`):

```js
function __rel(xpath) {
  return xpath.indexOf('//') === 0 ? '.' + xpath : xpath;
}
```

- [ ] **Step 4: Wrap the row/road-scoped selectors**

In `buildSearchScript`, change the two row-scoped calls:

```dart
      name: __txt(__rel(${jsonEncode(rule.searchName)}), list[i]),
      href: __attr(__rel(${jsonEncode(rule.searchResult)}), list[i], 'href')
```

In `buildEpisodesScript`, change the road-scoped call:

```dart
    var links = __ev(__rel(${jsonEncode(rule.chapterResult)}), roads[0]);
```

Leave `__ev(${jsonEncode(rule.searchList)}, document)` and `__ev(${jsonEncode(rule.chapterRoads)}, document)` unchanged.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/xpath_js_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Analyze and run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/core/video/webview_scraper.dart test/core/video/xpath_js_test.dart
git commit -m "fix(video): evaluate rule row sub-selectors relative to their row"
```

---

### Task 2: Bundle 4 more default rules

**Files:**
- Create: `assets/source_rules/akianime.json`
- Create: `assets/source_rules/gugu3.json`
- Create: `assets/source_rules/ezdmw.json`
- Create: `assets/source_rules/MXdm.json`
- Modify: `test/core/video/rule_store_test.dart`

**Interfaces:**
- Consumes: `SourceRule` (existing); `RuleStore` (existing).
- Produces: 5 bundled rule files (Task 3 calibrates them).

- [ ] **Step 1: Update the failing test**

In `test/core/video/rule_store_test.dart`, replace the `bundled 7sefun rule parses from disk` test with:

```dart
  test('every bundled rule parses from disk', () async {
    final dir = Directory('assets/source_rules');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(5));
    for (final file in files) {
      final rule = SourceRule.fromJsonString(await file.readAsString());
      expect(rule.name, isNotEmpty, reason: file.path);
      expect(rule.searchUrl, contains('@keyword'), reason: file.path);
    }
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_store_test.dart`
Expected: FAIL — expected 5 files, found 1.

- [ ] **Step 3: Create `assets/source_rules/akianime.json`**

```json
{
    "api": "4",
    "type": "anime",
    "name": "akianime",
    "version": "1.4",
    "muliSources": true,
    "useWebview": true,
    "useNativePlayer": true,
    "useLegacyParser": false,
    "userAgent": "",
    "baseURL": "https://www.akianime.cc/",
    "searchURL": "https://www.akianime.cc/bgmsearch/-------------.html?wd=@keyword",
    "searchList": "//div[@class='vod-detail style-detail cor4 search-list']",
    "searchName": "//div/div[2]/a/h3",
    "searchResult": "//div/div[2]/div/div[1]/a",
    "chapterRoads": "//ul[@class='anthology-list-play size']",
    "chapterResult": "//li/a"
}
```

- [ ] **Step 4: Create `assets/source_rules/gugu3.json`**

```json
{
    "api": "5",
    "type": "anime",
    "name": "gugu3",
    "version": "1.3",
    "muliSources": true,
    "useWebview": true,
    "useNativePlayer": true,
    "useLegacyParser": false,
    "userAgent": "",
    "adBlocker": true,
    "baseURL": "https://www.gugu3.com/",
    "searchURL": "https://www.gugu3.com/index.php/vod/search.html?wd=@keyword",
    "searchList": "//div[@class='public-list-box search-box flex rel']",
    "searchName": "//div[3]/div[1]/div[1]",
    "searchResult": "//div[3]/div[2]/a[1]",
    "chapterRoads": "//ul[@class='anthology-list-play size']",
    "chapterResult": "//li/a"
}
```

- [ ] **Step 5: Create `assets/source_rules/ezdmw.json`**

```json
{
    "api": "8",
    "type": "anime",
    "name": "ezdmw",
    "version": "1.2",
    "muliSources": true,
    "useWebview": true,
    "useNativePlayer": true,
    "usePost": false,
    "useLegacyParser": false,
    "adBlocker": false,
    "userAgent": "",
    "baseURL": "https://m.ezdmw.org/",
    "searchURL": "https://m.ezdmw.org/Index/search.html?searchText=@keyword",
    "searchList": "//section[@id='some_drama']/div",
    "searchName": "//p",
    "searchResult": "//a",
    "chapterRoads": "//section[@class='anthology'][1]/div[contains(@class,'line_button')]",
    "chapterResult": "/self::*[@class='line_button_ban']/following-sibling::a[@class='circuit_switch_ban'] | /self::*[@class='line_button1']/following-sibling::a[@class='circuit_switch1'] | /self::*[@class='line_button3']/following-sibling::a[@class='circuit_switch3'] | /self::*[@class='line_button2']/following-sibling::a[@class='circuit_switch2']",
    "referer": "https://m.ezdmw.org/"
}
```

- [ ] **Step 6: Create `assets/source_rules/MXdm.json`**

```json
{
    "api": "5",
    "type": "anime",
    "name": "MXdm",
    "version": "2.3",
    "muliSources": true,
    "useWebview": true,
    "useNativePlayer": true,
    "adBlocker": true,
    "userAgent": "",
    "baseURL": "https://www.dcc3.com/",
    "searchURL": "https://www.dcc3.com/search/?wd=@keyword",
    "searchList": "//div[3]/ul/li",
    "searchName": "//h3/a",
    "searchResult": "//h3/a",
    "chapterRoads": "//div[4]/div/div/ul",
    "chapterResult": "//li/a"
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_store_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 8: Analyze and run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add assets/source_rules test/core/video/rule_store_test.dart
git commit -m "feat(video): bundle four more Kazumi rule sources"
```

---

### Task 3: Calibrate every bundled rule + final verification

**Files:**
- Modify: `assets/source_rules/*.json` (XPath corrections only, as calibration requires)
- Create: `.superpowers/sdd/probe-rule.ps1` (calibration helper)

**Interfaces:**
- Consumes: the 5 bundled rules, `__rel` semantics from Task 1.
- Produces: 5 rules that actually return results on their live sites.

- [ ] **Step 1: Create the calibration helper**

Create `.superpowers/sdd/probe-rule.ps1`:

```powershell
param(
  [Parameter(Mandatory=$true)][string]$Rule,
  [Parameter(Mandatory=$true)][string]$Keyword,
  [ValidateSet('search','detail')][string]$Mode = 'search',
  [string]$DetailUrl = ''
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
$dir = "C:\Users\26568\AppData\Local\Temp\opencode\probe"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$j = [System.IO.File]::ReadAllText($Rule, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
if ($Mode -eq 'search') {
  $url = $j.searchURL -replace '@keyword', [System.Uri]::EscapeDataString($Keyword)
  $listX = $j.searchList; $nameX = $j.searchName; $resX = $j.searchResult
} else {
  $url = $DetailUrl
  $listX = $j.chapterRoads; $nameX = $j.chapterResult; $resX = $j.chapterResult
}
$page = Join-Path $dir "page.html"
curl.exe -k -s --ssl-no-revoke --max-time 25 -A $ua -L $url -o $page 2>$null
$body = [System.IO.File]::ReadAllText($page, [System.Text.Encoding]::UTF8)
$sl = $listX | ConvertTo-Json -Compress
$sn = $nameX | ConvertTo-Json -Compress
$sr = $resX | ConvertTo-Json -Compress
$js = @"
(function(){
  function ev(x,c){try{var r=document.evaluate(x,c||document,null,XPathResult.ORDERED_NODE_SNAPSHOT_TYPE,null);var o=[];for(var i=0;i<r.snapshotLength;i++)o.push(r.snapshotItem(i));return o;}catch(e){return [];}}
  function rel(x){return x.indexOf('//')===0?('.'+x):x;}
  function txt(x,c){var n=ev(x,c);if(!n.length)return '';return (n[0].textContent||'').trim();}
  function attr(x,c,a){var n=ev(x,c);if(!n.length)return '';var e=n[0];return ((e.getAttribute&&e.getAttribute(a))||'').trim();}
  var list=ev($sl,document);var rows=[];
  for(var i=0;i<Math.min(list.length,5);i++){rows.push({t:txt(rel($sn),list[i]),h:attr(rel($sr),list[i],'href')});}
  var pre=document.createElement('pre');pre.id='__probe';
  pre.textContent=JSON.stringify({url:location.href,count:list.length,rows:rows});
  document.body.innerHTML='';document.body.appendChild(pre);
})();
"@
$probe = Join-Path $dir "probe.html"
[System.IO.File]::WriteAllText($probe, ($body -replace '(?i)</body>', "<script>$js</script></body>"), (New-Object System.Text.UTF8Encoding($false)))
& $chrome --headless=new --disable-gpu --no-sandbox --no-first-run --virtual-time-budget=9000 --dump-dom $probe 2>$null | Out-File -LiteralPath (Join-Path $dir "out.html") -Encoding utf8
$o = Get-Content -LiteralPath (Join-Path $dir "out.html") -Raw -Encoding UTF8
$m = [regex]::Match($o, '(?s)<pre id="__probe">(.*?)</pre>')
if ($m.Success) { Write-Output $m.Groups[1].Value } else { Write-Output "NO PROBE OUTPUT (page len=$($body.Length))" }
```

- [ ] **Step 2: Probe each rule's search page**

Run for each of the 5 files (one at a time; each Chrome run is slow):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .superpowers/sdd/probe-rule.ps1 -Rule assets/source_rules/7sefun.json -Keyword 进击的巨人 -Mode search
powershell -NoProfile -ExecutionPolicy Bypass -File .superpowers/sdd/probe-rule.ps1 -Rule assets/source_rules/akianime.json -Keyword 进击的巨人 -Mode search
powershell -NoProfile -ExecutionPolicy Bypass -File .superpowers/sdd/probe-rule.ps1 -Rule assets/source_rules/gugu3.json -Keyword 进击的巨人 -Mode search
powershell -NoProfile -ExecutionPolicy Bypass -File .superpowers/sdd/probe-rule.ps1 -Rule assets/source_rules/ezdmw.json -Keyword 进击的巨人 -Mode search
powershell -NoProfile -ExecutionPolicy Bypass -File .superpowers/sdd/probe-rule.ps1 -Rule assets/source_rules/MXdm.json -Keyword 进击的巨人 -Mode search
```

Expected per rule: `count` > 0 and 5 **distinct** titles with non-empty `h` (detail hrefs). `akianime` and `gugu3` were already verified this way.

- [ ] **Step 3: Probe a detail page for each working rule**

Take a detail href from Step 2 (resolve it against `baseURL`) and run `-Mode detail -DetailUrl <absolute url>`. Expected: a non-empty list of episode titles + play hrefs.

- [ ] **Step 4: Fix or swap any rule that fails**

For a rule whose XPaths no longer match, inspect the live DOM with:

```powershell
& "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu --no-sandbox --virtual-time-budget=9000 --dump-dom "<url>" > dom.html
```

Correct that rule's XPaths and re-probe. If a source cannot be made to work, replace it with `baimao` (`https://www.baimaodm.com/`) or `moonci` (`https://www.moonci.com/`) — fetch the upstream rule from `https://raw.githubusercontent.com/Predidit/KazumiRules/main/<name>.json`, save it under `assets/source_rules/`, probe, and keep the file count at 5.

- [ ] **Step 5: Re-run the bundled-rule test**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_store_test.dart`
Expected: PASS (still exactly 5 files, all parsing).

- [ ] **Step 6: Final verification**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all tests pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → `Built build\windows\x64\runner\Debug\acgnhub.exe`.

- [ ] **Step 7: Commit any calibration changes**

```bash
git add assets/source_rules
git commit -m "fix(video): calibrate bundled rules against their live sites"
```

- [ ] **Step 8: In-app smoke test (manual, by the human)**

Launch the app, open a detail page, wait for `搜索中 n/m` to finish, and confirm results appear from the new sources and that an episode plays. Record the outcome.

---

## Self-Review

- **Spec coverage:** §3 row-relative fix → Task 1; §4 bundled sources → Task 2; §5 calibration → Task 3; §6 testing → Tasks 1–3; §7 files → Tasks 1–2. All spec sections covered.
- **Placeholders:** none — every step has concrete code, JSON, or an exact command.
- **Type consistency:** `buildSearchScript(SourceRule)` / `buildEpisodesScript(SourceRule)` signatures unchanged; `__rel` is a JS helper inside `_helpersJs`; `SourceRule.fromJsonString` and `RuleStore.mergeRules` unchanged.
