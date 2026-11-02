[CmdletBinding()]
param([string]$ProjectRoot)
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $ProjectRoot 'tools\RE8Patch.Common.ps1')
$fixture = Get-RE8ContainedPath $ProjectRoot ('artifacts\tests\installer-' + [Guid]::NewGuid().ToString('N'))
$package = Join-Path $fixture 'package space !'
$game = Join-Path $fixture 'game space !'
[IO.Directory]::CreateDirectory($package) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $game 'reframework\autorun')) | Out-Null
[IO.File]::WriteAllText((Join-Path $game 're8.exe'), 'fixture only - not executable')
$script:checks = 0
function Assert-RE8Test([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}
function Assert-RE8Throws([scriptblock]$Action, [string]$Message) {
    $thrown = $false
    try { & $Action | Out-Null } catch { $thrown = $true }
    Assert-RE8Test $thrown $Message
}
$spec = @(
    @{ source = 'dinput8.dll'; destination = 'dinput8.dll'; preserveExisting = $false; content = 'new dll' }
    @{ source = 'reframework\autorun\re8_display.lua'; destination = 'reframework\autorun\re8_display.lua'; preserveExisting = $false; content = 'new lua' }
    @{ source = 'reframework\data\re8_display.json'; destination = 'reframework\data\re8_display.json'; preserveExisting = $true; content = '{}' }
    @{ source = 're2_fw_config.txt'; destination = 're2_fw_config.txt'; preserveExisting = $true; content = 'default config' }
)
foreach ($file in $spec) {
    $path = Get-RE8ContainedPath $package $file.source
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
    [IO.File]::WriteAllText($path, $file.content)
}
function Set-RE8TestPayload {
    $files = foreach ($file in $spec) {
        [ordered]@{ source = $file.source; destination = $file.destination; preserveExisting = $file.preserveExisting; sha256 = Get-RE8Hash (Join-Path $package $file.source) }
    }
    Write-RE8Json (Join-Path $package 'runtime-files.json') ([ordered]@{ schema = 1; status = 'development-candidate-unverified-in-game'; files = @($files) })
}
Set-RE8TestPayload
[IO.File]::WriteAllText((Join-Path $game 'dinput8.dll'), 'original dll')
[IO.File]::WriteAllText((Join-Path $game 'reframework\autorun\re8_aspect_ratio_fix.lua'), 'legacy lua')
[IO.File]::WriteAllText((Join-Path $game 'reframework\autorun\unrelated.lua'), 'other mod')
[IO.File]::WriteAllText((Join-Path $game 're2_fw_config.txt'), 'personal config')
$install = Join-Path $ProjectRoot 'tools\RE8Patch.Install.ps1'
$uninstall = Join-Path $ProjectRoot 'tools\RE8Patch.Uninstall.ps1'
& $install -GamePath $game -PackageRoot $package | Out-Null
Assert-RE8Test ((Get-Content -LiteralPath (Join-Path $game 'dinput8.dll') -Raw) -eq 'new dll') 'DLL installed in path with space and !'
Assert-RE8Test (-not (Test-Path -LiteralPath (Join-Path $game 'reframework\autorun\re8_aspect_ratio_fix.lua'))) 'Legacy Lua retired'
Assert-RE8Test ((Get-Content -LiteralPath (Join-Path $game 're2_fw_config.txt') -Raw) -eq 'personal config') 'Existing framework settings preserved'
Assert-RE8Throws { & $install -GamePath $game -PackageRoot $package } 'Repeated install must refuse overwriting original backup'
[IO.File]::WriteAllText((Join-Path $game 'dinput8.dll'), 'changed by other mod')
Assert-RE8Throws { & $uninstall -GamePath $game } 'Changed runtime file must block uninstall'
Assert-RE8Test (Test-Path -LiteralPath (Join-Path $game 'reframework\autorun\re8_display.lua')) 'Refused uninstall leaves all other files intact'
[IO.File]::WriteAllText((Join-Path $game 'dinput8.dll'), 'new dll')
[IO.File]::WriteAllText((Join-Path $game 'reframework\data\re8_display.json'), '{"userSetting":true}')
& $uninstall -GamePath $game | Out-Null
Assert-RE8Test ((Get-Content -LiteralPath (Join-Path $game 'dinput8.dll') -Raw) -eq 'original dll') 'Original DLL restored'
Assert-RE8Test ((Get-Content -LiteralPath (Join-Path $game 'reframework\autorun\re8_aspect_ratio_fix.lua') -Raw) -eq 'legacy lua') 'Legacy Lua restored'
Assert-RE8Test ((Get-Content -LiteralPath (Join-Path $game 'reframework\autorun\unrelated.lua') -Raw) -eq 'other mod') 'Other mod preserved'
Assert-RE8Test ((Get-Content -LiteralPath (Join-Path $game 'reframework\data\re8_display.json') -Raw) -eq '{"userSetting":true}') 'User-modified config preserved'
Assert-RE8Test (-not (Test-Path -LiteralPath (Join-Path $game 'reframework\autorun\re8_display.lua'))) 'New runtime Lua removed'
Assert-RE8Throws { & $uninstall -GamePath $game } 'Uninstall without manifest must refuse guessing ownership'
# An actual Copy-Item failure after the DLL copy must restore the original DLL.
$global:RE8PatchTestFailNextLua = $true
function Copy-Item {
    param([string]$LiteralPath, [string]$Destination, [switch]$Force)
    if ($global:RE8PatchTestFailNextLua -and $LiteralPath -eq (Join-Path $package 'reframework\autorun\re8_display.lua')) {
        $global:RE8PatchTestFailNextLua = $false
        throw 'Injected payload copy failure'
    }
    Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
}
try { Assert-RE8Throws { & $install -GamePath $game -PackageRoot $package } 'Payload copy failure propagates' }
finally { Remove-Item Function:\Copy-Item; Remove-Variable -Name RE8PatchTestFailNextLua -Scope Global }
Assert-RE8Test ((Get-Content -LiteralPath (Join-Path $game 'dinput8.dll') -Raw) -eq 'original dll') 'Rollback restores DLL copied before failure'
Assert-RE8Test ((Get-Content -LiteralPath (Join-Path $game 'reframework\autorun\re8_aspect_ratio_fix.lua') -Raw) -eq 'legacy lua') 'Rollback keeps old Lua'
& $uninstall -GamePath $game | Out-Null
# Reject corrupt packages, traversal and redirected directories before mutation.
[IO.File]::WriteAllText((Join-Path $package 'dinput8.dll'), 'corrupted package')
Assert-RE8Throws { & $install -GamePath $game -PackageRoot $package } 'Checksum mismatch rejected'
Assert-RE8Test ((Get-Content -LiteralPath (Join-Path $game 'dinput8.dll') -Raw) -eq 'original dll') 'Corrupt package does not mutate game'
Assert-RE8Throws { Get-RE8ContainedPath $game '..\outside.dll' } 'Traversal rejected'
Assert-RE8Throws { Get-RE8ContainedPath $game 'C:\outside.dll' } 'Absolute destination rejected'
Assert-RE8Throws { Get-RE8ContainedPath $game 'file.dll:stream' } 'Alternate stream rejected'
$redirectTarget = Join-Path $fixture 'redirect target'
[IO.Directory]::CreateDirectory($redirectTarget) | Out-Null
New-Item -ItemType Junction -Path (Join-Path $game 'redirect') -Target $redirectTarget | Out-Null
Assert-RE8Throws { Get-RE8ContainedPath $game 'redirect\file.dll' } 'Junction rejected'
$result = [ordered]@{ status = 'passed'; checks = $script:checks; fixture = $fixture; scope = 'filesystem fixtures only; no real game installation' }
Write-RE8Json (Join-Path $fixture 'result.json') $result
Write-Output "PASS: $($script:checks) installer checks; fixture: $fixture"
