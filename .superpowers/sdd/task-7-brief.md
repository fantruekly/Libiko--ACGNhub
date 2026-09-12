### Task 7: Entrypoint, Docker, and manual smoke

**Files:**
- Create: `server/bin/server.dart`
- Create: `server/Dockerfile`

**Interfaces:**
- Consumes: `Database.open`, `Auth`, `Api.handler`.
- Produces: a runnable server reading `ACGHUB_JWT_SECRET`, `PORT`, `ACGHUB_DB_PATH`.

- [ ] **Step 1: Create `server/bin/server.dart`**

```dart
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:acgnhub_server/src/api.dart';
import 'package:acgnhub_server/src/auth.dart';
import 'package:acgnhub_server/src/database.dart';

Future<void> main() async {
  final secret = Platform.environment['ACGHUB_JWT_SECRET'];
  if (secret == null || secret.isEmpty) {
    stderr.writeln('ACGHUB_JWT_SECRET is required');
    exit(1);
  }
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dbPath = Platform.environment['ACGHUB_DB_PATH'] ?? 'data/acgnhub.db';

  final dir = Directory(File(dbPath).parent.path);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final db = Database.open(dbPath);
  final handler = Api(db, Auth(secret)).handler;

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('acgnhub-server listening on http://${server.address.host}:${server.port}');
}
```

- [ ] **Step 2: Create `server/Dockerfile`**

```dockerfile
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline

FROM dart:stable
WORKDIR /app
COPY --from=build /app /app
ENV PORT=8080
ENV ACGHUB_DB_PATH=/data/acgnhub.db
VOLUME /data
EXPOSE 8080
CMD ["dart", "run", "bin/server.dart"]
```

- [ ] **Step 3: Analyze**

Run (workdir `server/`): `dart analyze`
Expected: `No issues found!`

- [ ] **Step 4: Manual smoke test (report the exact output)**

Start the server in the background and exercise it with `curl` (workdir `server/`):

```powershell
$env:ACGHUB_JWT_SECRET = "dev-secret"
$env:ACGHUB_DB_PATH = "data/smoke.db"
$p = Start-Process -FilePath "dart" -ArgumentList "run","bin/server.dart" -PassThru -NoNewWindow
Start-Sleep -Seconds 6
$reg = curl.exe -s -X POST http://127.0.0.1:8080/api/auth/register -H "content-type: application/json" -d '{"username":"smoke","password":"secret1"}'
Write-Output "REGISTER=$reg"
$token = ($reg | ConvertFrom-Json).token
Write-Output "ME=$(curl.exe -s http://127.0.0.1:8080/api/me -H "authorization: Bearer $token")"
Write-Output "PUT=$(curl.exe -s -X PUT http://127.0.0.1:8080/api/follows -H "content-type: application/json" -H "authorization: Bearer $token" -d '{"work":{"id":"w1","title":"A"},"updatedAt":100}')"
Write-Output "SYNC=$(curl.exe -s "http://127.0.0.1:8080/api/sync?sinceSeq=0" -H "authorization: Bearer $token")"
Stop-Process -Id $p.Id -Force
Remove-Item -LiteralPath "data/smoke.db" -Force -ErrorAction SilentlyContinue
```

Expected: `REGISTER` contains a `token` and `"id":1`; `ME` returns the user; `PUT` returns the follow; `SYNC` contains it with `"nextSeq":1`.

- [ ] **Step 5: Commit**

```bash
git add server/bin/server.dart server/Dockerfile
git commit -m "feat(server): add the server entrypoint and Dockerfile"
```

---
