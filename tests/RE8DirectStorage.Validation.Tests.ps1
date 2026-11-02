[CmdletBinding()]
param([string]$ProjectRoot)
$ErrorActionPreference='Stop'
if(-not $ProjectRoot){$ProjectRoot=Split-Path -Parent $PSScriptRoot}
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
. (Join-Path $ProjectRoot 'tools\RE8Technology.Common.ps1')
$packageScript=Join-Path $ProjectRoot 'tools\RE8Technology.Package.ps1'
$originalBuild=Get-Content -LiteralPath (Join-Path $ProjectRoot 'artifacts\build\RE8DirectStorageBridge-build.json') -Raw|ConvertFrom-Json
$originalReport=Get-Content -LiteralPath (Join-Path $ProjectRoot 'artifacts\build\RE8DirectStorageBridge-game-test.json') -Raw|ConvertFrom-Json
$fixture=Get-TechPath $ProjectRoot ('artifacts\tests\directstorage-validation-'+[Guid]::NewGuid().ToString('N'))
$fixtureEvidence=Get-TechPath $fixture 'artifacts\runtime\directstorage-game\verified-fixture'
[IO.Directory]::CreateDirectory($fixtureEvidence)|Out-Null
$fixtureBinary=Get-TechPath $fixture 'artifacts\directstorage-bridge\Release\RE8DirectStorage.dll'
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($fixtureBinary))|Out-Null
Copy-Item -LiteralPath $originalBuild.binary -Destination $fixtureBinary
foreach($source in $originalBuild.sources){
    $target=Get-TechPath $fixture $source.path
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null
    Copy-Item -LiteralPath (Get-TechPath $ProjectRoot $source.path) -Destination $target
}
$originalBuild.binary=$fixtureBinary
Write-TechJson (Get-TechPath $fixture 'artifacts\build\RE8DirectStorageBridge-build.json') $originalBuild
$sourceEvidence=$originalReport.evidenceDirectory
$originalReport.evidenceDirectory=$fixtureEvidence
$baseline=ConvertTo-Json -InputObject $originalReport -Depth 12
$reportPath=Get-TechPath $fixture 'artifacts\build\RE8DirectStorageBridge-game-test.json'
$logPath=Join-Path $fixtureEvidence 're2_framework_log.txt'
$manifestPath=Join-Path $fixtureEvidence 'install-manifest.json'
$script:checks=0
function Reset-Fixture {
    Copy-Item -LiteralPath (Join-Path $sourceEvidence 're2_framework_log.txt') -Destination $logPath -Force
    Copy-Item -LiteralPath (Join-Path $sourceEvidence 'install-manifest.json') -Destination $manifestPath -Force
    Write-TechJson $reportPath ($baseline|ConvertFrom-Json)
}
function Assert([bool]$condition,[string]$message){if(-not $condition){throw "FAIL: $message"};$script:checks++}
function Reject([string]$name,[scriptblock]$change){
    Reset-Fixture
    $report=Get-Content -LiteralPath $reportPath -Raw|ConvertFrom-Json
    & $change $report
    Write-TechJson $reportPath $report
    $rejected=$false
    try{& $packageScript -Technology DirectStorage -ProjectRoot $fixture -ValidateOnly|Out-Null}catch{$rejected=$true}
    Assert $rejected $name
}
function Update-ManifestHash($report){
    if($report.PSObject.Properties['evidenceManifestSha256']){$report.evidenceManifestSha256=Get-TechHash $manifestPath}
}
Reset-Fixture
& $packageScript -Technology DirectStorage -ProjectRoot $fixture -ValidateOnly|Out-Null
Assert $true 'Exact copied real-game evidence accepted'
Reject 'String false is not a boolean activation confirmation' {param($report)$report.actualGameActivationVerified='false'}
Reject 'String true is not a boolean gameplay confirmation' {param($report)$report.gameplayConfirmed='true'}
Reject 'String nine cannot bypass numeric minimum' {param($report)$report.confirmedReads='9';$report.nativeVerifiedReads='9'}
Reject 'Negative count rejected' {param($report)$report.confirmedReads=-1}
Reject 'Zero byte claim rejected' {param($report)$report.confirmedBytes=0}
Reject 'Native compatibility count below reads rejected' {param($report)$report.nativeCompatibilityReads=$report.confirmedReads-1}
Reject 'Numeric receipt/log disagreement rejected' {param($report)$report.confirmedReads=$report.confirmedReads+1}
Reject 'Nonzero error claim rejected' {param($report)$report.referenceErrors=1}
Reject 'Wrong DLL rejected' {param($report)$report.binarySha256='0'*64}
Reject 'Wrong audited game executable rejected' {param($report)$report.gameExeSha256='0'*64}
Reject 'Wrong technology rejected' {param($report)$report.technology='Agility'}
Reject 'Missing archive rejected' {param($report)$report.evidenceDirectory=Join-Path $fixture 'artifacts/runtime/directstorage-game/absent'}
Reject 'Changed archive bytes rejected' {param($report)[IO.File]::AppendAllText($logPath,"`r`nchanged")}
Reject 'Changed receipt line rejected' {param($report)$report.counterLogLine+=' changed'}
Reject 'Duplicate counters rejected even with matching updated checksum' {
    param($report)
    $duplicate=$report.counterLogLine+' pak_reads='+$report.confirmedReads
    [IO.File]::WriteAllText($logPath,([IO.File]::ReadAllText($logPath).Replace($report.counterLogLine,$duplicate)),(New-Object Text.UTF8Encoding($false)))
    $report.counterLogLine=$duplicate;$report.evidenceLogSha256=Get-TechHash $logPath
}
Reject 'Wrong archived DLL manifest hash rejected' {
    param($report)
    $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
    ($manifest.files|Where-Object {$_.relative -eq 'reframework\plugins\RE8DirectStorage.dll'}).sha256='0'*64
    Write-TechJson $manifestPath $manifest;Update-ManifestHash $report
}
Reject 'String applied field rejected' {
    param($report)
    $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
    $manifest.files[0].applied='true'
    Write-TechJson $manifestPath $manifest;Update-ManifestHash $report
}
Reject 'Missing required runtime manifest entry rejected' {
    param($report)
    $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
    $manifest.files=@($manifest.files|Where-Object {$_.relative -ne 'RE8DirectStorage\dstoragecore.dll'})
    Write-TechJson $manifestPath $manifest;Update-ManifestHash $report
}
Reset-Fixture
& $packageScript -Technology DirectStorage -ProjectRoot $fixture -ValidateOnly|Out-Null
Assert $true 'Unchanged genuine evidence remains valid after rejection cases'
Assert (-not (Test-Path -LiteralPath (Join-Path $fixture 'dist'))) 'Validation-only cases never create a public ZIP'
Write-TechJson (Join-Path $fixture 'result.json') ([ordered]@{status='passed';checks=$script:checks;scope='Copied artifact/evidence fixtures only; no game access or native execution'})
Write-Output "PASS: $($script:checks) DirectStorage validation-integrity checks. Fixture: $fixture"
