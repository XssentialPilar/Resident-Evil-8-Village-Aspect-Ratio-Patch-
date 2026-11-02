[CmdletBinding()]
param([string]$ProjectRoot)
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'RE8Patch.Common.ps1')
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$receiptPath = Join-Path $ProjectRoot 'artifacts\build\RE8-build.json'
if (-not (Test-Path -LiteralPath $receiptPath)) { throw 'Run tools/RE8Patch.Build.ps1 successfully before packaging.' }
$receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
if ($receipt.schema -ne 1 -or $receipt.status -ne 'compiled-only-unverified-in-game') { throw 'Unsupported build receipt.' }
$expectedBinaries = @('reframework_src\build\bin\RE8\dinput8.dll', 'reframework_src\build\bin\REFramework\dinput8.dll') |
    ForEach-Object { Get-RE8ContainedPath $ProjectRoot $_ }
if ([IO.Path]::GetFullPath($receipt.binary) -notin $expectedBinaries) { throw 'Build receipt does not point to a supported build output.' }
if ($receipt.sourceFingerprint -ne (Get-RE8SourceFingerprint $ProjectRoot)) { throw 'C++ sources changed since the recorded build.' }
if ((Get-RE8Hash $receipt.binary) -ne $receipt.binarySha256) { throw 'The compiled DLL changed since the recorded build.' }
$name = 'RE8VillagePatch-dev-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 6)
$output = Get-RE8ContainedPath $ProjectRoot ('dist\' + $name)
$map = @(
    @{ source = $receipt.binary; destination = 'dinput8.dll'; preserveExisting = $false }
    @{ source = (Join-Path $ProjectRoot 'runtime\reframework\autorun\re8_display.lua'); destination = 'reframework\autorun\re8_display.lua'; preserveExisting = $false }
    @{ source = (Join-Path $ProjectRoot 'config\re8_display.json'); destination = 'reframework\data\re8_display.json'; preserveExisting = $true }
    @{ source = (Join-Path $ProjectRoot 'config\re2_fw_config.txt'); destination = 're2_fw_config.txt'; preserveExisting = $true }
)
$supportFiles = @('install.bat', 'uninstall.bat', 'LICENSE', 'README.md', 'tools\RE8Patch.Common.ps1', 'tools\RE8Patch.Install.ps1', 'tools\RE8Patch.Uninstall.ps1', 'docs\technical-report.md', 'docs\validation-matrix.md', 'docs\file-audit.md')
foreach ($optional in @('docs\cursor-evidence.json', 'docs\cursor-evidence.md', 'docs\cursor-controller.md', 'docs\aspect-evidence.md', 'docs\legacy-release-v1.1.0.md', 'docs\validation-results.json')) {
    if (Test-Path -LiteralPath (Get-RE8ContainedPath $ProjectRoot $optional) -PathType Leaf) { $supportFiles += $optional }
}
$licenseRoot = Join-Path $ProjectRoot 'licenses'
if (-not (Test-Path -LiteralPath (Join-Path $licenseRoot 'REFramework-MIT.txt'))) { throw 'Missing Praydog / REFramework license bundle.' }
foreach ($required in @($map | ForEach-Object { $_.source }) + @($supportFiles | ForEach-Object { Get-RE8ContainedPath $ProjectRoot $_ })) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing package input: $required" }
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$files = @()
foreach ($file in $map) {
    $target = Get-RE8ContainedPath $output $file.destination
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    Copy-Item -LiteralPath $file.source -Destination $target
    $files += [ordered]@{ source = $file.destination; destination = $file.destination; sha256 = Get-RE8Hash $target; preserveExisting = $file.preserveExisting }
}
foreach ($relative in $supportFiles) {
    $target = Get-RE8ContainedPath $output $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    Copy-Item -LiteralPath (Get-RE8ContainedPath $ProjectRoot $relative) -Destination $target
}
foreach ($item in Get-ChildItem -LiteralPath $licenseRoot -File -Recurse) {
    $relative = 'licenses' + $item.FullName.Substring($licenseRoot.Length)
    $target = Get-RE8ContainedPath $output $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    Copy-Item -LiteralPath $item.FullName -Destination $target
}
Write-RE8Json (Join-Path $output 'runtime-files.json') ([ordered]@{ schema = 1; status = 'development-candidate-unverified-in-game'; builtUtc = $receipt.builtUtc; sourceFingerprint = $receipt.sourceFingerprint; files = $files })
[IO.File]::WriteAllText((Join-Path $output 'VERIFICATION-PENDING.txt'), "DEVELOPMENT CANDIDATE. No new release is published.`r`nCompilation and automated checks do not establish in-game cursor, map or display correctness.`r`nReview docs/technical-report.md in the source checkout for real results and remaining checks.`r`n", (New-Object Text.UTF8Encoding($false)))
$zip = $output + '.zip'
Compress-Archive -LiteralPath $output -DestinationPath $zip
Write-Output "Development candidate folder: $output"
Write-Output "Local archive: $zip"
