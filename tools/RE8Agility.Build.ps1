[CmdletBinding()]
param([string]$ProjectRoot, [string]$Generator = 'Visual Studio 18 2026')
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'RE8Display.Common.ps1')
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$source = Join-Path $ProjectRoot 'native\agility_probe'
$build = Join-Path $ProjectRoot 'artifacts\agility-probe'
function Get-ProbeSources { @(Get-ChildItem -LiteralPath $source -File | Sort-Object Name | ForEach-Object { [ordered]@{path=$_.Name;sha256=Get-RE8Hash $_.FullName} }) }
$sources = @(Get-ProbeSources)
$sourceSnapshot = ConvertTo-Json -InputObject $sources -Compress
& cmake -S $source -B $build -G $Generator -A x64
if ($LASTEXITCODE -ne 0) { throw 'Agility compatibility probe configuration failed.' }
& cmake --build $build --config Release --target RE8AgilityProbe --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'Agility compatibility probe compilation failed.' }
if ($sourceSnapshot -ne (ConvertTo-Json -InputObject @(Get-ProbeSources) -Compress)) { throw 'Probe sources changed during compilation; rebuild.' }
$binary = Join-Path $build 'Release\RE8AgilityProbe.exe'
& $binary --selftest
if ($LASTEXITCODE -ne 0) { throw 'Agility compatibility probe selftest failed.' }
Write-RE8Json (Join-Path $ProjectRoot 'artifacts\build\RE8Agility-build.json') ([ordered]@{
    schema=1;kit='RE8Agility-722-Compatibility';sdkVersion=722;binary=$binary
    binarySha256=Get-RE8Hash $binary;sources=$sources;selftest='passed; no D3D12 device created'
    builtUtc=[DateTime]::UtcNow.ToString('o');gameIntegration=$false
})
Write-Output "Compiled independent compatibility probe: $binary"
