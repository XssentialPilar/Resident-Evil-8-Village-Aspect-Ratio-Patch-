[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GamePath, [string]$PackageRoot)
if (-not $PackageRoot) { $PackageRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'RE8Display.Common.ps1')
$GamePath = [IO.Path]::GetFullPath($GamePath)
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
Assert-RE8GameStopped $GamePath
if (-not (Test-Path -LiteralPath (Join-Path $GamePath 'dinput8.dll') -PathType Leaf)) { throw 'Install REFramework with plugin API 1.15 or newer first. This mod does not replace its loader.' }
$legacyManifest = Get-RE8ContainedPath $GamePath '.RE8VillagePatch\install-manifest.json'
if (Test-Path -LiteralPath $legacyManifest) { throw 'Remove the older bundled patch using its uninstaller before installing the independent plugin; keep its backups.' }
$manifest = Get-RE8ContainedPath $GamePath '.RE8Display\install-manifest.json'
if (Test-Path -LiteralPath $manifest) { throw 'An installation or recovery transaction exists. Uninstall RE8Display first.' }
$payload = Get-Content -LiteralPath (Join-Path $PackageRoot 'runtime-files.json') -Raw | ConvertFrom-Json
if ($payload.schema -ne 2 -or $payload.version -ne '2.5.0' -or $payload.format -ne 'reframework-plugin') { throw 'Unsupported plugin package manifest.' }
$allowed = @('reframework\plugins\RE8Display.dll', 'reframework\data\RE8Display.ini')
$files = @($payload.files)
if ($files.Count -ne $allowed.Count) { throw 'Unexpected plugin payload size.' }
$seen = @{}
$actions = @()
$transaction = [Guid]::NewGuid().ToString('N')
foreach ($file in $files) {
    $relative = [string]$file.destination
    if ($relative -notin $allowed -or $file.source -ne $relative -or $seen.ContainsKey($relative)) { throw 'Payload may only install the two owned plugin files.' }
    $seen[$relative] = $true
    $source = Get-RE8ContainedPath $PackageRoot $relative
    $target = Get-RE8ContainedPath $GamePath $relative
    if ($source -eq $target) { throw 'Package and game must be separate.' }
    if ((Get-RE8Hash $source) -ne $file.sha256) { throw "Package checksum mismatch: $relative" }
    $preserve = $relative -eq 'reframework\data\RE8Display.ini'
    if ($preserve -and (Test-Path -LiteralPath $target -PathType Leaf)) { continue }
    if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $target -PathType Leaf)) { throw 'Payload target is not a regular file.' }
    $actions += [pscustomobject]@{ relative=$relative; source=$source; installedHash=[string]$file.sha256; previousHash=$null; backup=$null; removeOnly=$false; preserveChanged=$preserve; applied=$false }
}
# Retire only this patch's old autorun scripts. All other mods are outside ownership.
foreach ($relative in @('reframework\autorun\re8_aspect_ratio_fix.lua','reframework\autorun\re8_display.lua')) {
    $target = Get-RE8ContainedPath $GamePath $relative
    if (Test-Path -LiteralPath $target -PathType Leaf) { $actions += [pscustomobject]@{relative=$relative;source=$null;installedHash=$null;previousHash=$null;backup=$null;removeOnly=$true;preserveChanged=$false;applied=$false} }
}
foreach ($action in $actions) {
    $target = Get-RE8ContainedPath $GamePath $action.relative
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $action.previousHash = Get-RE8Hash $target
        $action.backup = '.RE8Display\backups\' + $transaction + '\' + $action.relative
        $backup = Get-RE8ContainedPath $GamePath $action.backup
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($backup)) | Out-Null
        Copy-Item -LiteralPath $target -Destination $backup
        if ((Get-RE8Hash $backup) -ne $action.previousHash) { throw 'Backup verification failed.' }
    }
}
$state = [pscustomobject]@{schema=2;version='2.5.0';status='prepared';transaction=$transaction;actions=$actions}
Write-RE8Json $manifest $state
try {
    foreach ($action in $actions) {
        $target = Get-RE8ContainedPath $GamePath $action.relative
        $action.applied = $true
        Write-RE8Json $manifest $state
        if ($action.removeOnly) { Remove-Item -LiteralPath $target -Force }
        else {
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
            Copy-Item -LiteralPath $action.source -Destination $target -Force
            if ((Get-RE8Hash $target) -ne $action.installedHash) { throw 'Installed checksum mismatch.' }
        }
    }
    $state.status = 'installed'
    Write-RE8Json $manifest $state
    Write-Output 'RE8Display 2.5.0 installed. REFramework loader, shared settings, and other mods were preserved.'
} catch {
    $failure = $_
    foreach ($action in @($actions | Where-Object applied)) {
        $target = Get-RE8ContainedPath $GamePath $action.relative
        if ($action.backup) { Copy-Item -LiteralPath (Get-RE8ContainedPath $GamePath $action.backup) -Destination $target -Force }
        elseif (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force }
    }
    $state.status = 'rolled-back'
    Write-RE8Json $manifest $state
    throw $failure
}
