Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RE8ContainedPath([string]$Root, [string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative.Contains(':')) { throw "Invalid relative path: $Relative" }
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $full = [IO.Path]::GetFullPath((Join-Path $base $Relative))
    if (-not $full.StartsWith($base + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes its root: $Relative" }
    $cursor = $full
    while ($cursor -and $cursor.Length -ge $base.Length) {
        if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Refusing a redirected installation path: $cursor" }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    return $full
}
function Write-RE8Json([string]$Path, $Value) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText(($Path + '.pending'), (ConvertTo-Json -InputObject $Value -Depth 12), (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath ($Path + '.pending') -Destination $Path -Force
}
function Get-RE8Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-RE8GameStopped([string]$GamePath) {
    if (-not (Test-Path -LiteralPath (Join-Path $GamePath 're8.exe') -PathType Leaf)) { throw 'GamePath must contain re8.exe.' }
    $target = [IO.Path]::GetFullPath((Join-Path $GamePath 're8.exe'))
    foreach ($process in @(Get-Process -Name re8 -ErrorAction SilentlyContinue)) {
        if (-not $process.Path -or [IO.Path]::GetFullPath($process.Path) -eq $target) { throw 'Close Resident Evil Village before installing or uninstalling.' }
    }
}
function Get-RE8DisplayFingerprint([string]$ProjectRoot) {
    $paths = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'native'), (Join-Path $ProjectRoot 'external\reframework-sdk'), (Join-Path $ProjectRoot 'external\minhook') -Recurse -File | Where-Object { $_.Extension -in '.cpp', '.c', '.hpp', '.h', '.txt', '.rc' }) | Sort-Object FullName
    $lines = foreach ($item in $paths) { $item.FullName.Substring($ProjectRoot.Length).Replace('\', '/') + ':' + (Get-RE8Hash $item.FullName) }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))).Replace('-', '') }
    finally { $sha.Dispose() }
}
