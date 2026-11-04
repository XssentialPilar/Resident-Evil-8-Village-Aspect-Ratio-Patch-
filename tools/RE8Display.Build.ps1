[CmdletBinding()]
param([string]$ProjectRoot, [ValidateSet('Release','RelWithDebInfo')][string]$Configuration = 'Release', [string]$Generator = 'Visual Studio 18 2026')
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'RE8Display.Common.ps1')
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$build = Join-Path $ProjectRoot 'artifacts\native'
& cmake -S (Join-Path $ProjectRoot 'native') -B $build -G $Generator -A x64
if ($LASTEXITCODE -ne 0) { throw 'Standalone plugin CMake configuration failed.' }
$fingerprint = Get-RE8DisplayFingerprint $ProjectRoot
$started = [DateTime]::UtcNow
& cmake --build $build --config $Configuration --target RE8Display --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'Standalone plugin build failed.' }
if ($fingerprint -ne (Get-RE8DisplayFingerprint $ProjectRoot)) { throw 'Sources changed during compilation; rebuild before packaging.' }
$binary = Join-Path $build ($Configuration + '\RE8Display.dll')
if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw "Missing build output: $binary" }
Write-RE8Json (Join-Path $ProjectRoot 'artifacts\build\RE8Display-build.json') ([ordered]@{
    schema = 2; version = '2.7.0'; configuration = $Configuration; builtUtc = [DateTime]::UtcNow.ToString('o')
    elapsedSeconds = [Math]::Round(([DateTime]::UtcNow - $started).TotalSeconds,3)
    sourceFingerprint = $fingerprint; binary = $binary; binarySha256 = Get-RE8Hash $binary
    status = 'compiled-runtime-verification-pending'
})
Write-Output "Standalone plugin compiled: $binary"
