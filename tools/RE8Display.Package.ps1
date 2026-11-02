[CmdletBinding()]
param([string]$ProjectRoot)
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'RE8Display.Common.ps1')
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$receipt = Get-Content -LiteralPath (Join-Path $ProjectRoot 'artifacts\build\RE8Display-build.json') -Raw | ConvertFrom-Json
if ($receipt.schema -ne 2 -or $receipt.version -ne '2.1.0' -or $receipt.configuration -notin @('Release','RelWithDebInfo')) { throw 'Invalid standalone build receipt.' }
$expected = Join-Path $ProjectRoot ('artifacts\native\' + $receipt.configuration + '\RE8Display.dll')
if ([IO.Path]::GetFullPath($receipt.binary) -ne [IO.Path]::GetFullPath($expected)) { throw 'Receipt points outside the standalone output.' }
if ($receipt.sourceFingerprint -ne (Get-RE8DisplayFingerprint $ProjectRoot)) { throw 'Standalone sources changed since compilation.' }
if ((Get-RE8Hash $expected) -ne $receipt.binarySha256) { throw 'Standalone DLL checksum mismatch.' }
$name = 'RE8Display-2.1.0-candidate-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6)
$output = Get-RE8ContainedPath $ProjectRoot ('dist\' + $name)
$map = @(
    @{source=$expected;destination='reframework\plugins\RE8Display.dll'}
    @{source=(Join-Path $ProjectRoot 'config\RE8Display.ini');destination='reframework\data\RE8Display.ini'}
)
$support = @('install.bat','uninstall.bat','LICENSE','README.md','tools\RE8Display.Common.ps1','tools\RE8Display.Install.ps1','tools\RE8Display.Uninstall.ps1','docs\release-2.1.0.md')
foreach ($path in (@($map | ForEach-Object source) + @($support | ForEach-Object { Join-Path $ProjectRoot $_ }) + @((Join-Path $ProjectRoot 'licenses\REFramework-MIT.txt'),(Join-Path $ProjectRoot 'external\minhook\LICENSE.txt')))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing package input: $path" }
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$files = foreach ($file in $map) {
    $target = Get-RE8ContainedPath $output $file.destination
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    Copy-Item -LiteralPath $file.source -Destination $target
    [ordered]@{source=$file.destination;destination=$file.destination;sha256=Get-RE8Hash $target}
}
foreach ($relative in $support) {
    $target = Get-RE8ContainedPath $output $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $relative) -Destination $target
}
[IO.Directory]::CreateDirectory((Join-Path $output 'licenses')) | Out-Null
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'licenses\REFramework-MIT.txt') -Destination (Join-Path $output 'licenses\REFramework-MIT.txt')
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'external\minhook\LICENSE.txt') -Destination (Join-Path $output 'licenses\MinHook.txt')
Write-RE8Json (Join-Path $output 'runtime-files.json') ([ordered]@{schema=2;version='2.1.0';format='reframework-plugin';builtUtc=$receipt.builtUtc;sourceFingerprint=$receipt.sourceFingerprint;files=@($files)})
$zip = $output + '.zip'
$licenseRelative = 'reframework\plugins\RE8Display.LICENSE.txt'
$licenseTarget = Get-RE8ContainedPath $output $licenseRelative
$notices = foreach ($relative in @('LICENSE','licenses\REFramework-MIT.txt','external\minhook\LICENSE.txt')) {
    "===== $relative =====`r`n" + (Get-Content -LiteralPath (Join-Path $ProjectRoot $relative) -Raw)
}
[IO.File]::WriteAllText($licenseTarget,($notices -join "`r`n`r`n"),(New-Object Text.UTF8Encoding($false)))
# The public drag-and-drop ZIP contains only the plugin, private config and the
# required license notices. Installer receipts/tools/reports remain outside it.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($relative in (@($map | ForEach-Object destination) + @($licenseRelative))) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $output $relative),$relative.Replace('\','/'),[IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose() }
Write-RE8Json (Join-Path $ProjectRoot 'artifacts\build\RE8Display-package.json') ([ordered]@{version='2.1.0';directory=$output;archive=$zip;archiveSha256=Get-RE8Hash $zip;binarySha256=$receipt.binarySha256;sourceFingerprint=$receipt.sourceFingerprint;archiveFiles=@($map.destination)+@($licenseRelative)})
Write-Output "Standalone candidate folder: $output"
Write-Output "Standalone candidate archive: $zip"
