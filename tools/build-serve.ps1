<# ==============================================================
 build-serve.ps1
 - Builds (unless -SkipBuild)
 - Serves dist on :Port
 - Accepts -Port argument (default 3000)
 - Shows clear banner with URLs
 ==============================================================#>

[CmdletBinding()]
param(
  [string]$Dir = "dist",
  [int]$Port = 3000,
  [switch]$SkipBuild,
  [switch]$NoOpen,
  [switch]$Force,
  [switch]$Stay
)

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$distPath = Join-Path $root $Dir

function Banner([string]$text) {
  Write-Host "`n=== $text ===" -ForegroundColor Cyan
}

Banner "Project Root"
Write-Host "• Using: $root"
Write-Host "• Output: $distPath"

# --- Build section ---
if (-not $SkipBuild) {
  Banner "Building"
  npm run build
} else {
  Write-Host "⏩ Skipping build (using existing dist folder)"
}

# --- Port check ---
Banner "Port Check"
if (Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet) {
  Write-Host "⚠️ Port $Port is already in use. Please close the existing process or use a different port." -ForegroundColor Yellow
  exit 1
}
Write-Host "✅ Port $Port is free."

# --- Serve section ---
Banner "Serve"

$baseUrl   = "http://127.0.0.1:$Port/"
$serveArgs = @("http-server","`"$distPath`"","-p",$Port,"-a","127.0.0.1","-c-1")  # no -s

# ask http-server to open /, and keep our own fallback in case it doesn't
if (-not $NoOpen) { $serveArgs += @("-o","/") }

Write-Host ""
Write-Host "🚀 Serving built site → $baseUrl" -ForegroundColor Green
Write-Host "📂 Folder: $distPath" -ForegroundColor DarkGray
if (-not $NoOpen) { Write-Host "🧭 Opening browser…" -ForegroundColor DarkGray }
Write-Host "💡 Press CTRL+C to stop the server." -ForegroundColor DarkGray
Write-Host ""

# Fallback opener (some setups ignore http-server -o)
if (-not $NoOpen) {
  Start-Job -ScriptBlock {
    Start-Sleep -Seconds 1
    try { Start-Process $using:baseUrl } catch {}
  } | Out-Null
}

# Launch server (you'll now see request logs like GET "/")
& npx --yes @serveArgs

