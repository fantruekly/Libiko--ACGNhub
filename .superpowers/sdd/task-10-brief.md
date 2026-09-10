### Task 10: Create first built-in anime rule

**Files:**
- Create: `assets/rules/yhdm.json`

**Interfaces:**
- Produces: A working built-in anime source rule

- [ ] **Step 1: Write built-in rule**

Create `assets/rules/yhdm.json` (妯辫姳鐨勫姩婕?- a commonly available source):

```json
{
  "name": "妯辫姳鍔ㄦ极",
  "baseUrl": "https://www.yhdmp.cc",
  "search": {
    "url": "/s_all?ex=1&kw={keyword}&page={page}",
    "list": "//ul[@id='list_li']/li",
    "title": ".//a/@title",
    "cover": ".//img/@src",
    "link": ".//a/@href"
  },
  "detail": {
    "summary": "//div[@class='info']/text()",
    "tags": "//div[@class='sinfo']/span/text()",
    "cover": "//img[@class='pic']/@src",
    "chapters": "//ul[@id='playlist']/li[contains(@class,'episode')]",
    "chapterTitle": ".//a/text()",
    "chapterLink": ".//a/@href"
  },
  "video": {
    "playUrl": "//iframe[@id='playbox']/@src",
    "resolutions": "//select[@class='res']/option/@value"
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add assets/rules/yhdm.json
git commit -m "feat(anime): add built-in anime source rule"
```

---


