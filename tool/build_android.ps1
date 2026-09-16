# Build a universal release APK and copy it to dist/.
# Run tool\gen_keystore.ps1 first, otherwise the APK is debug-signed (not distributable).
# Usage: powershell -ExecutionPolicy Bypass -File tool\build_android.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) { $flutter = 'C:\flutter\bin\flutter.bat' }

if (-not (Test-Path 'android\key.properties')) {
  Write-Warning 'android/key.properties not found: the APK will be debug-signed. Run tool\gen_keystore.ps1 first.'
}

$raw = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$version = ($raw -split '\+')[0]

& $flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build apk --release failed' }

$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { throw "APK not found: $apk" }

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$out = Join-Path $dist "Libiko-$version-android.apk"
Copy-Item $apk $out -Force
Write-Output "Built $out ($([math]::Round((Get-Item $out).Length / 1MB, 1)) MB)"
