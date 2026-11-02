[CmdletBinding()]
param([string]$ProjectRoot)
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $ProjectRoot 'tools\RE8Patch.Common.ps1')
$fixture = Get-RE8ContainedPath $ProjectRoot ('artifacts\tests\build-configuration-' + [Guid]::NewGuid().ToString('N'))
$source = Join-Path $fixture 'reframework_src'
foreach ($relative in @('src', 'shared', 'include', 'dependencies\imgui')) {
    [IO.Directory]::CreateDirectory((Join-Path $source $relative)) | Out-Null
}
# This target exercises CMake configuration and output handling only. It copies
# an expressly fake DLL; it does not compile or validate the actual game patch.
$cmakeFixture = @'
cmake_minimum_required(VERSION 3.20)
project(RE8BuildConfigurationFixture NONE)
add_custom_command(
    OUTPUT "${CMAKE_BINARY_DIR}/bin/RE8/dinput8.dll"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_BINARY_DIR}/bin/RE8"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_SOURCE_DIR}/fake-dll.txt" "${CMAKE_BINARY_DIR}/bin/RE8/dinput8.dll"
    DEPENDS "${CMAKE_SOURCE_DIR}/fake-dll.txt"
    VERBATIM
)
add_custom_target(REFramework DEPENDS "${CMAKE_BINARY_DIR}/bin/RE8/dinput8.dll")
'@
[IO.File]::WriteAllText((Join-Path $source 'CMakeLists.txt'), $cmakeFixture)
[IO.File]::WriteAllText((Join-Path $source 'cmake.toml'), '# fixture only')
[IO.File]::WriteAllText((Join-Path $source 'fake-dll.txt'), 'FAKE DLL: build configuration fixture, not a compiled patch')
$buildScript = Join-Path $ProjectRoot 'tools\RE8Patch.Build.ps1'
$previousGenerator = $env:CMAKE_GENERATOR
try {
    $env:CMAKE_GENERATOR = 'Ninja Multi-Config'
    & $buildScript -ProjectRoot $fixture | Out-Null
    $cache = Join-Path $source 'build\CMakeCache.txt'
    $content = Get-Content -LiteralPath $cache -Raw
    if ($content -notmatch '(?m)^CMAKE_GENERATOR:INTERNAL=Visual Studio 18 2026\r?$') { throw 'Fresh build did not explicitly select Visual Studio 18 2026.' }
    if ($content -notmatch '(?m)^CMAKE_GENERATOR_PLATFORM:INTERNAL=x64\r?$') { throw 'Fresh Visual Studio configure did not use x64.' }
    # A requested generator applies only to a fresh cache. Reconfiguring a VS
    # cache must retain VS even when both this argument and the environment differ.
    & $buildScript -ProjectRoot $fixture -Configure -Generator 'Ninja Multi-Config' | Out-Null
    $content = Get-Content -LiteralPath $cache -Raw
    if ($content -notmatch '(?m)^CMAKE_GENERATOR:INTERNAL=Visual Studio 18 2026\r?$') { throw 'Reconfiguration changed the existing cache generator.' }
    $receipt = Get-Content -LiteralPath (Join-Path $fixture 'artifacts\build\RE8-build.json') -Raw | ConvertFrom-Json
    if ($receipt.binarySha256 -ne (Get-RE8Hash (Join-Path $source 'fake-dll.txt'))) { throw 'Fixture output receipt hash mismatch.' }
    Write-RE8Json (Join-Path $fixture 'result.json') ([ordered]@{ status = 'passed'; checks = 4; scope = 'actual CMake configure/build of a copy-only fixture; no game patch compilation'; fixture = $fixture })
    Write-Output "PASS: 4 build configuration checks; fixture: $fixture"
} finally {
    $env:CMAKE_GENERATOR = $previousGenerator
}
