<#
.SYNOPSIS
  Lists generated posts and extracts title/date/tags from YAML front-matter robustly.
#>

$RepoRoot   = (Resolve-Path "$PSScriptRoot\..").Path
$ContentDir = Join-Path $RepoRoot 'content\posts'

if (-not (Test-Path $ContentDir)) {
  Write-Host "⚠️  No posts directory found: $ContentDir" -ForegroundColor Yellow
  exit 0
}

$files = Get-ChildItem $ContentDir -Filter *.md | Sort-Object LastWriteTime -Descending
if (-not $files) {
  Write-Host "📭  No posts found."
  exit 0
}

function Get-FrontMatter {
  param([string]$Path)

  $text = Get-Content -Path $Path -Raw
  # Capture the first YAML block delimited by --- ... ---
  if ($text -match '(?s)^---\s*(.*?)\s*---') {
    $yaml = $Matches[1]
  } else {
    return @{
      title = "(untitled)"
      date  = ""
      tags  = @()
    }
  }

  $title = "(untitled)"
  $date  = ""
  $tags  = @()

  foreach ($line in ($yaml -split "`r?`n")) {
    # title: Some Title   OR  title: "Some Title"
    if ($line -match '^\s*title:\s*"?(.+?)"?\s*$') {
      $title = $Matches[1]
      continue
    }
    # date: 2025-10-24T12:34:56Z  (any string preserved)
    if ($line -match '^\s*date:\s*(.+?)\s*$') {
      $date = $Matches[1]
      continue
    }
    # tags: [devops, automation, github]  OR tags: devops, automation, github
    if ($line -match '^\s*tags:\s*(.+)$') {
      $raw = $Matches[1].Trim()
      if ($raw -match '^\[(.*)\]$') {
        $list = $Matches[1] -split '\s*,\s*'
      } else {
        $list = $raw -split '\s*,\s*'
      }
      $tags = $list | ForEach-Object { $_.Trim("'`" ")") } | Where-Object { $_ -ne "" }
      continue
    }
  }

  return @{
    title = $title
    date  = $date
    tags  = $tags
  }
}

Write-Host ""
Write-Host "📝  Blog Posts" -ForegroundColor Cyan
Write-Host "-----------------------------------------------"

foreach ($f in $files) {
  $fm = Get-FrontMatter -Path $f.FullName
  $title = $fm.title
  $date  = $fm.date
  $tags  = if ($fm.tags.Count) { "['{0}']" -f ($fm.tags -join "','") } else { "[]" }
  Write-Host ("• {0,-35} | {1,-25} | {2}" -f $title, $date, $tags) -ForegroundColor Gray
}

Write-Host ""
Write-Host "✅  Total posts: $($files.Count)" -ForegroundColor Green
