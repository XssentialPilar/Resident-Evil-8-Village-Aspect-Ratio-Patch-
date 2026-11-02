[CmdletBinding()]
param([string]$ProjectRoot, [string]$Generator = 'Visual Studio 18 2026')
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$headers = Join-Path $ProjectRoot 'artifacts/dependencies/directstorage-1.4-preview-inventory/native/include'
$build = Join-Path $ProjectRoot 'artifacts/directstorage-probe'
if (-not (Test-Path -LiteralPath (Join-Path $headers 'dstorage.h') -PathType Leaf)) {
    throw 'Missing locally inspected SDK headers; this build does not download or distribute Microsoft binaries.'
}
if ((Get-FileHash -LiteralPath (Join-Path $headers 'dstorage.h') -Algorithm SHA256).Hash -ne 'ED5CCC1C84C57FC35EE13708DE1044F08E18B623D083F991BF85C420C8623D78') {
    throw 'DirectStorage header does not match the reviewed preview package.'
}
function Get-ProbeSources {
    return (@('native/directstorage_probe/CMakeLists.txt','native/directstorage_probe/main.cpp') | ForEach-Object {
        $_ + ':' + (Get-FileHash -LiteralPath (Join-Path $ProjectRoot $_) -Algorithm SHA256).Hash
    }) -join '|'
}
$sources = Get-ProbeSources
& cmake -S (Join-Path $ProjectRoot 'native/directstorage_probe') -B $build -G $Generator -A x64 "-DDIRECTSTORAGE_INCLUDE_DIR=$headers"
if ($LASTEXITCODE -ne 0) { throw 'DirectStorage compatibility probe CMake configure failed.' }
& cmake --build $build --config Release --target RE8DirectStorageProbe --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'DirectStorage compatibility probe build failed.' }
$binary = Join-Path $build 'Release/RE8DirectStorageProbe.exe'
& $binary --help
if ($LASTEXITCODE -ne 0) { throw 'Compatibility probe help failed.' }
& $binary --selftest
if ($LASTEXITCODE -ne 0) { throw 'Compatibility probe selftest failed.' }
if ((Get-ProbeSources) -ne $sources) { throw 'Probe sources changed during compilation; rebuild.' }
$receiptDirectory = Join-Path $ProjectRoot 'artifacts/build'
New-Item -ItemType Directory -Path $receiptDirectory -Force | Out-Null
$receipt = [ordered]@{schema=1;kind='standalone-compatibility-only';sources=$sources;binarySha256=(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash;runtimeExecuted=$false}
[IO.File]::WriteAllText((Join-Path $receiptDirectory 'RE8DirectStorage-build.json'), (($receipt | ConvertTo-Json) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
Write-Output "Built standalone compatibility probe (runtime not executed): $binary"
