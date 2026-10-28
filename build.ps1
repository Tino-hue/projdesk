# ProjDesk one-shot build (Windows PowerShell)
# Usage: .\build.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

Write-Host "=== 1. MoonBit kernel build ===" -ForegroundColor Cyan
Push-Location "$root\moonbit"
$env:PATH += ";$env:USERPROFILE\.moon\bin"
moon build --target wasm-gc --release
Copy-Item "_build\wasm-gc\release\build\main\main.wasm" "$root\web\public\projdesk.wasm" -Force
Copy-Item "_build\wasm-gc\release\build\main\main.wasm" "$root\cli\projdesk.wasm" -Force
Write-Host "WASM copied to web/public/ and cli/" -ForegroundColor Green
Pop-Location

Write-Host "=== 2. Kernel contract tests ===" -ForegroundColor Cyan
Push-Location "$root\moonbit"
moon test
Pop-Location

Write-Host "=== 3. Frontend build ===" -ForegroundColor Cyan
Push-Location "$root\web"
npm run build
Pop-Location

Write-Host "=== 4. Frontend tests ===" -ForegroundColor Cyan
Push-Location "$root\web"
npm run test
Pop-Location

Write-Host "`nAll done! Run 'cd web; npm run dev' to preview at http://127.0.0.1:3000" -ForegroundColor Green
