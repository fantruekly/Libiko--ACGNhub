### Task 11: 探索页卡片去掉作者（统一封面高度）

> 用户反馈：探索页部分小说带作者，导致卡片高度不一致、封面大小会变。

**Files:**
- Modify: `lib/modules/novel/novel_home.dart`
- Modify: `test/modules/novel/novel_card_test.dart`（若断言了作者）

- [ ] **Step 1: 改 `NovelCard`**

删除作者那一行：

```dart
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              novel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, height: 1.45, color: _fg),
            ),
          ),
```

（即删掉 `if (novel.author != null && novel.author!.isNotEmpty) Text(novel.author!, ...)` 整段。）

- [ ] **Step 2: 适配测试**

`test/modules/novel/novel_card_test.dart`：若断言了 `find.text('入间人间')`（作者），删掉该断言，改为断言标题仍存在。

- [ ] **Step 3: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/modules/novel/novel_home.dart test/modules/novel/novel_card_test.dart
git commit -m "fix(novel): drop author from explore cards for uniform covers"
git push
```

---
