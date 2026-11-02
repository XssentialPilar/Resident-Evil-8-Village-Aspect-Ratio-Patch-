[CmdletBinding()]
param([string]$ProjectRoot)
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'RE8Patch.Common.ps1')
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$source = Get-RE8ContainedPath $ProjectRoot 'reframework_src'
$metadata = Get-Content -LiteralPath (Join-Path $ProjectRoot 'external\REFramework.source.json') -Raw | ConvertFrom-Json
if ($metadata.repository -ne 'https://github.com/praydog/REFramework.git' -or
    $metadata.sourceRevision -notmatch '^[0-9a-f]{40}$' -or
    $metadata.imguiRevision -notmatch '^[0-9a-f]{40}$') {
    throw 'Unsupported source provenance. No checkout was modified.'
}
$frameworkPatch = Get-RE8ContainedPath $ProjectRoot 'patches\RE8Framework.patch'
$imguiPatch = Get-RE8ContainedPath $ProjectRoot 'patches\RE8ImGuiStartup.patch'
foreach ($patch in @($frameworkPatch, $imguiPatch)) {
    $name = [IO.Path]::GetFileName($patch)
    $expected = $metadata.patches.$name
    if ($expected -notmatch '^[0-9a-fA-F]{64}$' -or (Get-RE8Hash $patch) -ne $expected) {
        throw "Patch hash mismatch: $name. No checkout was modified."
    }
}

# Capture native output without a shell or PowerShell's stderr-to-error coercion.
function ConvertTo-RE8GitArgument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}
function Invoke-RE8SourceGit([string]$Directory, [string[]]$Arguments, [int[]]$Success = @(0)) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = (Get-Command git -CommandType Application | Select-Object -First 1).Source
    $start.Arguments = ((@('-C', $Directory) + $Arguments | ForEach-Object { ConvertTo-RE8GitArgument $_ }) -join ' ')
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $start.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    try {
        $process.Start() | Out-Null
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $result = [pscustomobject]@{ code = $process.ExitCode; output = $stdout.GetAwaiter().GetResult(); error = $stderr.GetAwaiter().GetResult() }
        if ($result.code -notin $Success) { throw "git $($Arguments -join ' ') failed: $($result.error.Trim())" }
        return $result
    } finally { $process.Dispose() }
}
function Get-RE8CheckoutState([string]$Directory, [string]$Patch, [switch]$Framework) {
    $arguments = @('diff', '--no-ext-diff', '--no-color', '--binary', 'HEAD')
    if ($Framework) { $arguments += @('--', '.', ':(exclude)dependencies/imgui') }
    $actual = (Invoke-RE8SourceGit $Directory $arguments).output
    $untracked = (Invoke-RE8SourceGit $Directory @('ls-files', '--others', '--exclude-standard', '-z')).output
    $additions = @($untracked.Split([char]0) | Where-Object { $_.Length -gt 0 })
    # Match the exporter's deterministic ordering and no-index representation.
    [Array]::Sort($additions, [StringComparer]::Ordinal)
    foreach ($relative in $additions) {
        $actual += (Invoke-RE8SourceGit $Directory @('diff', '--no-index', '--no-ext-diff', '--no-color', '--binary', '--', 'NUL', $relative) @(1)).output
    }
    if ($actual.Length -eq 0) {
        Invoke-RE8SourceGit $Directory @('apply', '--check', $Patch) | Out-Null
        return 'clean'
    }
    $expected = [IO.File]::ReadAllText($Patch, (New-Object Text.UTF8Encoding($false)))
    if ($actual -cne $expected) { throw "Checkout contains changes outside the recorded patch: $Directory. No reset or overwrite was performed." }
    Invoke-RE8SourceGit $Directory @('apply', '--reverse', '--check', $Patch) | Out-Null
    return 'prepared'
}

if (-not (Test-Path -LiteralPath $source)) {
    Write-Output 'Creating the external checkout at the recorded upstream revision...'
    # Fetch the exact commit rather than following a moving upstream branch.
    Invoke-RE8SourceGit $ProjectRoot @('init', $source) | Out-Null
    Invoke-RE8SourceGit $source @('remote', 'add', 'origin', $metadata.repository) | Out-Null
    Invoke-RE8SourceGit $source @('fetch', '--depth', '1', 'origin', $metadata.sourceRevision) | Out-Null
    Invoke-RE8SourceGit $source @('checkout', '--detach', $metadata.sourceRevision) | Out-Null
} elseif (-not (Test-Path -LiteralPath (Join-Path $source '.git'))) {
    throw 'reframework_src already exists without its own Git metadata. It was not changed.'
}
$top = (Invoke-RE8SourceGit $source @('rev-parse', '--show-toplevel')).output.Trim()
if ([IO.Path]::GetFullPath($top) -ne $source) { throw 'reframework_src is not the expected repository root.' }
$head = (Invoke-RE8SourceGit $source @('rev-parse', 'HEAD')).output.Trim()
if ($head -ne $metadata.sourceRevision) { throw 'Existing REFramework HEAD differs from sourceRevision. No checkout/reset was performed.' }

# Preflight the top-level worktree before initializing any missing submodules.
$frameworkState = Get-RE8CheckoutState $source $frameworkPatch -Framework
$submoduleStatus = (Invoke-RE8SourceGit $source @('submodule', 'status', '--recursive')).output
foreach ($line in @($submoduleStatus -split "`n" | Where-Object { $_.Length -gt 0 })) {
    if ($line[0] -eq '+' -or $line[0] -eq 'U') { throw 'A submodule has a mismatched commit or unresolved merge. No submodule reset was performed.' }
}
if ($submoduleStatus -match '(?m)^-') {
    Invoke-RE8SourceGit $source @('submodule', 'update', '--init', '--recursive', '--depth', '1') | Out-Null
}
$imgui = Get-RE8ContainedPath $source 'dependencies\imgui'
$imguiHead = (Invoke-RE8SourceGit $imgui @('rev-parse', 'HEAD')).output.Trim()
if ($imguiHead -ne $metadata.imguiRevision) { throw 'Existing ImGui HEAD differs from imguiRevision. It was not reset.' }
$imguiState = Get-RE8CheckoutState $imgui $imguiPatch

# Both patches have passed preflight before either worktree is written.
if ($frameworkState -eq 'clean') { Invoke-RE8SourceGit $source @('apply', $frameworkPatch) | Out-Null }
if ($imguiState -eq 'clean') { Invoke-RE8SourceGit $imgui @('apply', $imguiPatch) | Out-Null }
if ((Get-RE8CheckoutState $source $frameworkPatch -Framework) -ne 'prepared' -or
    (Get-RE8CheckoutState $imgui $imguiPatch) -ne 'prepared') { throw 'Prepared source verification failed.' }
Write-Output "Source prepared at $head; exact patches verified. Existing matching patches were preserved."
Write-Output 'Next from the source root: tools/RE8Patch.Build.ps1, then tools/RE8Patch.Test.ps1, then tools/RE8Patch.Package.ps1.'
