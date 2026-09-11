### Task 4: Regenerate the offline seed from Bangumi

**Files:**
- Create: `tool/gen_seed.dart`
- Replace: `assets/anime_seed.json`

**Interfaces:**
- Produces: `assets/anime_seed.json` — a JSON array of up to 40 `Work`-shaped objects with Chinese `title`, `summary`, `coverUrl` (https), and `extra = {bangumiId, score, episodes, airDate}`.

**Note:** the generator must be **Dart** (Dio/BoringSSL), not PowerShell — curl/.NET fail on Bangumi's TLS revocation check.

- [ ] **Step 1: Write the Dart generator**

Create `tool/gen_seed.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

Future<void> main() async {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.bgm.tv',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'ACGNhub/0.1 (https://github.com/acgnhub)',
      'Accept': 'application/json',
    },
  ));

  final res = await dio.get('/calendar');
  final days = res.data as List<dynamic>;
  final works = <Map<String, dynamic>>[];
  final seen = <int>{};

  for (final day in days) {
    for (final item in ((day as Map<String, dynamic>)['items'] as List<dynamic>? ?? [])) {
      final m = item as Map<String, dynamic>;
      final id = m['id'] as int;
      if (!seen.add(id)) continue;
      final nameCn = (m['name_cn'] as String?)?.trim() ?? '';
      final name = (m['name'] as String?)?.trim() ?? '';
      final title = nameCn.isNotEmpty ? nameCn : name;
      if (title.isEmpty) continue;
      final images = m['images'] as Map<String, dynamic>?;
      final cover = images?['large'] as String? ?? images?['common'] as String?;
      final rating = m['rating'] as Map<String, dynamic>?;
      works.add({
        'id': 'bangumi_$id',
        'sourceId': 'bangumi',
        'sourceName': 'Bangumi',
        'type': 'anime',
        'title': title,
        'coverUrl': cover == null
            ? null
            : (cover.startsWith('http://') ? cover.replaceFirst('http://', 'https://') : cover),
        'summary': (m['summary'] as String?)?.trim(),
        'tags': <String>[],
        'author': null,
        'extra': {
          'bangumiId': id,
          'score': rating?['score'],
          'episodes': m['eps'],
          'airDate': m['air_date'],
        },
      });
      if (works.length >= 40) break;
    }
    if (works.length >= 40) break;
  }

  await File('assets/anime_seed.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(works),
  );
  stdout.writeln('wrote ${works.length} entries');
}
```

- [ ] **Step 2: Run the generator**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; dart run tool/gen_seed.dart`
Expected: `wrote <N> entries` with N ≥ 30.

- [ ] **Step 3: Verify the asset and tests**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass.

- [ ] **Step 4: Commit (only if user asked)**

```bash
git add tool/gen_seed.dart assets/anime_seed.json
git commit -m "chore(seed): regenerate offline seed from Bangumi calendar"
```

---
