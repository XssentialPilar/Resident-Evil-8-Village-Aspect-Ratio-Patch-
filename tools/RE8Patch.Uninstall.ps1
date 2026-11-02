[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$GamePath)
. (Join-Path $PSScriptRoot 'RE8Patch.Common.ps1')
$GamePath = [IO.Path]::GetFullPath($GamePath)
Assert-RE8GameStopped $GamePath
$manifestPath = Get-RE8ContainedPath $GamePath '.RE8VillagePatch\install-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'No patch installation manifest. No game files were removed.' }
$state = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($state.schema -ne 1) { throw 'Unsupported installation manifest.' }
if ($state.status -eq 'rolled-back') {
    Remove-Item -LiteralPath $manifestPath
    Write-Output 'Rolled-back transaction cleared; backups retained.'
    return
}
$retained = @{}
# Validate ALL files before changing any. A later user/mod edit must be preserved.
foreach ($action in @($state.actions | Where-Object applied)) {
    $target = Get-RE8ContainedPath $GamePath $action.relative
    if ($action.removeOnly) {
        if (Test-Path -LiteralPath $target) { throw "Retired file was recreated; preserved: $target" }
    } elseif (-not (Test-Path -LiteralPath $target -PathType Leaf) -or (Get-RE8Hash $target) -ne $action.installedHash) {
        if ($action.preserveChanged) { $retained[$target] = $true; continue }
        throw "Installed file changed or is missing; no files removed: $target"
    }
    if ($action.backup) {
        $backup = Get-RE8ContainedPath $GamePath $action.backup
        if ((Get-RE8Hash $backup) -ne $action.previousHash) { throw 'Backup changed; refusing restoration.' }
    }
}
foreach ($action in @($state.actions | Where-Object applied)) {
    $target = Get-RE8ContainedPath $GamePath $action.relative
    if ($retained.ContainsKey($target)) { Write-Output "User configuration retained: $target"; continue }
    if ($action.backup) { Copy-Item -LiteralPath (Get-RE8ContainedPath $GamePath $action.backup) -Destination $target -Force }
    elseif (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force }
}
Remove-Item -LiteralPath $manifestPath
Write-Output 'Patch files removed and prior files restored. Backups retained in .RE8VillagePatch; other mods were preserved.'
