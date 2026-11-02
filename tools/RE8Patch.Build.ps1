[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [ValidateSet('Release', 'RelWithDebInfo')][string]$Configuration = 'Release',
    [string]$Generator = 'Visual Studio 18 2026',
    [switch]$Configure
)
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'RE8Patch.Common.ps1')
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$source = Join-Path $ProjectRoot 'reframework_src'
$build = Join-Path $source 'build'
$cache = Join-Path $build 'CMakeCache.txt'
$hasCache = Test-Path -LiteralPath $cache -PathType Leaf
if ($Configure -or -not $hasCache) {
    $configureArguments = @('-S', $source, '-B', $build, '-DCMAKE_BUILD_TYPE=Release')
    if ($hasCache) {
        # Explicitly retain the existing generator even when CMAKE_GENERATOR differs.
        $cachedGenerator = Get-Content -LiteralPath $cache | Where-Object { $_ -like 'CMAKE_GENERATOR:INTERNAL=*' } | Select-Object -First 1
        if (-not $cachedGenerator) { throw 'CMake cache has no generator; preserve or remove that cache manually before reconfiguring.' }
        $configureArguments += @('-G', $cachedGenerator.Substring('CMAKE_GENERATOR:INTERNAL='.Length))
    } else {
        $configureArguments += @('-G', $Generator)
        if ($Generator -like 'Visual Studio *') { $configureArguments += @('-A', 'x64') }
    }
    & cmake @configureArguments
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed ($LASTEXITCODE)." }
}
$fingerprint = Get-RE8SourceFingerprint $ProjectRoot
$started = [DateTime]::UtcNow
& cmake --build $build --config $Configuration --target REFramework --parallel 4
if ($LASTEXITCODE -ne 0) { throw "Build failed ($LASTEXITCODE). No package receipt written." }
if ($fingerprint -ne (Get-RE8SourceFingerprint $ProjectRoot)) { throw 'Sources changed while compiling; rebuild before packaging.' }
$binary = @('bin\RE8\dinput8.dll', 'bin\REFramework\dinput8.dll') |
    ForEach-Object { Join-Path $build $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Sort-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc } -Descending | Select-Object -First 1
if (-not $binary) { throw 'Build succeeded but dinput8.dll was not found in an expected output directory.' }
$receipt = [ordered]@{
    schema = 1; configuration = $Configuration; builtUtc = [DateTime]::UtcNow.ToString('o')
    elapsedSeconds = [Math]::Round(([DateTime]::UtcNow - $started).TotalSeconds, 3)
    sourceFingerprint = $fingerprint; binary = $binary; binarySha256 = Get-RE8Hash $binary
    status = 'compiled-only-unverified-in-game'
}
Write-RE8Json (Join-Path $ProjectRoot 'artifacts\build\RE8-build.json') $receipt
Write-Output "Build receipt written. In-game verification remains pending. Binary: $binary"
