[CmdletBinding()]
param([string]$ProjectRoot)
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $ProjectRoot 'tools\RE8Patch.Common.ps1')
$fixture = Get-RE8ContainedPath $ProjectRoot ('artifacts\tests\prepare-source-' + [Guid]::NewGuid().ToString('N'))
$source = Join-Path $fixture 'reframework_src'
$upstream = Join-Path $fixture 'imgui upstream space !'
foreach ($path in @($source, $upstream, (Join-Path $fixture 'external'), (Join-Path $fixture 'patches'))) { [IO.Directory]::CreateDirectory($path) | Out-Null }
function Invoke-RE8FixtureGit([string]$Directory, [string[]]$Arguments) {
    $output = & git -C $Directory @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'Fixture Git command failed.' }
    return $output
}
Invoke-RE8FixtureGit $upstream @('init', '--quiet') | Out-Null
Invoke-RE8FixtureGit $upstream @('config', 'core.autocrlf', 'false') | Out-Null
[IO.File]::WriteAllText((Join-Path $upstream 'imgui.txt'), "base imgui`n")
Invoke-RE8FixtureGit $upstream @('add', '.') | Out-Null
Invoke-RE8FixtureGit $upstream @('-c', 'user.name=RE8 Test', '-c', 'user.email=re8-test@example.invalid', 'commit', '--quiet', '-m', 'fixture base') | Out-Null
$imguiRevision = (Invoke-RE8FixtureGit $upstream @('rev-parse', 'HEAD')).Trim()
Invoke-RE8FixtureGit $source @('init', '--quiet') | Out-Null
Invoke-RE8FixtureGit $source @('config', 'core.autocrlf', 'false') | Out-Null
[IO.File]::WriteAllText((Join-Path $source 'native.txt'), "base native`n")
Invoke-RE8FixtureGit $source @('-c', 'protocol.file.allow=always', 'submodule', 'add', '--quiet', $upstream, 'dependencies/imgui') | Out-Null
Invoke-RE8FixtureGit $source @('add', '.') | Out-Null
Invoke-RE8FixtureGit $source @('-c', 'user.name=RE8 Test', '-c', 'user.email=re8-test@example.invalid', 'commit', '--quiet', '-m', 'fixture base') | Out-Null
$sourceRevision = (Invoke-RE8FixtureGit $source @('rev-parse', 'HEAD')).Trim()
$imgui = Join-Path $source 'dependencies\imgui'
Invoke-RE8FixtureGit $imgui @('config', 'core.autocrlf', 'false') | Out-Null
[IO.File]::WriteAllText((Join-Path $source 'native.txt'), "patched native`n")
[IO.File]::WriteAllText((Join-Path $imgui 'imgui.txt'), "patched imgui`n")
$frameworkPatch = Join-Path $fixture 'patches\RE8Framework.patch'
$imguiPatch = Join-Path $fixture 'patches\RE8ImGuiStartup.patch'
$frameworkDiff = (& git -C $source diff --binary HEAD -- . ':(exclude)dependencies/imgui') -join "`n"
$imguiDiff = (& git -C $imgui diff --binary HEAD) -join "`n"
[IO.File]::WriteAllText($frameworkPatch, $frameworkDiff + "`n", (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($imguiPatch, $imguiDiff + "`n", (New-Object Text.UTF8Encoding($false)))
$metadata = [ordered]@{ repository = 'https://github.com/praydog/REFramework.git'; sourceRevision = $sourceRevision; imguiRevision = $imguiRevision; patches = [ordered]@{ 'RE8Framework.patch' = Get-RE8Hash $frameworkPatch; 'RE8ImGuiStartup.patch' = Get-RE8Hash $imguiPatch } }
$metadataPath = Join-Path $fixture 'external\REFramework.source.json'
Write-RE8Json $metadataPath $metadata
[IO.File]::WriteAllText((Join-Path $source 'native.txt'), "base native`n")
[IO.File]::WriteAllText((Join-Path $imgui 'imgui.txt'), "base imgui`n")
$prepare = Join-Path $ProjectRoot 'tools\RE8Patch.PrepareSource.ps1'
$script:checks = 0
function Assert-RE8PrepareTest([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}
function Assert-RE8PrepareThrows([scriptblock]$Action, [string]$Message) {
    $thrown = $false
    try { & $Action | Out-Null } catch { $thrown = $true }
    Assert-RE8PrepareTest $thrown $Message
}
& $prepare -ProjectRoot $fixture | Out-Null
Assert-RE8PrepareTest ((Get-Content -LiteralPath (Join-Path $source 'native.txt') -Raw) -eq "patched native`n") 'Framework patch applied'
Assert-RE8PrepareTest ((Get-Content -LiteralPath (Join-Path $imgui 'imgui.txt') -Raw) -eq "patched imgui`n") 'ImGui patch applied'
$indexHash = Get-RE8Hash (Join-Path $source '.git\index')
& $prepare -ProjectRoot $fixture | Out-Null
Assert-RE8PrepareTest ((Get-RE8Hash (Join-Path $source '.git\index')) -eq $indexHash) 'Idempotent prepare preserves Git index'
[IO.File]::WriteAllText((Join-Path $source 'native.txt'), "user modified native`n")
Assert-RE8PrepareThrows { & $prepare -ProjectRoot $fixture } 'Unrelated tracked edits rejected'
Assert-RE8PrepareTest ((Get-Content -LiteralPath (Join-Path $source 'native.txt') -Raw) -eq "user modified native`n") 'User edit not overwritten'
[IO.File]::WriteAllText((Join-Path $source 'native.txt'), "patched native`n")
[IO.File]::WriteAllText((Join-Path $source 'untracked.txt'), 'user addition')
Assert-RE8PrepareThrows { & $prepare -ProjectRoot $fixture } 'Unrecorded untracked file rejected'
Remove-Item -LiteralPath (Join-Path $source 'untracked.txt')
$metadata.sourceRevision = ('0' * 40)
Write-RE8Json $metadataPath $metadata
Assert-RE8PrepareThrows { & $prepare -ProjectRoot $fixture } 'Mismatched framework commit rejected'
Assert-RE8PrepareTest ((Invoke-RE8FixtureGit $source @('rev-parse', 'HEAD')).Trim() -eq $sourceRevision) 'Mismatched commit does not reset HEAD'
$metadata.sourceRevision = $sourceRevision
$metadata.imguiRevision = ('0' * 40)
Write-RE8Json $metadataPath $metadata
Assert-RE8PrepareThrows { & $prepare -ProjectRoot $fixture } 'Mismatched ImGui commit rejected'
$metadata.imguiRevision = $imguiRevision
Write-RE8Json $metadataPath $metadata
[IO.File]::AppendAllText($frameworkPatch, 'corrupted patch')
Assert-RE8PrepareThrows { & $prepare -ProjectRoot $fixture } 'Corrupt patch rejected before worktree mutation'
[IO.File]::WriteAllText($frameworkPatch, $frameworkDiff + "`n", (New-Object Text.UTF8Encoding($false)))
# The second checkout must pass preflight before the clean framework is patched.
[IO.File]::WriteAllText((Join-Path $source 'native.txt'), "base native`n")
[IO.File]::WriteAllText((Join-Path $imgui 'imgui.txt'), "unrelated imgui edit`n")
Assert-RE8PrepareThrows { & $prepare -ProjectRoot $fixture } 'ImGui extra edit rejects entire preparation'
Assert-RE8PrepareTest ((Get-Content -LiteralPath (Join-Path $source 'native.txt') -Raw) -eq "base native`n") 'Failed child preflight leaves framework clean'
[IO.File]::WriteAllText((Join-Path $imgui 'imgui.txt'), "patched imgui`n")
& $prepare -ProjectRoot $fixture | Out-Null
Assert-RE8PrepareTest ((Get-Content -LiteralPath (Join-Path $source 'native.txt') -Raw) -eq "patched native`n") 'Mixed clean/prepared checkout completes missing patch'
Write-RE8Json (Join-Path $fixture 'result.json') ([ordered]@{ status = 'passed'; checks = $script:checks; scope = 'local tiny Git repositories and submodule; no network clone and no game access'; fixture = $fixture })
Write-Output "PASS: $($script:checks) source preparation checks; fixture: $fixture"
