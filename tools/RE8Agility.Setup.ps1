[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PackagePath, [switch]$AcceptPreviewLicense)
$ErrorActionPreference = 'Stop'
$expectedPackage = 'BF9915DBB39F7C97018D42B36E65469F11C864B805E3BC9A773EBA364208CDC3'
$expectedCore = '1A588965B12422DB5DF18F9331E244616F4F7A3893DB83A4C578F7DE50A36F13'
$kitRoot = [IO.Path]::GetFullPath($PSScriptRoot)
if (-not (Test-Path -LiteralPath (Join-Path $kitRoot 'RE8AgilityProbe.exe') -PathType Leaf)) { throw 'Run setup.ps1 from the extracted compatibility kit.' }
for ($candidate = $kitRoot; $candidate; $candidate = Split-Path -Parent $candidate) {
    if (Test-Path -LiteralPath (Join-Path $candidate 're8.exe')) { throw 'Keep this diagnostic kit separate from the game directory.' }
    if ((Get-Item -LiteralPath $candidate -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'The kit path must not traverse a symbolic link or junction.' }
}
$PackagePath = [IO.Path]::GetFullPath($PackagePath)
if ((Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash -ne $expectedPackage) { throw 'The original SDK 1.722.0-preview package checksum does not match. Nothing extracted.' }
$runtimeRoot = Join-Path $kitRoot 'D3D12'
foreach ($candidate in @($kitRoot,$runtimeRoot)) {
    if ((Test-Path -LiteralPath $candidate) -and ((Get-Item -LiteralPath $candidate -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'The kit/runtime directory must not be a symbolic link or junction.' }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
$temporary = $null
try {
    $licenseEntry = $archive.GetEntry('LICENSE.txt')
    $coreEntry = $archive.GetEntry('build/native/bin/x64/D3D12Core.dll')
    if (-not $licenseEntry -or -not $coreEntry) { throw 'Missing exact runtime/license entry.' }
    $reader = New-Object IO.StreamReader($licenseEntry.Open())
    try { $licenseText = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $licensePath = Join-Path $kitRoot 'Microsoft-Preview-License.local.txt'
    if (Test-Path -LiteralPath $licensePath) {
        if (-not (Test-Path -LiteralPath $licensePath -PathType Leaf) -or ((Get-Item -LiteralPath $licensePath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -or [IO.File]::ReadAllText($licensePath) -ne $licenseText) { throw 'An unrelated local license file exists; no replacement performed.' }
    } else { [IO.File]::WriteAllText($licensePath,$licenseText,(New-Object Text.UTF8Encoding($false))) }
    if (-not $AcceptPreviewLicense) {
        Write-Output "Read the original runtime license copied to: $licensePath"
        throw 'No runtime extracted. After reading and accepting the preview terms, rerun with -AcceptPreviewLicense for local use.'
    }
    [IO.Directory]::CreateDirectory($runtimeRoot) | Out-Null
    $target = Join-Path $runtimeRoot 'D3D12Core.dll'
    if (Test-Path -LiteralPath $target) {
        if ((Get-Item -LiteralPath $target -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Runtime target is a symbolic link.' }
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $expectedCore) { throw 'Another runtime already exists. No replacement performed.' }
        Write-Output 'The exact SDK 722 runtime is already staged locally. No device created.'
        return
    }
    $temporary = Join-Path $runtimeRoot ('D3D12Core-' + [Guid]::NewGuid().ToString('N') + '.dll')
    [IO.Compression.ZipFileExtensions]::ExtractToFile($coreEntry,$temporary)
    if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $expectedCore) { throw 'Extracted core checksum mismatch.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $temporary
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne '1D77A9B9E8FE2075D9AD15123257FB90DB0DA4A1') { throw 'The exact Microsoft runtime Authenticode signature did not validate.' }
    Move-Item -LiteralPath $temporary -Destination $target
    $temporary = $null
    Write-Output "SDK 722 core staged for local diagnostic use only: $target"
    Write-Output 'No device created and no game files changed. Run RE8AgilityProbe.exe when ready to test.'
} finally {
    $archive.Dispose()
    if ($temporary -and (Test-Path -LiteralPath $temporary)) { Remove-Item -LiteralPath $temporary -Force }
}
