<#
.SYNOPSIS
  Build the site and push a release commit to trigger GitHub Actions.

.DESCRIPTION
  - Runs npm install (ci if lock file exists), lints (optional), and builds.
  - Verifies dist/ exists and has index.html.
  - Creates a conventional-commit style message.
  - Pushes to the current branch (default: main).

.PARAMETER Message
  Extra text to append to the release commit message.

.PARAMETER SkipInstall
  Skip dependency install step.

.PARAMETER Branch
  Branch to push to (defaults to current).

.PARAMETER Target
  Optional hint for humans only: pages | main | both (Action picks up routing).
#>

[CmdletBinding()]
param(
  [string]$Message = "",
  [switch]$SkipInstall,
  [string]$Branch,
  [ValidateSet('pages','main','both','')]
  [string]$Target = ''
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "▶ $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "✖ $msg" -ForegroundColor Red; exit 1 }

# 0) Ensure we’re at repo root
if (-not (Test-Path .git)) { Fail "Run this from the repository root (no .git found)." }

# 1) Figure out branch
if (-not $Branch) {
  $Branch = (git rev-parse --abbrev-ref HEAD).Trim()
}
Write-Step "Using branch: $Branch"

# 2) Install deps (unless skipped)
if (-not $SkipInstall) {
  if (Test-Path package-lock.json) {
    Write-Step "Installing dependencies (npm ci)…"
    npm ci
  } else {
    Write-Step "Installing dependencies (npm install)…"
    npm install
  }
}

# 3) Optional lint (uncomment when you add eslint)
# Write-Step "Linting…"
# npm run lint

# 4) Build
Write-Step "Building site…"
npm run build

# 5) Verify build
if (-not (Test-Path dist/index.html)) {
  Fail "Build failed: dist/index.html not found."
}
Write-Step "Build OK (dist/ ready)."

# 6) Compose release message
$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$targetNote = if ($Target) { " [target:$Target]" } else { "" }
$commitMsg = "release: publish site $targetNote ($ts)"
if ($Message) { $commitMsg += "`n`n$Message" }

# 7) Commit & push
Write-Step "Staging changes…"
git add -A

# Avoid empty commits
$diff = git status --porcelain
if ([string]::IsNullOrWhiteSpace($diff)) {
  Write-Step "No file changes detected (skipping commit). Pushing to trigger CI anyway…"
} else {
  Write-Step "Creating commit…"
  git commit -m $commitMsg
}

Write-Step "Pushing to origin/$Branch…"
git push origin $Branch

Write-Host "`n✅ Done. GitHub Actions will pick this up and deploy." -ForegroundColor Green

# 8) Optional: trigger workflow_dispatch with custom inputs (requires GitHub CLI).
# if (Get-Command gh -ErrorAction SilentlyContinue) {
#   Write-Step "Triggering workflow dispatch (optional)…"
#   gh workflow run build-multi-deploy.yml --raw-field deploy_pages=true --raw-field deploy_main=true
# }
