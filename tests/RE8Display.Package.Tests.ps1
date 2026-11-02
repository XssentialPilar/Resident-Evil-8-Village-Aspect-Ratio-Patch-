[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PackageRoot,[string]$ProjectRoot)
if (-not $ProjectRoot) { $ProjectRoot=Split-Path -Parent $PSScriptRoot }
. (Join-Path $ProjectRoot 'tools\RE8Display.Common.ps1')
$PackageRoot=[IO.Path]::GetFullPath($PackageRoot)
$script:checks=0
function Assert([bool]$condition,[string]$message) { if (-not $condition) { throw "FAIL: $message" }; $script:checks++ }
$manifest=Get-Content -LiteralPath (Join-Path $PackageRoot 'runtime-files.json') -Raw | ConvertFrom-Json
Assert ($manifest.schema -eq 2 -and $manifest.version -eq '2.1.0' -and $manifest.format -eq 'reframework-plugin') 'Versioned standalone format'
$files=@($manifest.files)
Assert ($files.Count -eq 2) 'Exactly two runtime files'
Assert (@($files.destination | Where-Object { $_ -notin @('reframework\plugins\RE8Display.dll','reframework\data\RE8Display.ini') }).Count -eq 0) 'Runtime ownership is limited'
foreach ($file in $files) { Assert ((Get-RE8Hash (Get-RE8ContainedPath $PackageRoot $file.destination)) -eq $file.sha256) 'Runtime hash matches' }
Assert (-not (Test-Path -LiteralPath (Join-Path $PackageRoot 'dinput8.dll'))) 'No framework loader bundled'
Assert (-not (Test-Path -LiteralPath (Join-Path $PackageRoot 're2_fw_config.txt'))) 'No shared settings bundled'
Assert (-not (Test-Path -LiteralPath (Join-Path $PackageRoot 'reframework\autorun'))) 'No competing autorun script bundled'
$dlls=@(Get-ChildItem -LiteralPath $PackageRoot -Recurse -Filter '*.dll' -File)
Assert ($dlls.Count -eq 1 -and $dlls[0].Name -eq 'RE8Display.dll') 'No dependency DLLs or unrelated mods'
Assert ([Diagnostics.FileVersionInfo]::GetVersionInfo($dlls[0].FullName).ProductVersion -eq '2.1.0') 'Native version resource is 2.1.0'
Assert (Test-Path -LiteralPath (Join-Path $PackageRoot 'licenses\REFramework-MIT.txt')) 'SDK attribution included'
Assert (Test-Path -LiteralPath (Join-Path $PackageRoot 'licenses\MinHook.txt')) 'MinHook/HDE attribution included'
Assert (Test-Path -LiteralPath (Join-Path $PackageRoot 'docs\release-2.1.0.md')) 'Validation report included'
$unexpected=@(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File | Where-Object { $_.Extension -in '.cpp','.hpp','.c','.h','.pdb','.log' })
Assert ($unexpected.Count -eq 0) 'No source, symbols or development logs in runtime package'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($PackageRoot + '.zip')
try {
    $entries=@($archive.Entries | Where-Object { $_.Name.Length -gt 0 })
    Assert ($entries.Count -eq @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File).Count) 'Archive contains every package file'
    Assert (@($entries | Where-Object { $_.FullName.Replace('\','/') -eq 'reframework/plugins/RE8Display.dll' }).Count -eq 1) 'Archive extracts directly to the documented root'
} finally { $archive.Dispose() }
$result=[ordered]@{status='passed';checks=$script:checks;scope='Actual package structure, hashes, version resource and archive';package=$PackageRoot;pluginSha256=Get-RE8Hash $dlls[0].FullName}
Write-RE8Json (Join-Path $ProjectRoot 'artifacts\tests\RE8Display-package-tests.json') $result
Write-Output "PASS: $($script:checks) actual standalone package checks"
