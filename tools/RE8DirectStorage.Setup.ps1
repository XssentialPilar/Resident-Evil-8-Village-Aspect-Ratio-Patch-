[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PackagePath, [string]$KitRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $KitRoot) { $KitRoot = Split-Path -Parent $PSScriptRoot }
$KitRoot = [IO.Path]::GetFullPath($KitRoot)
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
if ((Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash -ne '5E0EC8178EDD0F5B6EDABA8EC89D3540DC2AE17A9D2DD70E5737ADAC3F50C590') {
    throw 'The local NuGet package does not match the reviewed DirectStorage preview.'
}
$bin = Join-Path $KitRoot 'bin'
if (-not (Test-Path -LiteralPath (Join-Path $bin 'RE8DirectStorageProbe.exe') -PathType Leaf)) {
    throw 'KitRoot must contain this standalone kit and its bin/RE8DirectStorageProbe.exe.'
}
for ($current = Get-Item -LiteralPath $bin; $null -ne $current; $current = $current.Parent) {
    if (($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse-point kit paths are not supported.' }
    if (Test-Path -LiteralPath (Join-Path $current.FullName 're8.exe')) { throw 'Install the compatibility kit outside the RE8 directory.' }
}
$expected = @{
    'dstorage.dll' = '4AE887A8CD21DB2CFECD97C34B5F4DA48D8370D4646F3853D60DB809AA02A8BF'
    'dstoragecore.dll' = 'C6A160899D2C607E1547476B210E36B1CE059A78FEB6DC027A2A0CF4A6F22B78'
}
function Assert-PrivateRuntime([string]$Path, [string]$Name) {
    if (((Get-Item -LiteralPath $Path).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Runtime reparse points are not supported: $Name" }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $expected[$Name]) { throw "Unexpected hash: $Name" }
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(^|, )CN=Microsoft Corporation(,|$)') {
        throw "A valid Microsoft signature is required: $Name"
    }
}
# Preserve all existing files. Reusing an exact, signed copy is idempotent;
# other files with these names are never replaced.
foreach ($name in $expected.Keys) {
    $target = Join-Path $bin $name
    if (Test-Path -LiteralPath $target) { Assert-PrivateRuntime $target $name }
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$temporary = Join-Path $bin ('.directstorage-setup-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
$archive = $null
$created = New-Object 'System.Collections.Generic.List[string]'
try {
    $archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
    foreach ($name in $expected.Keys) {
        $entry = @($archive.Entries | Where-Object FullName -eq "native/bin/x64/$name")
        if ($entry.Count -ne 1) { throw "Expected exactly one package entry for $name" }
        $staged = Join-Path $temporary $name
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry[0], $staged, $false)
        Assert-PrivateRuntime $staged $name
    }
    foreach ($name in @('LICENSE.txt','LICENSE-CODE.txt','NOTICES.txt','README.md')) {
        $entry = @($archive.Entries | Where-Object FullName -eq $name)
        if ($entry.Count -ne 1) { throw "Missing original package document: $name" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry[0], (Join-Path $temporary $name), $false)
    }
    $archive.Dispose(); $archive = $null
    $privateDocs = Join-Path $bin 'directstorage-preview-private-terms'
    if (Test-Path -LiteralPath $privateDocs) { throw 'Private terms directory already exists; keep it or use a fresh kit folder.' }
    New-Item -ItemType Directory -Path $privateDocs | Out-Null
    $created.Add($privateDocs)
    foreach ($name in @('LICENSE.txt','LICENSE-CODE.txt','NOTICES.txt','README.md')) {
        [IO.File]::Move((Join-Path $temporary $name), (Join-Path $privateDocs $name))
    }
    foreach ($name in $expected.Keys) {
        $target = Join-Path $bin $name
        if (-not (Test-Path -LiteralPath $target)) {
            [IO.File]::Move((Join-Path $temporary $name), $target)
            $created.Add($target)
        }
    }
    Write-Output 'Private preview files prepared for this isolated compatibility test.'
    Write-Output "Read the original terms in $privateDocs. Preview binary redistribution and production use are not granted by this kit."
    Write-Output 'No runtime was loaded. To test explicitly, run bin/RE8DirectStorageProbe.exe --probe.'
} catch {
    foreach ($createdPath in $created) {
        $absolute = [IO.Path]::GetFullPath($createdPath)
        if (-not $absolute.StartsWith($bin + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Rollback path outside kit bin.' }
        if (Test-Path -LiteralPath $absolute -PathType Container) { Remove-Item -LiteralPath $absolute -Recurse -Force }
        elseif (Test-Path -LiteralPath $absolute) { Remove-Item -LiteralPath $absolute -Force }
    }
    throw
} finally {
    if ($null -ne $archive) { $archive.Dispose() }
    $absolute = [IO.Path]::GetFullPath($temporary)
    if (-not $absolute.StartsWith($bin + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Temporary path outside kit bin.' }
    if (Test-Path -LiteralPath $absolute) { Remove-Item -LiteralPath $absolute -Recurse -Force }
}
