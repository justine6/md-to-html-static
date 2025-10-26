param(
  # forwarded ONLY to build-serve.ps1
  [string] $Dir = "dist",
  [switch] $SkipBuild,
  [switch] $NoOpen,
  [switch] $Force,
  [switch] $Stay,

  # post creation controls
  [switch] $NoNewPost,
  [string] $Title,
  [string] $Slug,
  [switch] $Draft
)

$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot

function Banner([string]$t) {
  Write-Host ""
  Write-Host "=== $t ===" -ForegroundColor Cyan
}

# ---------- 1) (Optional) Create a new post ----------
if (-not $NoNewPost) {
  Banner "New Post"

  # Ask for Title if none provided
  if (-not $PSBoundParameters.ContainsKey('Title') -or [string]::IsNullOrWhiteSpace($Title)) {
    $Title = Read-Host "Title"
  }

  if ([string]::IsNullOrWhiteSpace($Title)) {
    Write-Host "✖ No title provided. Aborting new-post step." -ForegroundColor Red
    exit 1
  }

  # If Slug wasn't provided, derive one from Title (lowercase, hyphens)
  if (-not $PSBoundParameters.ContainsKey('Slug') -or [string]::IsNullOrWhiteSpace($Slug)) {
    $Slug = ($Title.ToLowerInvariant() `
              -replace "[^a-z0-9\s-]", "" `
              -replace "\s+", "-" `
              -replace "-+", "-").Trim("-")
  }

  # If Draft wasn’t supplied on the CLI, ask (default = No)
  if (-not $PSBoundParameters.ContainsKey('Draft')) {
    $ans = Read-Host "Mark as draft? (y/N)"
    if ($ans -match '^[yY]') { $Draft = $true }
  }

  # Single, definite action: always call with Title/Slug/Draft
  & "$tools\New-Post.ps1" -Title $Title -Slug $Slug -Draft:$Draft

  if ($LASTEXITCODE -ne 0) {
    Write-Host "✖ New-Post.ps1 failed ($LASTEXITCODE). Aborting." -ForegroundColor Red
    exit $LASTEXITCODE
  }

  Write-Host "✔ New post created successfully." -ForegroundColor Green
}

# ---------- 2) Preview locally (build + serve) ----------
Banner "Local Preview"
& "$tools\build-serve.ps1" `
    -Dir $Dir `
    -SkipBuild:$SkipBuild `
    -NoOpen:$NoOpen `
    -Force:$Force `
    -Stay:$Stay

exit $LASTEXITCODE
