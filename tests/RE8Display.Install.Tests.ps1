[CmdletBinding()]
param([string]$ProjectRoot)
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $ProjectRoot 'tools\RE8Display.Common.ps1')
$fixture = Get-RE8ContainedPath $ProjectRoot ('artifacts\tests\plugin-installer-' + [Guid]::NewGuid().ToString('N'))
$package = Join-Path $fixture 'package space !'
$game = Join-Path $fixture 'game space !'
$script:checks = 0
function Assert([bool]$condition,[string]$message) { if (-not $condition) { throw "FAIL: $message" }; $script:checks++ }
function Throws([scriptblock]$action,[string]$message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Assert $failed $message }
function Put([string]$root,[string]$relative,[string]$value) { $path=Get-RE8ContainedPath $root $relative; [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))|Out-Null; [IO.File]::WriteAllText($path,$value) }
function Read([string]$relative) { Get-Content -LiteralPath (Join-Path $game $relative) -Raw }
Put $game 're8.exe' 'non-executable fixture'
Put $game 'dinput8.dll' 'existing framework loader'
Put $game 're2_fw_config.txt' 'existing shared settings'
Put $game 'reframework\plugins\OtherMod.dll' 'unrelated plugin'
Put $game 'reframework\autorun\OtherMod.lua' 'unrelated script'
Put $game 'reframework\autorun\re8_aspect_ratio_fix.lua' 'legacy patch'
Put $game 'reframework\plugins\RE8Display.dll' 'previous own plugin'
Put $package 'reframework\plugins\RE8Display.dll' 'new own plugin fixture'
Put $package 'reframework\data\RE8Display.ini' 'Enabled=1'
$files = @('reframework\plugins\RE8Display.dll','reframework\data\RE8Display.ini') | ForEach-Object { [ordered]@{source=$_;destination=$_;sha256=Get-RE8Hash (Join-Path $package $_)} }
function Payload { Write-RE8Json (Join-Path $package 'runtime-files.json') ([ordered]@{schema=2;version='2.1.0';format='reframework-plugin';files=@($files)}) }
Payload
$install=Join-Path $ProjectRoot 'tools\RE8Display.Install.ps1'
$uninstall=Join-Path $ProjectRoot 'tools\RE8Display.Uninstall.ps1'
& $install -GamePath $game -PackageRoot $package | Out-Null
Assert ((Read 'reframework\plugins\RE8Display.dll') -eq 'new own plugin fixture') 'Own DLL installed'
Assert ((Read 'dinput8.dll') -eq 'existing framework loader') 'Framework loader untouched'
Assert ((Read 're2_fw_config.txt') -eq 'existing shared settings') 'Shared settings untouched'
Assert ((Read 'reframework\plugins\OtherMod.dll') -eq 'unrelated plugin') 'Other DLL untouched'
Assert ((Read 'reframework\autorun\OtherMod.lua') -eq 'unrelated script') 'Other Lua untouched'
Assert (-not (Test-Path -LiteralPath (Join-Path $game 'reframework\autorun\re8_aspect_ratio_fix.lua'))) 'Legacy own Lua retired'
Throws { & $install -GamePath $game -PackageRoot $package } 'Repeated installation rejected'
Put $game 'reframework\plugins\RE8Display.dll' 'changed by another tool'
Throws { & $uninstall -GamePath $game } 'Modified DLL refuses all uninstall changes'
Assert ((Read 'reframework\data\RE8Display.ini') -eq 'Enabled=1') 'Failed uninstall preserves remaining files'
Put $game 'reframework\plugins\RE8Display.dll' 'new own plugin fixture'
Put $game 'reframework\data\RE8Display.ini' 'ManualFOV=1'
& $uninstall -GamePath $game | Out-Null
Assert ((Read 'reframework\plugins\RE8Display.dll') -eq 'previous own plugin') 'Previous own DLL restored'
Assert ((Read 'reframework\data\RE8Display.ini') -eq 'ManualFOV=1') 'Personal plugin config retained'
Assert ((Read 'reframework\autorun\re8_aspect_ratio_fix.lua') -eq 'legacy patch') 'Retired Lua restored'
Throws { & $uninstall -GamePath $game } 'No manifest refuses ownership guesses'
& $install -GamePath $game -PackageRoot $package | Out-Null
Assert ((Read 'reframework\data\RE8Display.ini') -eq 'ManualFOV=1') 'Existing plugin config preserved on install'
& $uninstall -GamePath $game | Out-Null
# Malicious or corrupted package must never gain ownership of another mod/loader.
$files[0].destination='dinput8.dll'; Payload
Throws { & $install -GamePath $game -PackageRoot $package } 'Shared loader destination rejected'
$files[0].destination='..\outside.dll'; Payload
Throws { & $install -GamePath $game -PackageRoot $package } 'Traversal rejected'
$files[0].destination='reframework\plugins\RE8Display.dll'; Payload
Put $package 'reframework\plugins\RE8Display.dll' 'corrupt'
Throws { & $install -GamePath $game -PackageRoot $package } 'Corrupt DLL rejected'
Assert ((Read 'dinput8.dll') -eq 'existing framework loader') 'Failed package never changes loader'
Put $package 'reframework\plugins\RE8Display.dll' 'new own plugin fixture'
Throws { Get-RE8ContainedPath $game 'file.dll:stream' } 'Alternate data stream rejected'
Throws { Get-RE8ContainedPath $game 'C:\outside.dll' } 'Absolute path rejected'
Put $game '.RE8VillagePatch\install-manifest.json' '{}'
Throws { & $install -GamePath $game -PackageRoot $package } 'Active old bundled installation rejected'
Remove-Item -LiteralPath (Join-Path $game '.RE8VillagePatch\install-manifest.json')
# Rollback occurs after a real first-file copy and an injected second copy failure.
Remove-Item -LiteralPath (Join-Path $game 'reframework\data\RE8Display.ini')
$global:RE8DisplayFailConfig=$true
function Copy-Item {
    param([string]$LiteralPath,[string]$Destination,[switch]$Force)
    if ($global:RE8DisplayFailConfig -and $LiteralPath -eq (Join-Path $package 'reframework\data\RE8Display.ini')) { $global:RE8DisplayFailConfig=$false; throw 'Injected config copy failure' }
    Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
}
try { Throws { & $install -GamePath $game -PackageRoot $package } 'Failure propagates after DLL copy' }
finally { Remove-Item Function:\Copy-Item; Remove-Variable RE8DisplayFailConfig -Scope Global }
Assert ((Read 'reframework\plugins\RE8Display.dll') -eq 'previous own plugin') 'Rollback restores original own DLL'
Assert ((Read 'dinput8.dll') -eq 'existing framework loader') 'Rollback leaves host untouched'
& $uninstall -GamePath $game | Out-Null
Write-RE8Json (Join-Path $fixture 'result.json') ([ordered]@{status='passed';checks=$script:checks;scope='Filesystem fixtures with fake DLLs; no game compatibility claim'})
Write-Output "PASS: $($script:checks) standalone installation checks. Fixture: $fixture"
