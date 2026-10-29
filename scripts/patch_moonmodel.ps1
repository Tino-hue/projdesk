<#
.SYNOPSIS
Makes the published moonmodel package compile against this kernel's toolchain.

.DESCRIPTION
The MoonBit toolchain this kernel is written for spells the 32-bit integer
`Int`. MoonBit later renamed that type to `Int32`, and the moonmodel package
is published against the newer spelling, so the dependency has to be adjusted
before it will compile.

The patch is deliberately minimal: it renames the type in type positions and
leaves everything else alone. It is applied to the copy of the package that
the build downloaded, never to the registry cache.

If the dependency has not been fetched yet, this fetches it first, so it can
be run on a fresh clone without any other step.

.PARAMETER Path
The moonmodel package directory. Defaults to the copy inside the module.

.EXAMPLE
pwsh -File scripts/patch_moonmodel.ps1
#>
param(
  [string]$Path = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$moduleDir = Join-Path $repoRoot "moonbit"

if ($Path -eq "") {
  $Path = Join-Path $moduleDir ".mooncakes\moonbitstack\moonmodel"
}

function Get-DependencyFiles {
  if (-not (Test-Path $Path)) {
    return @()
  }
  return @(Get-ChildItem $Path -Recurse -File -Filter "*.mbt")
}

if ((Get-DependencyFiles).Count -eq 0) {
  Write-Host "Fetching the moonmodel dependency..." -ForegroundColor Yellow
  Push-Location $moduleDir
  try {
    # `moon install` fetches the dependency without compiling it. A build
    # would fail here, because the dependency is what still needs patching.
    #
    # The error preference is relaxed for the call on purpose: redirecting a
    # native command's stderr into a pipeline turns its warnings into
    # terminating errors, which would kill it before it downloaded anything.
    $ErrorActionPreference = 'Continue'
    moon install *> $null
  } catch {
    # not every toolchain has `moon install`; the build below fetches too
  } finally {
    $ErrorActionPreference = 'Stop'
    Pop-Location
  }
}

if ((Get-DependencyFiles).Count -eq 0) {
  Push-Location $moduleDir
  try {
    # The build fails until the dependency is patched, which is what this
    # script is here to do, so the failure is expected.
    $ErrorActionPreference = 'Continue'
    moon build --target wasm-gc *> $null
  } catch {
  } finally {
    $ErrorActionPreference = 'Stop'
    Pop-Location
  }
}

$files = Get-DependencyFiles
if ($files.Count -eq 0) {
  Write-Host "moonmodel not found at $Path" -ForegroundColor Red
  Write-Host "Run 'cd moonbit && moon build' to fetch it, then run this script again." -ForegroundColor Yellow
  exit 1
}

$patched = 0
$alreadyOk = $true

foreach ($file in $files) {
  $content = Get-Content $file.FullName -Raw -Encoding UTF8
  # The type name only: a quoted "Int32" is a JSON format value, not a type.
  $updated = [regex]::Replace($content, '(?<![a-zA-Z"''])Int32(?![a-zA-Z"''])', 'Int')
  if ($updated -ne $content) {
    # Write without a BOM: the compiler treats a leading BOM as a stray token.
    [System.IO.File]::WriteAllText($file.FullName, $updated, (New-Object System.Text.UTF8Encoding($false)))
    $patched++
    $alreadyOk = $false
  }
}

# The JSON Schema format value for a 32-bit integer stays "int32".
$jsonFile = Join-Path $Path "json\json.mbt"
if (Test-Path $jsonFile) {
  $content = Get-Content $jsonFile -Raw -Encoding UTF8
  if ($content -match 'Json::string\("Int"\)') {
    $content = $content.Replace('Json::string("Int")', 'Json::string("int32")')
    [System.IO.File]::WriteAllText($jsonFile, $content, (New-Object System.Text.UTF8Encoding($false)))
  }
}

if ($alreadyOk) {
  Write-Host "moonmodel already matches this toolchain - nothing to patch" -ForegroundColor Green
} else {
  Write-Host "Patched $patched moonmodel file(s) for this toolchain" -ForegroundColor Green
}
