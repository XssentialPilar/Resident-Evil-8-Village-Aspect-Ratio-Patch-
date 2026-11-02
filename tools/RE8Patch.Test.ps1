[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $projectRoot 'artifacts\tests\native-vs'
& cmake -S $projectRoot -B $testBuild -G 'Visual Studio 18 2026' -A x64
if ($LASTEXITCODE -ne 0) { throw 'Native test configuration failed.' }
& cmake --build $testBuild --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'Native test build failed.' }
& ctest --test-dir $testBuild -C Release --output-on-failure
if ($LASTEXITCODE -ne 0) { throw 'Native/Lua tests failed.' }
foreach ($suite in @('RE8Patch.Install.Tests.ps1', 'RE8Patch.Package.Tests.ps1', 'RE8Patch.Build.Tests.ps1', 'RE8Patch.PrepareSource.Tests.ps1')) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot ('tests\' + $suite))
    if ($LASTEXITCODE -ne 0) { throw "Tooling test failed: $suite" }
}
Write-Output 'Native, Lua and file-operation checks passed. In-game tests are recorded separately.'
