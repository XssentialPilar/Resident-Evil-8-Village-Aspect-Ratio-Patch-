[CmdletBinding()]
param([string]$ProjectRoot, [string]$Generator = 'Visual Studio 18 2026', [switch]$RunHarness)
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$headers = Join-Path $ProjectRoot 'artifacts/dependencies/directstorage-1.4-preview-inventory/native/include'
$build = Join-Path $ProjectRoot 'artifacts/directstorage-bridge'
$sourcePaths = @('native/directstorage_bridge/CMakeLists.txt','native/directstorage_bridge/RE8DirectStorageBridge.cpp',
    'native/directstorage_bridge/RE8DirectStorageCore.hpp','tools/RE8DirectStorageBridge.Build.ps1',
    'external/reframework-sdk/reframework/API.h','external/reframework-sdk/reframework/API.hpp',
    'artifacts/dependencies/directstorage-1.4-preview-inventory/native/include/dstorage.h')
function Get-BridgeSources {
    @($sourcePaths | Sort-Object | ForEach-Object { [pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $ProjectRoot $_) -Algorithm SHA256).Hash} })
}
$sources = Get-BridgeSources
if (($sources | Where-Object path -like '*/dstorage.h').sha256 -ne 'ED5CCC1C84C57FC35EE13708DE1044F08E18B623D083F991BF85C420C8623D78') { throw 'DirectStorage header mismatch.' }
& cmake -S (Join-Path $ProjectRoot 'native/directstorage_bridge') -B $build -G $Generator -A x64 "-DDIRECTSTORAGE_INCLUDE_DIR=$headers"
if ($LASTEXITCODE -ne 0) { throw 'DirectStorage bridge configure failed.' }
& cmake --build $build --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'DirectStorage bridge build failed.' }
if (($sources | ConvertTo-Json -Compress) -ne ((Get-BridgeSources) | ConvertTo-Json -Compress)) { throw 'Bridge sources changed during build; rebuild.' }
$binary = Join-Path $build 'Release/RE8DirectStorage.dll'
$harnessVerified = $false
$fixture = $null
if ($RunHarness) {
    $fixture = Join-Path $ProjectRoot ('artifacts/tests/directstorage-live-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $fixture 'RE8DirectStorage') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $build 'Release/re8.exe') -Destination (Join-Path $fixture 're8.exe')
    Copy-Item -LiteralPath $binary -Destination (Join-Path $fixture 'RE8DirectStorageBridge-under-test.dll')
    Copy-Item -LiteralPath (Join-Path $build 'Release/RE8DirectStorageFaultTest.dll') -Destination (Join-Path $fixture 'RE8DirectStorageFaultTest.dll')
    $hashes = @{'dstorage.dll'='4AE887A8CD21DB2CFECD97C34B5F4DA48D8370D4646F3853D60DB809AA02A8BF';'dstoragecore.dll'='C6A160899D2C607E1547476B210E36B1CE059A78FEB6DC027A2A0CF4A6F22B78'}
    foreach ($name in $hashes.Keys) {
        $source = Join-Path $ProjectRoot ('artifacts/dependencies/directstorage-1.4-preview-inventory/native/bin/x64/' + $name)
        $signature = Get-AuthenticodeSignature -LiteralPath $source
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $hashes[$name] -or $signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'CN=Microsoft Corporation,') { throw 'Private DirectStorage runtime hash/signature mismatch.' }
        Copy-Item -LiteralPath $source -Destination (Join-Path $fixture ('RE8DirectStorage/' + $name))
    }
    & (Join-Path $fixture 're8.exe') (Join-Path $fixture 'RE8DirectStorageBridge-under-test.dll')
    if ($LASTEXITCODE -ne 0) { throw "Isolated DirectStorage integration harness failed; fixture: $fixture" }
    & (Join-Path $fixture 're8.exe') (Join-Path $fixture 'RE8DirectStorageBridge-under-test.dll') --no-ex
    if ($LASTEXITCODE -ne 0) { throw 'Optional SetFilePointerEx import test failed.' }
    & (Join-Path $fixture 're8.exe') (Join-Path $fixture 'RE8DirectStorageBridge-under-test.dll') --sync-ov
    if ($LASTEXITCODE -ne 0) { throw 'Synchronous OVERLAPPED native-oracle integration test failed.' }
    & (Join-Path $fixture 're8.exe') (Join-Path $fixture 'RE8DirectStorageBridge-under-test.dll') --conflict
    if ($LASTEXITCODE -ne 0) { throw 'Foreign import-hook rejection test failed.' }
    foreach ($mode in @('--rollback','--timeout','--mixed','--mismatch')) {
        & (Join-Path $fixture 're8.exe') (Join-Path $fixture 'RE8DirectStorageFaultTest.dll') $mode
        if ($LASTEXITCODE -ne 0) { throw "DirectStorage fault harness failed: $mode" }
    }
    $harnessVerified = $true
}
$receiptDirectory = Join-Path $ProjectRoot 'artifacts/build'
New-Item -ItemType Directory -Path $receiptDirectory -Force | Out-Null
$receipt = [ordered]@{schema=1;technology='DirectStorage';buildConfiguration='Release';binary=$binary;binarySha256=(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash;
    sources=@($sources);harnessVerified=$harnessVerified;harnessFixture=$fixture;actualGameActivationVerified=$false;scope='experimental synchronous readonly PAK file-to-CPU-memory; original game decompression retained'}
[IO.File]::WriteAllText((Join-Path $receiptDirectory 'RE8DirectStorageBridge-build.json'), (($receipt | ConvertTo-Json -Depth 6) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
Write-Output "Built experimental DirectStorage CPU PAK bridge: $binary"
Write-Output "Isolated harness verified: $harnessVerified; real RE8 activation is not yet verified."
