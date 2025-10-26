# tools/check-injectVersion.ps1
$ErrorActionPreference = 'Stop'
$file = Join-Path $PSScriptRoot '..\build.mjs'

if (-not (Test-Path $file)) {
  Write-Host "❌ build.mjs not found at $file" -ForegroundColor Red
  exit 1
}

# Count only definitions, not usages:
$definitionPattern = '^\s*(?:function|const)\s+injectVersion\b'
$defs = Select-String -Path $file -Pattern $definitionPattern -AllMatches

if (-not $defs) {
  Write-Host "❌ No injectVersion definition found in build.mjs." -ForegroundColor Red
  exit 1
}

if ($defs.Matches.Count -gt 1) {
  $lines = ($defs | ForEach-Object { $_.LineNumber }) -join ', '
  Write-Host "❌ Multiple injectVersion *definitions* found at lines: $lines" -ForegroundColor Red
  Write-Host "   Remove duplicates so there is exactly one definition." -ForegroundColor Yellow
  exit 1
}

Write-Host "✅ injectVersion definition check passed (exactly one definition)" -ForegroundColor Green
exit 0
