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

.PARAMETER Path
The moonmodel package directory. Defaults to the copy inside the module.

.EXAMPLE
pwsh -File scripts/patch_moonmodel.ps1
#>
param(
  [string]$Path = ""
)

$ErrorActionPreference = "Stop"

if ($Path -eq "") {
  $repoRoot = Split-Path -Parent $PSScriptRoot
  $Path = Join-Path $repoRoot "moonbit\.mooncakes\moonbitstack\moonmodel"
}

if (-not (Test-Path $Path)) {
  Write-Host "moonmodel not found at $Path - run 'moon build' first to fetch it" -ForegroundColor Red
  exit 1
}

$patched = 0
$alreadyOk = $true

Get-ChildItem $Path -Recurse -File -Filter "*.mbt" | ForEach-Object {
  $content = Get-Content $_.FullName -Raw -Encoding UTF8
  # The type name only: a quoted "Int32" is a JSON format value, not a type.
  $updated = [regex]::Replace($content, '(?<![a-zA-Z"''])Int32(?![a-zA-Z"''])', 'Int')
  if ($updated -ne $content) {
    # Write without a BOM: the compiler treats a leading BOM as a stray token.
    [System.IO.File]::WriteAllText($_.FullName, $updated, (New-Object System.Text.UTF8Encoding($false)))
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
