param(
  [Parameter(Mandatory = $true)]
  [string] $Title,

  [string] $Slug,
  [switch] $Draft
)

$ErrorActionPreference = 'Stop'

# Make a slug if missing
if ([string]::IsNullOrWhiteSpace($Slug)) {
  $Slug = ($Title.ToLowerInvariant() `
            -replace "[^a-z0-9\s-]", "" `
            -replace "\s+", "-" `
            -replace "-+", "-").Trim("-")
}

$root  = Split-Path -Parent $PSScriptRoot
$posts = Join-Path $root "content\posts"
$null  = New-Item -ItemType Directory -Force -Path $posts | Out-Null

# Unique filename if exists
$file = Join-Path $posts "$Slug.md"
$base = $Slug; $i = 2
while (Test-Path $file) {
  $Slug = "$base-$i"
  $file = Join-Path $posts "$Slug.md"
  $i++
}

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$draftLine = if ($Draft) { "draft: true" } else { "" }

@"
---
title: "$Title"
date: $now
slug: $Slug
$draftLine
---

Write your post here. You can use regular **Markdown**.

Replace this intro.
Add code blocks.
Add images (put assets in \public\).
"@ | Set-Content -Encoding UTF8 $file

Write-Host "✅ New post created at: $file"
exit 0