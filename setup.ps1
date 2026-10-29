#!/usr/bin/env pwsh
# ProjDesk setup script — prepares the dependency, builds the kernel and the
# frontend, and runs both test suites.
# Run this after cloning: .\setup.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

Write-Host "=== ProjDesk Setup ===" -ForegroundColor Cyan

# 1. Ensure MoonBit PATH
$env:PATH += ";$env:USERPROFILE\.moon\bin"
if (-not (Get-Command moon -ErrorAction SilentlyContinue)) {
  Write-Host "The MoonBit toolchain is not on PATH." -ForegroundColor Red
  Write-Host "Install it from https://www.moonbitlang.com/download and run this again." -ForegroundColor Yellow
  exit 1
}
# The kernel is written for MoonBit 0.1.20261023 or newer, which is the
# release that spells the 32-bit integer `Int32` the way moonmodel is
# published. An older toolchain compiles the dependency but not this kernel.
$version = (& moon version | Select-Object -First 1)
$build = [regex]::Match($version, '(\d+)\.\d+\.(\d+)')
if ($build.Success -and [int]$build.Groups[2].Value -lt 20261023) {
  Write-Host "MoonBit $version is too old; 0.1.20261023 or newer is required." -ForegroundColor Red
  Write-Host "Upgrade with 'moon upgrade', or reinstall from https://www.moonbitlang.com/download" -ForegroundColor Yellow
  exit 1
}

# The MoonBit toolchain writes progress to stderr. PowerShell turns that into
# a terminating error when the output is piped, so the preference is relaxed
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

# 2. Build and test the kernel
Write-Host "`n[1/2] Building and testing the kernel..." -ForegroundColor Yellow
if ((Invoke-Moon @("build", "--target", "wasm-gc", "--release") "$root\moonbit") -ne 0) {
  Write-Host "The kernel build failed." -ForegroundColor Red
  exit 1
}
if ((Invoke-Moon @("test") "$root\moonbit") -ne 0) {
  Write-Host "The kernel tests failed." -ForegroundColor Red
  exit 1
}
Copy-Item "$root\moonbit\_build\wasm-gc\release\build\main\main.wasm" "$root\web\public\projdesk.wasm" -Force
Copy-Item "$root\moonbit\_build\wasm-gc\release\build\main\main.wasm" "$root\cli\projdesk.wasm" -Force
Write-Host "  WASM copied to web/public/ and cli/" -ForegroundColor Green

# 3. Build and test the frontend
Write-Host "[2/2] Building and testing the frontend..." -ForegroundColor Yellow
Push-Location "$root\web"
try {
  $ErrorActionPreference = 'Continue'
  npm install
  npm run build
  npm run test
  $code = $LASTEXITCODE
} finally {
  $ErrorActionPreference = 'Stop'
  Pop-Location
}
if ($code -ne 0) {
  Write-Host "The frontend build or tests failed." -ForegroundColor Red
  exit 1
}

Write-Host "`n=== Setup complete! ===" -ForegroundColor Green
Write-Host "Run 'cd web; npm run dev' to preview at http://127.0.0.1:3000" -ForegroundColor Cyan
