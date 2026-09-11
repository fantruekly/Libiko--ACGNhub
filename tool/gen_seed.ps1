$ErrorActionPreference = "Stop"
$out = "D:\ACGNhub\assets\anime_seed.json"
$sourceName = "" + [char]0x79BB + [char]0x7EBF + [char]0x63A8 + [char]0x8350

$items = $null
for ($attempt = 1; $attempt -le 8; $attempt++) {
  try {
    $r = Invoke-WebRequest -Uri "https://api.jikan.moe/v4/top/anime?limit=25" -TimeoutSec 30 -UseBasicParsing
    $items = ($r.Content | ConvertFrom-Json).data
    if ($items -and $items.Count -gt 0) { break }
  } catch {
    Start-Sleep -Seconds (2 * $attempt)
  }
}
if (-not $items) { Write-Error "Jikan /top/anime unavailable"; exit 1 }

$works = New-Object System.Collections.Generic.List[object]
foreach ($it in $items) {
  $malId = $it.mal_id
  $title = if ($it.title_english) { $it.title_english } elseif ($it.title) { $it.title } else { $it.title_japanese }
  $cover = $null
  if ($it.images -and $it.images.jpg -and $it.images.jpg.large_image_url) { $cover = $it.images.jpg.large_image_url }
  $tags = @()
  if ($it.genres) { $tags = @($it.genres | ForEach-Object { $_.name }) }
  $summary = $it.synopsis
  if ($summary) { $summary = ($summary -replace '<[^>]+>', '').Trim() }
  $works.Add([ordered]@{
    id         = "seed_$malId"
    sourceId   = "seed"
    sourceName = $sourceName
    type       = "anime"
    title      = $title
    coverUrl   = $cover
    summary    = $summary
    tags       = $tags
    author     = $null
    extra      = [ordered]@{
      malId      = $malId
      score      = $it.score
      episodes   = $it.episodes
      status     = $it.status
      seasonYear = $it.year
    }
  })
}

[System.IO.File]::WriteAllText($out, ($works | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
$withSummary = ($works | Where-Object { $_.summary -and $_.summary.Length -gt 10 }).Count
$withScore = ($works | Where-Object { $_.extra.score }).Count
Write-Output "total=$($works.Count) withSummary=$withSummary withScore=$withScore"
