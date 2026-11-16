# Real Windows playback audit. Does not load the user's database or login.
[CmdletBinding()]
param(
  [string[]]$Keywords = @('鬼灭', '葬送的芙莉莲'),
  [string[]]$Sources = @(),
  [ValidateRange(10, 60)][int]$ObserveSeconds = 10,
  [ValidateRange(1, 5)][int]$MaxLines = 3,
  [string]$ReportDirectory = 'dist/playback-audit',
  [switch]$TestSeek,
  [switch]$TestNext,
  [ValidateRange(0, 99999)][int]$StartEpisode = 0,
  [switch]$SkipRestore
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) { $flutter = 'C:\flutter\bin\flutter.bat' }
$report = if ([IO.Path]::IsPathRooted($ReportDirectory)) {
  [IO.Path]::GetFullPath($ReportDirectory)
} else {
  [IO.Path]::GetFullPath((Join-Path $root $ReportDirectory))
}
New-Item -ItemType Directory -Force -Path $report | Out-Null
$arguments = @('run', '-d', 'windows', '--no-pub', '--no-dds', '-t', 'tool/playback_probe.dart',
  "--dart-define=PLAYBACK_AUDIT_DIR=$report",
  "--dart-define=PLAYBACK_AUDIT_KEYWORDS=$($Keywords -join ',')",
  "--dart-define=PLAYBACK_AUDIT_SOURCES=$($Sources -join ',')",
  "--dart-define=PLAYBACK_AUDIT_SECONDS=$ObserveSeconds",
  "--dart-define=PLAYBACK_AUDIT_LINES=$MaxLines",
  "--dart-define=PLAYBACK_AUDIT_NEXT=$($TestNext.IsPresent.ToString().ToLowerInvariant())",
  "--dart-define=PLAYBACK_AUDIT_START_EPISODE=$StartEpisode",
  "--dart-define=PLAYBACK_AUDIT_SEEK=$($TestSeek.IsPresent.ToString().ToLowerInvariant())")
try {
  & $flutter @arguments 2>&1 | ForEach-Object {
    # Native media libraries may include a signed URL in diagnostics.
    $_.ToString() -replace 'https?://[^\s"<>]+', '[URL]'
  } | Tee-Object -FilePath (Join-Path $report 'runner.log')
  if ($LASTEXITCODE -ne 0) { throw 'Playback audit process failed; inspect report.json and runner.log.' }
  Write-Output "Playback audit saved to $report"
} finally {
  if (-not $SkipRestore) {
    & $flutter build windows --debug --no-pub -t lib/main.dart
    if ($LASTEXITCODE -ne 0) { throw 'Could not restore the normal app build.' }
  }
}
