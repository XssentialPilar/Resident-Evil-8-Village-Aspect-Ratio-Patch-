[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GamePath,[string]$PackageRoot)
if (-not $PackageRoot) { $PackageRoot=$PSScriptRoot }
. (Join-Path $PSScriptRoot 'common.ps1')
$GamePath=[IO.Path]::GetFullPath($GamePath)
Assert-TechStopped $GamePath
$package=Read-TechPackage ([IO.Path]::GetFullPath($PackageRoot))
$definition=Get-TechDefinition $package.technology
$manifest=Get-TechPath $GamePath ('.RE8Technologies\'+$definition.Name+'\install-manifest.json')
$state=Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
if ($state.schema -ne 1 -or $state.technology -ne $definition.Name -or $state.status -notin @('prepared','installed','rolled-back')) { throw 'Invalid ownership manifest.' }
$allowed=@($definition.Target)+@($definition.Runtime | ForEach-Object Target)+@($definition.Folder+'\LICENSE-preview.txt')
if($definition.Name -eq 'DirectStorage'){$allowed+=($definition.Folder+'\NOTICES-preview.txt')}
if (@($state.files).Count -ne $allowed.Count) { throw 'Incomplete ownership manifest; nothing removed.' }
$seen=@{};$plans=@()
foreach($file in @($state.files)) {
    if ($file.relative -notin $allowed -or $seen.ContainsKey($file.relative) -or $file.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Manifest contains an unowned or duplicate file.' }
    $seen[$file.relative]=$true
    $target=Get-TechPath $GamePath $file.relative
    if (-not $file.applied -or -not (Test-Path -LiteralPath $target)) { continue }
    if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or (Get-TechHash $target) -ne $file.sha256) { throw "Installed file changed; nothing removed: $($file.relative)" }
    $plans += $target
}
foreach($target in $plans) { Remove-Item -LiteralPath $target -Force }
Remove-Item -LiteralPath $manifest -Force
Write-Output ($definition.Name+' module removed. Logs, other mods, RE8Display, game files and Windows runtimes were preserved.')
