# Task 7 Report: Entrypoint, Docker, and manual smoke

## What I implemented

- `server/bin/server.dart` — runnable entrypoint, created verbatim from the brief. It reads
  `ACGHUB_JWT_SECRET` (required; writes `ACGHUB_JWT_SECRET is required` to stderr and exits 1
  if unset/empty), `PORT` (default 8080) and `ACGHUB_DB_PATH` (default `data/acgnhub.db`),
  creates the DB parent directory if missing, opens the database via `Database.open`, builds
  `Api(db, Auth(secret)).handler`, and serves it with `shelf_io.serve` on `InternetAddress.anyIPv4`.
- `server/Dockerfile` — multi-stage build, created verbatim from the brief.

## Smoke test output (verbatim)

Command adapted only for how the process is launched and how the JSON body reaches `curl.exe`
on this Windows/PowerShell 5.1 host (see concerns):

- Server started with the real SDK binary
  `C:\flutter\bin\cache\dart-sdk\bin\dart.exe run bin/server.dart` (the `dart.bat` wrapper
  spawns a child process and exits, so `Start-Process` lost the handle).
- Request bodies passed via `curl.exe -d "@<tempfile>"` because PowerShell 5.1 mangles inline
  JSON containing double quotes when forwarding to native executables.

Server stdout:

```
acgnhub-server listening on http://0.0.0.0:8080
```

HTTP output:

```
REGISTER={"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOjEsInR5cCI6ImFjY2VzcyIsImlhdCI6MTc4OTIxMzA4OCwiZXhwIjoxNzg5MjEzOTg4fQ.-9yhWAW8TpRq30SW6ieNbPfCP092IBXaoRAt176K3Rw","refreshToken":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOjEsInR5cCI6InJlZnJlc2giLCJpYXQiOjE3ODkyMTMwODgsImV4cCI6MTc5MTgwNTA4OH0.ngyw1kGGWrG_x0n4kyrsS5ICrEAhXW9p-yOhpBpstQw","user":{"id":1,"username":"smoke"}}
ME={"id":1,"username":"smoke"}
PUT={"work":{"id":"w1","title":"A"},"updatedAt":100}
SYNC={"follows":[{"work":{"id":"w1","title":"A"},"updatedAt":100,"deleted":false}],"history":[],"nextSeq":1}
```

Result: matches all expectations — `REGISTER` has a `token` and `"id":1`; `ME` returns the user;
`PUT` returns the follow; `SYNC` contains it with `"nextSeq":1`. Server was stopped and
`data/smoke.db` plus the redirect logs were deleted.

`dart analyze` (workdir `server/`): `No issues found!`

## Files changed

- `server/bin/server.dart` (new)
- `server/Dockerfile` (new)

## Self-review findings

- **Completeness:** Both required files exist and match the brief byte-for-byte; analyze passes;
  smoke test passes; commit made with the brief's message. No smoke artifacts remain
  (`server/data/` is empty, `git check-ignore` confirms `/server/data/` is ignored).
- **Quality:** Entrypoint fails fast on a missing secret; directory creation handles the default
  relative path. Dockerfile is the specified multi-stage build.
- **YAGNI:** No extra flags, config files, or code beyond the brief.

## Concerns

1. **Brief's smoke snippet did not run as written on this host.** `Start-Process -FilePath "dart"`
   yielded a process that exited immediately (the `.bat` shim spawns a child), and inline
   `-d '{"..."}'` produced `{"error":"bad_request","message":"Expected a JSON object"}` because
   PowerShell 5.1 stripped the inner double quotes. Both were worked around without changing the
   server code; the API behaved correctly.
2. **No `.dockerignore`.** The brief's `COPY . .` will copy `server/data/`, `.dart_tool/`, and
   `test/` into the build context/image. Left as specified by the brief.
3. **`ACGHUB_JWT_SECRET` is not set in the Dockerfile** (by design — it is a runtime secret), so
   the container requires `-e ACGHUB_JWT_SECRET=...` or it exits 1.

## Commit

- `78c32d9` feat(server): add the server entrypoint and Dockerfile

## Fix report

Two Important review findings were fixed in the Docker packaging.

### What changed

- **`server/Dockerfile` (replaced).** The runtime stage was a fresh `dart:stable` that only
  copied `/app`, so `dart pub get` results from the build stage (`/root/.pub-cache`) were absent
  and `dart run bin/server.dart` could not resolve `package:shelf` at runtime. The runtime stage
  now copies `/root/.pub-cache` from the build stage. It also installs `libsqlite3-0` via
  `apt-get` before copying the app, because on Linux `package:sqlite3` loads `libsqlite3.so.0`,
  which the `dart:stable` image may not provide (the server only overrides the Windows library).
- **`server/.dockerignore` (new).** Ignores `.dart_tool/`, `data/`, and `test/` so the host's
  Windows-path `.dart_tool/`, the runtime DB, and the tests stay out of the build context.

### Commands run and output

`$env:Path = "C:\flutter\bin;$env:Path"; & C:\flutter\bin\dart.bat analyze` (workdir `server/`):

```
Analyzing server...
No issues found!
```

`$env:Path = "C:\flutter\bin;$env:Path"; & C:\flutter\bin\dart.bat test` (workdir `server/`):

```
00:01 +33: All tests passed!
```

### Docker verification limitation (explicit)

**Docker could not be built or run on this machine — there is no Docker daemon available.** The
fix is therefore a correctness fix verified by inspection, not a verified container build.
Reading the final `server/Dockerfile` confirms the runtime stage now contains both required
pieces: `COPY --from=build /root/.pub-cache /root/.pub-cache` (pub cache) and the
`apt-get install -y --no-install-recommends libsqlite3-0` step (`libsqlite3.so.0`).
