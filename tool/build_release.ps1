# Build the Windows release bundle and package it as a distributable zip.
# Usage: powershell -ExecutionPolicy Bypass -File tool\build_release.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) { $flutter = 'C:\flutter\bin\flutter.bat' }

$raw = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$version = ($raw -split '\+')[0]

& $flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build windows --release failed" }

$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'libiko.exe'))) {
  throw "release bundle not found at $release"
}

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist "Libiko-$version-windows-x64.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
# Running the app can leave a WebView profile beside the executable. Only the
# Flutter data directory and top-level runtime files belong in a release bundle.
$bundleItems = @(Get-ChildItem -LiteralPath $release -Force | Where-Object {
    -not $_.PSIsContainer -or $_.Name -eq 'data'
})
Compress-Archive -LiteralPath $bundleItems.FullName -DestinationPath $zip

$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Output "Built $zip ($size MB)"
