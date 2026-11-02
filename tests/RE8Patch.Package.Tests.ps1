[CmdletBinding()]
param([string]$ProjectRoot)
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $ProjectRoot 'tools\RE8Patch.Common.ps1')
$fixture = Get-RE8ContainedPath $ProjectRoot ('artifacts\tests\package-' + [Guid]::NewGuid().ToString('N'))
$paths = @('reframework_src\src', 'reframework_src\shared', 'reframework_src\include', 'reframework_src\dependencies\imgui', 'reframework_src\build\bin\RE8', 'runtime\reframework\autorun', 'config', 'tools', 'docs', 'licenses')
foreach ($relative in $paths) { [IO.Directory]::CreateDirectory((Join-Path $fixture $relative)) | Out-Null }
foreach ($relative in @('reframework_src\src\fixture.cpp', 'reframework_src\CMakeLists.txt', 'reframework_src\cmake.toml', 'runtime\reframework\autorun\re8_display.lua', 'config\re8_display.json', 'config\re2_fw_config.txt', 'README.md', 'LICENSE', 'docs\technical-report.md', 'docs\validation-matrix.md', 'docs\file-audit.md', 'docs\cursor-evidence.json', 'docs\cursor-controller.md', 'docs\aspect-evidence.md', 'docs\legacy-release-v1.1.0.md', 'licenses\REFramework-MIT.txt')) {
    [IO.File]::WriteAllText((Join-Path $fixture $relative), 'packaging fixture - not runtime evidence')
}
foreach ($relative in @('install.bat', 'uninstall.bat', 'tools\RE8Patch.Common.ps1', 'tools\RE8Patch.Install.ps1', 'tools\RE8Patch.Uninstall.ps1')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $relative) -Destination (Join-Path $fixture $relative)
}
$binary = Join-Path $fixture 'reframework_src\build\bin\RE8\dinput8.dll'
[IO.File]::WriteAllText($binary, 'fake DLL used only to test packaging file operations')
$receiptPath = Join-Path $fixture 'artifacts\build\RE8-build.json'
$receipt = [ordered]@{ schema = 1; status = 'compiled-only-unverified-in-game'; builtUtc = 'fixture'; sourceFingerprint = Get-RE8SourceFingerprint $fixture; binary = $binary; binarySha256 = Get-RE8Hash $binary }
Write-RE8Json $receiptPath $receipt
$script:checks = 0
function Assert-RE8PackageTest([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}
function Assert-RE8PackageThrows([scriptblock]$Action, [string]$Message) {
    $thrown = $false
    try { & $Action | Out-Null } catch { $thrown = $true }
    Assert-RE8PackageTest $thrown $Message
}
$packageScript = Join-Path $ProjectRoot 'tools\RE8Patch.Package.ps1'
& $packageScript -ProjectRoot $fixture | Out-Null
$output = Get-ChildItem -LiteralPath (Join-Path $fixture 'dist') -Directory | Select-Object -First 1
$payload = Get-Content -LiteralPath (Join-Path $output.FullName 'runtime-files.json') -Raw | ConvertFrom-Json
Assert-RE8PackageTest ($payload.files.Count -eq 4) 'Exactly four runtime files enumerated'
Assert-RE8PackageTest ($payload.status -eq 'development-candidate-unverified-in-game') 'Candidate explicitly marked unverified'
foreach ($file in $payload.files) {
    Assert-RE8PackageTest ((Get-RE8Hash (Join-Path $output.FullName $file.source)) -eq $file.sha256) ('Packaged hash: ' + $file.source)
}
Assert-RE8PackageTest (Test-Path -LiteralPath (Join-Path $output.FullName 'licenses\REFramework-MIT.txt')) 'Attribution packaged'
Assert-RE8PackageTest (Test-Path -LiteralPath (Join-Path $output.FullName 'docs\technical-report.md')) 'Technical report packaged'
Assert-RE8PackageTest ((Test-Path -LiteralPath (Join-Path $output.FullName 'docs\aspect-evidence.md')) -and (Test-Path -LiteralPath (Join-Path $output.FullName 'docs\cursor-controller.md')) -and (Test-Path -LiteralPath (Join-Path $output.FullName 'docs\legacy-release-v1.1.0.md'))) 'Evidence and preserved release documentation packaged'
Assert-RE8PackageTest (-not (Test-Path -LiteralPath (Join-Path $output.FullName 'reframework_src'))) 'C++ source excluded'
Assert-RE8PackageTest (-not (Test-Path -LiteralPath (Join-Path $output.FullName 'tests'))) 'Tests excluded'
Assert-RE8PackageTest (Test-Path -LiteralPath ($output.FullName + '.zip')) 'Local archive created'
[IO.File]::WriteAllText((Join-Path $fixture 'reframework_src\src\fixture.cpp'), 'changed C++ source')
Assert-RE8PackageThrows { & $packageScript -ProjectRoot $fixture } 'Stale-source receipt rejected'
$receipt.sourceFingerprint = Get-RE8SourceFingerprint $fixture
Write-RE8Json $receiptPath $receipt
[IO.File]::WriteAllText($binary, 'changed DLL')
Assert-RE8PackageThrows { & $packageScript -ProjectRoot $fixture } 'Changed compiled binary rejected'
$receipt.binarySha256 = Get-RE8Hash $binary
$receipt.binary = Join-Path $fixture 'README.md'
Write-RE8Json $receiptPath $receipt
Assert-RE8PackageThrows { & $packageScript -ProjectRoot $fixture } 'Non-build binary path rejected'
$receipt.binary = $binary
Write-RE8Json $receiptPath $receipt
Remove-Item -LiteralPath (Join-Path $fixture 'licenses\REFramework-MIT.txt')
Assert-RE8PackageThrows { & $packageScript -ProjectRoot $fixture } 'Missing license rejected'
Assert-RE8PackageTest ((@(Get-ChildItem -LiteralPath (Join-Path $fixture 'dist') -Directory)).Count -eq 1) 'Rejected packages create no partial directories'
# Execute the actual batch wrappers with spaces and ! in the target path.
$game = Join-Path $fixture 'game space !'
[IO.Directory]::CreateDirectory($game) | Out-Null
[IO.File]::WriteAllText((Join-Path $game 're8.exe'), 'filesystem fixture only')
& (Join-Path $output.FullName 'install.bat') $game | Out-Null
Assert-RE8PackageTest ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath (Join-Path $game 'dinput8.dll'))) 'Batch install preserves spaces and !'
& (Join-Path $output.FullName 'uninstall.bat') $game | Out-Null
Assert-RE8PackageTest ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $game 'dinput8.dll'))) 'Batch uninstall restores fixture'
Write-RE8Json (Join-Path $fixture 'result.json') ([ordered]@{ status = 'passed'; checks = $script:checks; scope = 'packaging and batch filesystem fixtures only; fake DLL is not build evidence'; fixture = $fixture })
Write-Output "PASS: $($script:checks) packaging checks; fixture: $fixture"
