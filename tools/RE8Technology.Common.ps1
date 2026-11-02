Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-TechPath([string]$Root,[string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative.Contains(':')) { throw 'Invalid relative path.' }
    $base=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    $full=[IO.Path]::GetFullPath((Join-Path $base $Relative))
    if (-not $full.StartsWith($base+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Path outside installation root.' }
    for ($cursor=$full; $cursor -and $cursor.Length -ge $base.Length; $cursor=[IO.Path]::GetDirectoryName($cursor)) {
        if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Redirected installation paths are not supported.' }
    }
    return $full
}
function Get-TechHash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-TechJson([string]$Path,$Value) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $pending=$Path+'.pending'
    [IO.File]::WriteAllText($pending,((ConvertTo-Json -InputObject $Value -Depth 12)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $pending -Destination $Path -Force
}
function Assert-TechStopped([string]$Root) {
    $exe=Get-TechPath $Root 're8.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'GamePath must contain re8.exe.' }
    foreach($process in @(Get-Process -Name re8 -ErrorAction SilentlyContinue)) {
        if (-not $process.Path -or [IO.Path]::GetFullPath($process.Path) -eq $exe) { throw 'Close RE8 before installing or removing this module.' }
    }
}
function Get-TechDefinition([string]$Technology) {
    switch($Technology) {
        'Agility' { return [pscustomobject]@{
            Name='Agility';Folder='RE8Agility';Binary='d3d12.dll';Target='d3d12.dll';PackageHash='BF9915DBB39F7C97018D42B36E65469F11C864B805E3BC9A773EBA364208CDC3';
            Runtime=@(@{Entry='build/native/bin/x64/D3D12Core.dll';Target='RE8Agility\D3D12\D3D12Core.dll';Hash='1A588965B12422DB5DF18F9331E244616F4F7A3893DB83A4C578F7DE50A36F13'})
        } }
        'DirectStorage' { return [pscustomobject]@{
            Name='DirectStorage';Folder='RE8DirectStorage';Binary='RE8DirectStorage.dll';Target='reframework\plugins\RE8DirectStorage.dll';PackageHash='5E0EC8178EDD0F5B6EDABA8EC89D3540DC2AE17A9D2DD70E5737ADAC3F50C590';
            Runtime=@(@{Entry='native/bin/x64/dstorage.dll';Target='RE8DirectStorage\dstorage.dll';Hash='4AE887A8CD21DB2CFECD97C34B5F4DA48D8370D4646F3853D60DB809AA02A8BF'},@{Entry='native/bin/x64/dstoragecore.dll';Target='RE8DirectStorage\dstoragecore.dll';Hash='C6A160899D2C607E1547476B210E36B1CE059A78FEB6DC027A2A0CF4A6F22B78'})
        } }
        default { throw 'Unknown technology.' }
    }
}
function Read-TechPackage([string]$Root) {
    $package=Get-Content -LiteralPath (Get-TechPath $Root 'package.json') -Raw | ConvertFrom-Json
    $definition=Get-TechDefinition $package.technology
    if ($package.schema -ne 1 -or $package.binary -ne ('payload/'+$definition.Binary) -or $package.binarySha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Unsupported technology package.' }
    if ((Get-TechHash (Get-TechPath $Root $package.binary)) -ne $package.binarySha256) { throw 'Module checksum mismatch.' }
    return $package
}
