[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GamePath,[Parameter(Mandatory=$true)][string]$PackagePath,[switch]$AcceptPreviewLicense,[string]$PackageRoot)
if (-not $PackageRoot) { $PackageRoot=$PSScriptRoot }
. (Join-Path $PSScriptRoot 'common.ps1')
$GamePath=[IO.Path]::GetFullPath($GamePath)
$PackageRoot=[IO.Path]::GetFullPath($PackageRoot)
Assert-TechStopped $GamePath
$package=Read-TechPackage $PackageRoot
$definition=Get-TechDefinition $package.technology
if (-not $AcceptPreviewLicense) { throw 'Read the original Microsoft preview license. For a private development test, rerun with -AcceptPreviewLicense after accepting its terms. Preview runtimes are not redistributed by this ZIP.' }
if ((Get-TechHash $PackagePath) -ne $definition.PackageHash) { throw 'Wrong original Microsoft preview package.' }
if ($definition.Name -eq 'DirectStorage' -and -not (Test-Path -LiteralPath (Get-TechPath $GamePath 'dinput8.dll') -PathType Leaf)) { throw 'DirectStorage bridge requires an existing REFramework host with plugin API 1.15 or newer.' }
$manifest=Get-TechPath $GamePath ('.RE8Technologies\'+$definition.Name+'\install-manifest.json')
if (Test-Path -LiteralPath $manifest) { throw 'An existing installation/recovery transaction must be removed first.' }
$relativeTargets=@($definition.Target)+@($definition.Runtime | ForEach-Object Target)+@($definition.Folder+'\LICENSE-preview.txt')
if($definition.Name -eq 'DirectStorage'){$relativeTargets+=($definition.Folder+'\NOTICES-preview.txt')}
foreach($relative in $relativeTargets) {
    if (Test-Path -LiteralPath (Get-TechPath $GamePath $relative)) { throw "An existing file would be overwritten: $relative. No game files changed." }
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$temporaryRoot=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('RE8Technology-'+[Guid]::NewGuid().ToString('N'))))
$temporaryParent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
if (-not $temporaryRoot.StartsWith($temporaryParent,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected staging path.' }
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
$archive=$null
$actions=@()
$state=$null
try {
    $archive=[IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($PackagePath))
    foreach($runtime in $definition.Runtime) {
        $entry=$archive.GetEntry($runtime.Entry)
        if (-not $entry) { throw 'Exact runtime entry missing.' }
        $staged=Get-TechPath $temporaryRoot ([IO.Path]::GetFileName($runtime.Target))
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$staged)
        if ((Get-TechHash $staged) -ne $runtime.Hash) { throw 'Runtime checksum mismatch.' }
        $signature=Get-AuthenticodeSignature -LiteralPath $staged
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(^|, )CN=Microsoft Corporation(,|$)') { throw 'A valid Microsoft runtime signature is required.' }
        $actions += [pscustomobject]@{source=$staged;relative=$runtime.Target;sha256=$runtime.Hash;applied=$false}
    }
    $license=$archive.GetEntry('LICENSE.txt')
    if (-not $license) { throw 'Original preview license missing.' }
    $licensePath=Get-TechPath $temporaryRoot 'LICENSE-preview.txt'
    [IO.Compression.ZipFileExtensions]::ExtractToFile($license,$licensePath)
    $actions += [pscustomobject]@{source=$licensePath;relative=($definition.Folder+'\LICENSE-preview.txt');sha256=(Get-TechHash $licensePath);applied=$false}
    if($definition.Name -eq 'DirectStorage') {
        $notices=$archive.GetEntry('NOTICES.txt')
        if(-not $notices){throw 'Original runtime notices missing.'}
        $noticesPath=Get-TechPath $temporaryRoot 'NOTICES-preview.txt'
        [IO.Compression.ZipFileExtensions]::ExtractToFile($notices,$noticesPath)
        $actions += [pscustomobject]@{source=$noticesPath;relative=($definition.Folder+'\NOTICES-preview.txt');sha256=(Get-TechHash $noticesPath);applied=$false}
    }
    $actions += [pscustomobject]@{source=(Get-TechPath $PackageRoot $package.binary);relative=$definition.Target;sha256=$package.binarySha256;applied=$false}
    $archive.Dispose();$archive=$null
    Assert-TechStopped $GamePath
    $state=[ordered]@{schema=1;technology=$definition.Name;version='1.0.0';status='prepared';files=@($actions | ForEach-Object {[ordered]@{relative=$_.relative;sha256=$_.sha256;applied=$false}})}
    Write-TechJson $manifest $state
    for($index=0;$index -lt $actions.Count;$index++) {
        $action=$actions[$index]
        $target=Get-TechPath $GamePath $action.relative
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        # No overwrite: a concurrently created foreign file aborts the transaction.
        [IO.File]::Copy($action.source,$target,$false)
        $action.applied=$true;$state.files[$index].applied=$true
        Write-TechJson $manifest $state
    }
    $state.status='installed';Write-TechJson $manifest $state
    Write-Output ($definition.Name+' bridge installed for private preview testing. Its log must confirm activation; no system DLL was replaced.')
} catch {
    foreach($action in $actions) {
        if (-not $action.applied) { continue }
        $target=Get-TechPath $GamePath $action.relative
        if ((Test-Path -LiteralPath $target -PathType Leaf) -and (Get-TechHash $target) -eq $action.sha256) { Remove-Item -LiteralPath $target -Force }
    }
    if ($state) { $state.status='rolled-back';Write-TechJson $manifest $state }
    throw
} finally {
    if ($archive) { $archive.Dispose() }
    if ([IO.Path]::GetFullPath($temporaryRoot).StartsWith($temporaryParent,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $temporaryRoot)) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
}
