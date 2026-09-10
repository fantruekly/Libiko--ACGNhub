### Task 9 Report: XPathParser and AnimeSource Implementation

**Status:** COMPLETE

**Commit:** `b852cdd` - feat(anime): implement XPathParser and AnimeSource adapter

**Files changed:**
- `lib/modules/anime/anime_rule.dart` - Replaced XPathParser stub with full implementation:
  - `extractText()` - extracts text/attributes from HTML nodes using XPath-like selectors
  - `findNodes()` - finds all matching HTML elements by XPath selector
  - `_queryAll()` - CSS selector translation for `//tag[@attr='value']` patterns
  - `_extractAttribute()` - extracts src/href/custom attributes
  - `_findNode()` - finds first matching node
- `lib/modules/anime/anime_source.dart` (new) - AnimeSource adapter implementing SourceAdapter:
  - `buildUrl()` / `resolveUrl()` - public with `@visibleForTesting` annotation
  - `search()` - searches anime sources using XPath rules
  - `fetchDetail()` - fetches work details with summary/tags/cover/author
  - `fetchChapters()` - fetches chapter list with XPath extraction
  - `fetchContent()` - stub returning null (video player handles extraction)
- `test/modules/anime/anime_source_test.dart` (new) - 3 tests:
  - source has correct properties (type, name, baseUrl)
  - resolveUrl resolves relative/absolute/protocol-relative paths
  - buildUrl replaces {keyword} and {page} placeholders

**Tests:** All 13 tests pass (10 existing + 3 new)

**Concerns:**
- `fetchDetail()` and `fetchChapters()` currently use empty `link` string - need real workId-to-link extraction mechanism
- `fetchContent()` returns null - video stream extraction not yet implemented
- XPathParser uses CSS selector translation, not full XPath spec - may need expansion for complex rules