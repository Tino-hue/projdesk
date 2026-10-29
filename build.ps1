# ProjDesk one-shot build (Windows PowerShell)
# Usage: .\build.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

$env:PATH += ";$env:USERPROFILE\.moon\bin"
if (-not (Get-Command moon -ErrorAction SilentlyContinue)) {
  Write-Host "The MoonBit toolchain is not on PATH." -ForegroundColor Red
  Write-Host "Install it from https://www.moonbitlang.com/download and run this again." -ForegroundColor Yellow
  exit 1
}
# The kernel needs MoonBit 0.1.20261023 or newer: that is the release that
# spells the 32-bit integer the way the moonmodel package is published.
$version = (& moon version | Select-Object -First 1)
$build = [regex]::Match($version, '(\d+)\.\d+\.(\d+)')
if ($build.Success -and [int]$build.Groups[2].Value -lt 20261023) {
  Write-Host "MoonBit $version is too old; 0.1.20261023 or newer is required." -ForegroundColor Red
  Write-Host "Upgrade with 'moon upgrade', or reinstall from https://www.moonbitlang.com/download" -ForegroundColor Yellow
  exit 1
}

# The MoonBit toolchain writes progress to stderr, which PowerShell turns into
# a terminating error when the output is piped. The preference is relaxed
# around the calls to it and the exit code is checked instead.
function Invoke-Moon([string[]]$MoonArgs, [string]$WorkingDirectory) {
  Push-Location $WorkingDirectory
  try {
    $ErrorActionPreference = 'Continue'
    # Out-Host keeps the toolchain's output out of the function's return value,
    # so the caller gets the exit code and nothing else.
    & moon @MoonArgs | Out-Host
    return $LASTEXITCODE
  } finally {
    $ErrorActionPreference = 'Stop'
    Pop-Location
  }
}

Write-Host "=== 1. MoonBit kernel build ===" -ForegroundColor Cyan
if ((Invoke-Moon @("build", "--target", "wasm-gc", "--release") "$root\moonbit") -ne 0) {
  Write-Host "The kernel build failed." -ForegroundColor Red
  exit 1
}
Copy-Item "$root\moonbit\_build\wasm-gc\release\build\main\main.wasm" "$root\web\public\projdesk.wasm" -Force
Copy-Item "$root\moonbit\_build\wasm-gc\release\build\main\main.wasm" "$root\cli\projdesk.wasm" -Force
Write-Host "WASM copied to web/public/ and cli/" -ForegroundColor Green

Write-Host "=== 2. Kernel contract tests ===" -ForegroundColor Cyan
if ((Invoke-Moon @("test") "$root\moonbit") -ne 0) {
  Write-Host "The kernel tests failed." -ForegroundColor Red
  exit 1
}

Write-Host "=== 3. Frontend build ===" -ForegroundColor Cyan
Push-Location "$root\web"
try {
  $ErrorActionPreference = 'Continue'
  if (-not (Test-Path "node_modules")) {
    npm install
  }
  npm run build
  $code = $LASTEXITCODE
} finally {
  $ErrorActionPreference = 'Stop'
  Pop-Location
}
if ($code -ne 0) { Write-Host "The frontend build failed." -ForegroundColor Red; exit 1 }

Write-Host "=== 4. Frontend tests ===" -ForegroundColor Cyan
Push-Location "$root\web"
try {
  $ErrorActionPreference = 'Continue'
  npm run test
  $code = $LASTEXITCODE
} finally {
  $ErrorActionPreference = 'Stop'
  Pop-Location
}
if ($code -ne 0) { Write-Host "The frontend tests failed." -ForegroundColor Red; exit 1 }

Write-Host "`nAll done! Run 'cd web; npm run dev' to preview at http://127.0.0.1:3000" -ForegroundColor Green
