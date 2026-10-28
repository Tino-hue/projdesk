$ErrorActionPreference = "Stop"
$tmp = "D:\moonprobe"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Force $tmp | Out-Null
$home_ = "$tmp\home"

Write-Host "=== downloading the latest toolchain ===" -ForegroundColor Cyan
curl.exe -fsSL --max-time 300 -o "$tmp\moonbit.zip" "https://cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.zip"
"moonbit.zip: {0} bytes" -f (Get-Item "$tmp\moonbit.zip").Length
curl.exe -fsSL --max-time 300 -o "$tmp\core.tar.gz" "https://cli.moonbitlang.com/cores/core-latest.tar.gz"
"core.tar.gz: {0} bytes" -f (Get-Item "$tmp\core.tar.gz").Length

Write-Host "=== extracting ===" -ForegroundColor Cyan
Expand-Archive "$tmp\moonbit.zip" -DestinationPath $home_ -Force
New-Item -ItemType Directory -Force "$home_\lib" | Out-Null
tar xf "$tmp\core.tar.gz" -C "$home_\lib"
Get-ChildItem $home_ | Select-Object Name
Get-ChildItem "$home_\bin" -ErrorAction SilentlyContinue | Select-Object Name

Write-Host "=== the new toolchain's version ===" -ForegroundColor Cyan
$env:MOON_HOME = $home_
$env:PATH = "$home_\bin;" + $env:PATH
& "$home_\bin\moon.exe" version

Write-Host "=== bundling the core library ===" -ForegroundColor Cyan
Push-Location "$home_\lib\core"
& "$home_\bin\moon.exe" -C "$home_\lib\core" bundle --warn-list -a --all 2>&1 | Select-Object -Last 3
& "$home_\bin\moon.exe" -C "$home_\lib\core" bundle --warn-list -a --target wasm-gc --quiet 2>&1 | Select-Object -Last 3
Pop-Location

Write-Host "=== copying the kernel and compiling it with the new toolchain ===" -ForegroundColor Cyan
Copy-Item "D:\moonbit-projdesk\moonbit" "$tmp\kernel" -Recurse -Force
Remove-Item "$tmp\kernel\_build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$tmp\kernel\.mooncakes" -Recurse -Force -ErrorAction SilentlyContinue
Push-Location "$tmp\kernel"
& "$home_\bin\moon.exe" build --target wasm-gc 2>&1 | Select-Object -Last 40
Pop-Location
