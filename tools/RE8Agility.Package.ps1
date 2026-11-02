[CmdletBinding()]
param([string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'RE8Display.Common.ps1')
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$receipt = Get-Content -LiteralPath (Join-Path $ProjectRoot 'artifacts\build\RE8Agility-build.json') -Raw | ConvertFrom-Json
$expected = Join-Path $ProjectRoot 'artifacts\agility-probe\Release\RE8AgilityProbe.exe'
if ($receipt.schema -ne 1 -or $receipt.sdkVersion -ne 722 -or $receipt.binary -ne $expected -or (Get-RE8Hash $expected) -ne $receipt.binarySha256) { throw 'Invalid or stale Agility probe build receipt.' }
if (@($receipt.sources).Count -ne 2) { throw 'Unexpected probe source receipt.' }
foreach ($source in $receipt.sources) {
    if ($source.path -notin @('CMakeLists.txt','RE8AgilityProbe.cpp') -or (Get-RE8Hash (Join-Path $ProjectRoot ('native\agility_probe\' + $source.path))) -ne $source.sha256) { throw 'Agility probe source changed since compilation.' }
}
$stage = Join-Path $ProjectRoot ('artifacts\agility-kit-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage) | Out-Null
$payload = @(
    @{source=$expected;name='RE8AgilityProbe.exe'}
    @{source=(Join-Path $ProjectRoot 'tools\RE8Agility.Setup.ps1');name='setup.ps1'}
    @{source=(Join-Path $ProjectRoot 'docs\agility-compatibility-kit-README.md');name='README.md'}
    @{source=(Join-Path $ProjectRoot 'docs\agility-1.722.0-preview-assessment.md');name='agility-assessment.md'}
    @{source=(Join-Path $ProjectRoot 'LICENSE');name='LICENSE.txt'}
)
foreach ($file in $payload) { Copy-Item -LiteralPath $file.source -Destination (Join-Path $stage $file.name) }
$destination = Join-Path $ProjectRoot 'dist\RE8Agility-722-Compatibility.zip'
[IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$temporary = Join-Path (Split-Path -Parent $destination) ('RE8Agility-722-' + [Guid]::NewGuid().ToString('N') + '.zip')
$archive = [IO.Compression.ZipFile]::Open($temporary,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $payload) { [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $stage $file.name),$file.name,[IO.Compression.CompressionLevel]::Optimal) | Out-Null }
} finally { $archive.Dispose() }
$verify = [IO.Compression.ZipFile]::OpenRead($temporary)
try {
    if ($verify.Entries.Count -ne $payload.Count -or @($verify.Entries | Where-Object { $_.FullName -notin $payload.name }).Count -ne 0) { throw 'Unexpected compatibility kit contents.' }
    if (@($verify.Entries | Where-Object { $_.FullName -match '(?i)(D3D12Core|SDKLayers|\.nupkg$|\.pdb$|\.dll$)' }).Count) { throw 'Preview binaries must not be redistributed.' }
} finally { $verify.Dispose() }
Move-Item -LiteralPath $temporary -Destination $destination -Force
$hash = Get-RE8Hash $destination
[IO.File]::WriteAllText((Join-Path (Split-Path -Parent $destination) 'SHA256SUMS-RE8Agility-722.txt'),($hash + '  RE8Agility-722-Compatibility.zip' + [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
Write-RE8Json (Join-Path $ProjectRoot 'artifacts\build\RE8Agility-package.json') ([ordered]@{schema=1;archive=$destination;sha256=$hash;files=$payload.name;gameIntegration=$false;previewRuntimeRedistributed=$false})
Write-Output "Optional compatibility kit: $destination"
Write-Output "SHA256: $hash"
