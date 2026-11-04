[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GamePath)
. (Join-Path $PSScriptRoot 'RE8Display.Common.ps1')
$GamePath = [IO.Path]::GetFullPath($GamePath)
Assert-RE8GameStopped $GamePath
$manifest = Get-RE8ContainedPath $GamePath '.RE8Display\install-manifest.json'
if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { throw 'No RE8Display installation manifest; ownership will not be guessed.' }
$state = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
if ($state.schema -ne 2 -or $state.version -notin @('2.1.0','2.5.0','2.7.0') -or $state.transaction -notmatch '^[a-f0-9]{32}$' -or $state.status -notin @('installed','prepared','rolled-back')) { throw 'Invalid RE8Display recovery manifest.' }
$owned = @('reframework\plugins\RE8Display.dll','reframework\data\RE8Display.ini')
$retired = @('reframework\autorun\re8_aspect_ratio_fix.lua','reframework\autorun\re8_display.lua')
$seen = @{}
$plans = @()
foreach ($action in @($state.actions)) {
    $relative = [string]$action.relative
    if ($seen.ContainsKey($relative) -or ($relative -notin ($owned + $retired)) -or ([bool]$action.removeOnly -ne ($relative -in $retired))) { throw 'Manifest contains an unowned or duplicate path.' }
    $seen[$relative] = $true
    $target = Get-RE8ContainedPath $GamePath $relative
    $backup = $null
    if ($action.backup) {
        $expected = '.RE8Display\backups\' + $state.transaction + '\' + $relative
        if ($action.backup -ne $expected -or $action.previousHash -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid backup record.' }
        $backup = Get-RE8ContainedPath $GamePath $expected
        if ((Get-RE8Hash $backup) -ne $action.previousHash) { throw 'Backup checksum mismatch; no files changed.' }
    } elseif ($action.previousHash) { throw 'Missing backup record.' }
    if (-not $action.applied) { continue }
    $preserve = $relative -eq 'reframework\data\RE8Display.ini'
    $exists = Test-Path -LiteralPath $target -PathType Leaf
    $alreadyRestored = $false
    if ($exists) {
        $hash = Get-RE8Hash $target
        $alreadyRestored = $action.previousHash -and $hash -eq $action.previousHash
        if ($action.removeOnly -and -not $alreadyRestored) { throw "An old script path was recreated; refusing to overwrite it: $relative" }
        if (-not $action.removeOnly -and -not $alreadyRestored -and $hash -ne $action.installedHash) {
            if ($preserve) { continue }
            throw "Installed plugin changed; no files changed: $relative"
        }
    }
    if (-not $alreadyRestored) { $plans += [pscustomobject]@{target=$target;backup=$backup;exists=$exists} }
}
foreach ($plan in $plans) {
    if ($plan.backup) {
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($plan.target)) | Out-Null
        Copy-Item -LiteralPath $plan.backup -Destination $plan.target -Force
    } elseif ($plan.exists) { Remove-Item -LiteralPath $plan.target -Force }
}
Remove-Item -LiteralPath $manifest -Force
Write-Output 'RE8Display removed. Loader, shared settings, other mods, modified personal configuration, and recovery backups were preserved.'
