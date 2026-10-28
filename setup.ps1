#!/usr/bin/env pwsh
# ProjDesk setup script — applies moonmodel compatibility patch and builds
# Run this after cloning: .\setup.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

Write-Host "=== ProjDesk Setup ===" -ForegroundColor Cyan

# 1. Ensure MoonBit PATH
$env:PATH += ";$env:USERPROFILE\.moon\bin"

# 2. First build (downloads moonmodel dependency)
Write-Host "`n[1/3] Building kernel (downloads dependencies)..." -ForegroundColor Yellow
Push-Location "$root\moonbit"
moon build --target wasm-gc 2>&1 | Out-Null

# 3. Apply Int32->Int compatibility patch to moonmodel
Write-Host "[2/3] Applying moonmodel compatibility patch..." -ForegroundColor Yellow
$patchDir = "$root\moonbit\.mooncakes\moonbitstack\moonmodel"
if (Test-Path $patchDir) {
    $patched = 0
    $alreadyPatched = $false
    Get-ChildItem $patchDir -Recurse -File -Filter "*.mbt" | ForEach-Object {
        $c = Get-Content $_.FullName -Raw
        if ($c -match 'Json::string\("int32"\)') { $alreadyPatched = $true }
        # Replace type name Int32 -> Int (word boundary, case-sensitive)
        $c2 = [regex]::Replace($c, '(?<![a-zA-Z"'])Int32(?![a-zA-Z"'])', 'Int')
        if ($c2 -ne $c) {
            Set-Content $_.FullName $c2 -Encoding UTF8
            $patched++
        }
    }
    # Fix format string if it was corrupted
    $jsonFile = "$patchDir\json\json.mbt"
    if (Test-Path $jsonFile) {
        $c = Get-Content $jsonFile -Raw
        if ($c -match 'Json::string\("Int"\)') {
            $c = $c.Replace('Json::string("Int")', 'Json::string("int32")')
            Set-Content $jsonFile $c -Encoding UTF8
            Write-Host "  Fixed format string in json.mbt" -ForegroundColor Yellow
        }
    }
    if ($alreadyPatched -and $patched -eq 0) {
        Write-Host "  Already patched, skipping" -ForegroundColor Green
    } else {
        Write-Host "  Patched $patched files" -ForegroundColor Green
    }
} else {
    Write-Host "  WARNING: moonmodel not found at $patchDir" -ForegroundColor Red
    Write-Host "  Run 'moon build' first to download dependencies" -ForegroundColor Yellow
}

# 4. Full build + tests
Write-Host "[3/3] Building and testing..." -ForegroundColor Yellow
moon build --target wasm-gc --release 2>&1 | Out-Null
moon test 2>&1 | Select-String "Total"

# 5. Copy WASM to frontend
Copy-Item "$root\moonbit\_build\wasm-gc\release\build\main\main.wasm" "$root\web\public\projdesk.wasm" -Force
Copy-Item "$root\moonbit\_build\wasm-gc\release\build\main\main.wasm" "$root\cli\projdesk.wasm" -Force
Write-Host "  WASM copied to web/public/ and cli/" -ForegroundColor Green

# 6. Build frontend
Push-Location "$root\web"
npm install 2>&1 | Out-Null
npm run build 2>&1 | Select-String "built"
npm run test 2>&1 | Select-String "Tests"
Pop-Location

Write-Host "`n=== Setup complete! ===" -ForegroundColor Green
Write-Host "Run 'cd web; npm run dev' to preview at http://127.0.0.1:3000" -ForegroundColor Cyan

