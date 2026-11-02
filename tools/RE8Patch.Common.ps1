Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RE8ContainedPath([string]$Root, [string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative.Contains(':')) {
        throw "Invalid relative path: $Relative"
    }
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $full = [IO.Path]::GetFullPath((Join-Path $base $Relative))
    if (-not $full.StartsWith($base + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes its root: $Relative"
    }
    $cursor = $full
    while ($cursor -and $cursor.Length -ge $base.Length) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing a junction/symlink in installation path: $cursor"
            }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    return $full
}

function Write-RE8Json([string]$Path, $Value) {
    $parent = [IO.Path]::GetDirectoryName($Path)
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $json = ConvertTo-Json -InputObject $Value -Depth 12
    $temporary = $Path + '.pending'
    [IO.File]::WriteAllText($temporary, $json, (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-RE8Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-RE8GameStopped([string]$GamePath) {
    if (-not (Test-Path -LiteralPath (Join-Path $GamePath 're8.exe') -PathType Leaf)) {
        throw 'GamePath must contain re8.exe.'
    }
    $targetExecutable = [IO.Path]::GetFullPath((Join-Path $GamePath 're8.exe'))
    foreach ($process in @(Get-Process -Name re8 -ErrorAction SilentlyContinue)) {
        if (-not $process.Path -or [IO.Path]::GetFullPath($process.Path) -eq $targetExecutable) {
            throw 'Close Resident Evil Village before installing or uninstalling.'
        }
    }
}

function Get-RE8SourceFingerprint([string]$ProjectRoot) {
    $source = Join-Path $ProjectRoot 'reframework_src'
    $paths = @(
        Get-ChildItem -LiteralPath (Join-Path $source 'src'), (Join-Path $source 'shared'), (Join-Path $source 'include'), (Join-Path $source 'dependencies\imgui') -File -Recurse |
            Where-Object { $_.Extension -in '.cpp', '.c', '.hpp', '.h', '.inl' }
        Get-Item -LiteralPath (Join-Path $source 'CMakeLists.txt'), (Join-Path $source 'cmake.toml')
    ) | Sort-Object FullName
    $lines = foreach ($item in $paths) {
        $item.FullName.Substring($source.Length).Replace('\', '/') + ':' + (Get-RE8Hash $item.FullName)
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))).Replace('-', '') }
    finally { $sha.Dispose() }
}
