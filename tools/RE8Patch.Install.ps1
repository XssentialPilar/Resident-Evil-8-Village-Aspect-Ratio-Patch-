[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GamePath,
    [string]$PackageRoot
)
if (-not $PackageRoot) { $PackageRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'RE8Patch.Common.ps1')
$GamePath = [IO.Path]::GetFullPath($GamePath)
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
Assert-RE8GameStopped $GamePath
$manifestPath = Get-RE8ContainedPath $GamePath '.RE8VillagePatch\install-manifest.json'
if (Test-Path -LiteralPath $manifestPath) { throw 'An installation or interrupted transaction exists. Run RE8Patch.Uninstall.ps1 first.' }
$payloadPath = Join-Path $PackageRoot 'runtime-files.json'
if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) { throw 'This is a source checkout. Build and package a development candidate first with tools/RE8Patch.Package.ps1.' }
$payload = Get-Content -LiteralPath $payloadPath -Raw | ConvertFrom-Json
if ($payload.schema -ne 1 -or $payload.status -ne 'development-candidate-unverified-in-game') { throw 'Unsupported package manifest.' }
$transaction = [Guid]::NewGuid().ToString('N')
$actions = @()
$seen = @{}
foreach ($file in $payload.files) {
    $source = Get-RE8ContainedPath $PackageRoot $file.source
    $target = Get-RE8ContainedPath $GamePath $file.destination
    if ($source -eq $target) { throw 'Package and game files must be separate.' }
    if ($seen.ContainsKey($target)) { throw 'Duplicate payload destination.' }
    $seen[$target] = $true
    if ((Get-RE8Hash $source) -ne $file.sha256) { throw "Package checksum mismatch: $($file.source)" }
    if ($file.preserveExisting -and (Test-Path -LiteralPath $target -PathType Leaf)) { continue }
    if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Destination is not a file: $target" }
    $actions += [pscustomobject]@{ relative = $file.destination; source = $source; installedHash = $file.sha256; previousHash = $null; backup = $null; removeOnly = $false; preserveChanged = [bool]$file.preserveExisting; applied = $false }
}
# Retire exactly the old patch Lua so both autorun scripts cannot run together.
$legacy = 'reframework\autorun\re8_aspect_ratio_fix.lua'
$legacyPath = Get-RE8ContainedPath $GamePath $legacy
if ((Test-Path -LiteralPath $legacyPath -PathType Leaf) -and -not $seen.ContainsKey($legacyPath)) {
    $actions += [pscustomobject]@{ relative = $legacy; source = $null; installedHash = $null; previousHash = $null; backup = $null; removeOnly = $true; preserveChanged = $false; applied = $false }
}
# Prepare every backup before modifying any target file.
foreach ($action in $actions) {
    $target = Get-RE8ContainedPath $GamePath $action.relative
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $action.previousHash = Get-RE8Hash $target
        $action.backup = '.RE8VillagePatch\backups\' + $transaction + '\' + $action.relative
        $backup = Get-RE8ContainedPath $GamePath $action.backup
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($backup)) | Out-Null
        Copy-Item -LiteralPath $target -Destination $backup
        if ((Get-RE8Hash $backup) -ne $action.previousHash) { throw 'Backup verification failed.' }
    }
}
$state = [pscustomobject]@{ schema = 1; status = 'prepared'; transaction = $transaction; actions = $actions }
Write-RE8Json $manifestPath $state
try {
    foreach ($action in $actions) {
        $target = Get-RE8ContainedPath $GamePath $action.relative
        # Mark the action before mutation so a failure during copy can be recovered.
        $action.applied = $true
        Write-RE8Json $manifestPath $state
        if ($action.removeOnly) { Remove-Item -LiteralPath $target -Force }
        else {
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
            Copy-Item -LiteralPath $action.source -Destination $target -Force
            if ((Get-RE8Hash $target) -ne $action.installedHash) { throw 'Installed checksum mismatch.' }
        }
    }
    $state.status = 'installed'
    Write-RE8Json $manifestPath $state
    Write-Output 'Development candidate installed. In-game cursor, map and aspect verification remains pending.'
} catch {
    $failure = $_
    foreach ($action in @($actions | Where-Object applied)) {
        $target = Get-RE8ContainedPath $GamePath $action.relative
        if ($action.backup) { Copy-Item -LiteralPath (Get-RE8ContainedPath $GamePath $action.backup) -Destination $target -Force }
        elseif (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force }
    }
    $state.status = 'rolled-back'
    Write-RE8Json $manifestPath $state
    throw $failure
}
