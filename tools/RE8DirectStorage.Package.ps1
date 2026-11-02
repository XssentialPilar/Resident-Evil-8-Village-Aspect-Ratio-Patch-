[CmdletBinding()]
param([string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$binary = Join-Path $ProjectRoot 'artifacts/directstorage-probe/Release/RE8DirectStorageProbe.exe'
if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw 'Build the compatibility probe before packaging.' }
$receipt = Get-Content -LiteralPath (Join-Path $ProjectRoot 'artifacts/build/RE8DirectStorage-build.json') -Raw | ConvertFrom-Json
$sources = (@('native/directstorage_probe/CMakeLists.txt','native/directstorage_probe/main.cpp') | ForEach-Object {
    $_ + ':' + (Get-FileHash -LiteralPath (Join-Path $ProjectRoot $_) -Algorithm SHA256).Hash
}) -join '|'
if ($receipt.schema -ne 1 -or $receipt.sources -ne $sources -or $receipt.binarySha256 -ne (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash) {
    throw 'Probe binary/source receipt mismatch; rebuild before packaging.'
}
$headerLicense = Join-Path $ProjectRoot 'artifacts/dependencies/directstorage-1.4-preview-inventory/LICENSE-CODE.txt'
if ((Get-FileHash -LiteralPath $headerLicense -Algorithm SHA256).Hash -ne '903DF5512F7D02609FED0C780A9B704F5A3EEB6E4D84EBE42A29845C81899A3C') { throw 'Header license mismatch.' }
$dist = Join-Path $ProjectRoot 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$stage = Join-Path $ProjectRoot ('artifacts/directstorage-kit-' + [Guid]::NewGuid().ToString('N'))
foreach ($directory in @('bin','tools','licenses')) { New-Item -ItemType Directory -Path (Join-Path $stage $directory) -Force | Out-Null }
Copy-Item -LiteralPath $binary -Destination (Join-Path $stage 'bin/RE8DirectStorageProbe.exe')
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'tools/RE8DirectStorage.Setup.ps1') -Destination (Join-Path $stage 'tools/RE8DirectStorage.Setup.ps1')
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'native/directstorage_probe/README.md') -Destination (Join-Path $stage 'README.md')
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'LICENSE') -Destination (Join-Path $stage 'licenses/PROJECT-MIT.txt')
Copy-Item -LiteralPath $headerLicense -Destination (Join-Path $stage 'licenses/DIRECTSTORAGE-HEADERS-MIT.txt')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archivePath = Join-Path $dist 'RE8DirectStorage-1.4-Compatibility.zip'
$temporaryZip = Join-Path $dist ('RE8DirectStorage-1.4-Compatibility-' + [Guid]::NewGuid().ToString('N') + '.tmp')
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $temporaryZip, [IO.Compression.CompressionLevel]::Optimal, $false)
$archive = [IO.Compression.ZipFile]::OpenRead($temporaryZip)
try {
    $expected = @('README.md','bin/RE8DirectStorageProbe.exe','tools/RE8DirectStorage.Setup.ps1','licenses/PROJECT-MIT.txt','licenses/DIRECTSTORAGE-HEADERS-MIT.txt')
    $actual = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
    if ($actual.Count -ne $expected.Count -or @(Compare-Object $expected $actual).Count -ne 0) { throw 'Unexpected compatibility ZIP contents.' }
} finally { $archive.Dispose() }
if (Test-Path -LiteralPath $archivePath) {
    $previous = Join-Path $dist ('RE8DirectStorage-previous-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::Replace($temporaryZip, $archivePath, $previous)
    Remove-Item -LiteralPath $previous
}
else { [IO.File]::Move($temporaryZip, $archivePath) }
$checksum = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash + '  RE8DirectStorage-1.4-Compatibility.zip' + [Environment]::NewLine
[IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS-DirectStorage-Compatibility.txt'), $checksum, (New-Object Text.UTF8Encoding($false)))
Write-Output $archivePath
Write-Output $checksum.Trim()
Write-Output "Staging folder (no Microsoft runtime DLLs): $stage"
