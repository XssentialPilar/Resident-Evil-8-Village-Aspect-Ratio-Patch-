[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$build = Join-Path $projectRoot 'artifacts\tests\standalone'
& cmake -S (Join-Path $projectRoot 'tests\standalone') -B $build -G 'Visual Studio 18 2026' -A x64
if ($LASTEXITCODE -ne 0) { throw 'Standalone tests configuration failed.' }
& cmake --build $build --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'Standalone tests build failed.' }
& ctest --test-dir $build -C Release --output-on-failure
if ($LASTEXITCODE -ne 0) { throw 'Standalone logic tests failed.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'tests\RE8Display.Install.Tests.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Standalone installation tests failed.' }
Write-Output 'Standalone checks passed. Image, menu interaction and mod compatibility are recorded separately.'
