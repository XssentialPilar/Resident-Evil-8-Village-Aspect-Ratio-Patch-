[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GamePath,[switch]$GameplayCompleted,[string]$ProjectRoot)
$ErrorActionPreference='Stop'
if(-not $ProjectRoot){$ProjectRoot=Split-Path -Parent $PSScriptRoot}
. (Join-Path $PSScriptRoot 'RE8Technology.Common.ps1')
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
$GamePath=[IO.Path]::GetFullPath($GamePath)
$build=Get-Content (Get-TechPath $ProjectRoot 'artifacts/build/RE8AgilityBridge-build.json') -Raw|ConvertFrom-Json
$definition=Get-TechDefinition 'Agility'
$proxy=Get-TechPath $GamePath $definition.Target
if($build.schema -ne 1 -or $build.technology -ne 'Agility' -or $build.buildConfiguration -ne 'Release' -or (Get-TechHash $proxy) -ne $build.binarySha256){throw 'Installed Agility proxy differs from the compiled release.'}
$manifestPath=Get-TechPath $GamePath '.RE8Technologies/Agility/install-manifest.json'
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
if($manifest.schema -ne 1 -or $manifest.technology -ne 'Agility' -or $manifest.status -ne 'installed'){throw 'No installed Agility transaction.'}
$expected=@{}; $expected[$definition.Target]=$build.binarySha256
foreach($runtime in $definition.Runtime){$expected[$runtime.Target]=$runtime.Hash}
$seen=@{}
foreach($file in @($manifest.files)){
    if($file.relative -notin (@($expected.Keys)+@('RE8Agility\LICENSE-preview.txt')) -or $seen.ContainsKey($file.relative) -or $file.applied -isnot [bool] -or -not $file.applied -or $file.sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or (Get-TechHash (Get-TechPath $GamePath $file.relative)) -ne $file.sha256){throw 'Installed Agility file/ownership mismatch.'}
    $seen[$file.relative]=$file.sha256
}
foreach($path in $expected.Keys){if(-not $seen.ContainsKey($path) -or $seen[$path] -ne $expected[$path]){throw 'Expected Agility runtime is missing or changed.'}}
$gameHash=Get-TechHash (Get-TechPath $GamePath 're8.exe')
if($gameHash -ne 'B489826FD3E8AEEA0DD0B1C4ADCF35D5C98D1B599EED022623AA73241FE21E3B'){throw 'Record a separate validation for this unaudited game build.'}
$evidence=Get-TechPath $ProjectRoot ('artifacts/runtime/agility-game/verified-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($evidence)|Out-Null
$evidenceLog=Join-Path $evidence 'bridge.log'
Copy-Item -LiteralPath (Get-TechPath $GamePath 'RE8Agility/bridge.log') -Destination $evidenceLog
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $evidence 'install-manifest.json')
$lines=[IO.File]::ReadAllLines($evidenceLog)
$starts=@($lines|Where-Object {$_ -match 'pid=(\d+)\] Bridge startup:'})
if(-not $starts.Count){throw 'No startup record.'}
$start=$starts[-1]; $match=[regex]::Match($start,'pid=(\d+)\]')
$started=[DateTime]::ParseExact($start.Substring(1,23),'yyyy-MM-dd HH:mm:ss.fff',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeLocal).ToUniversalTime()
if($started -lt (Get-Item -LiteralPath $proxy).LastWriteTimeUtc){throw 'Agility evidence predates this installed binary.'}
$bridgePid=[int]$match.Groups[1].Value
$session=@($lines|Where-Object {$_ -match ('pid='+$bridgePid+'\]')})
$activation=@($session|Where-Object {$_ -match 'ACTIVATED SDK 722 before forwarded device creation;'})
$success=@($session|Where-Object {$_ -match 'FIRST_DEVICE HRESULT=0x00000000 active=1 device_sdk=722 .*observed_core_sdk=722'})
$capabilities=@($session|Where-Object {$_ -match 'CAPABILITIES shader_model=0x[0-9A-F]+ raytracing_tier=\d+'})
if(-not $activation.Count -or -not $success.Count -or -not $capabilities.Count){throw 'This session did not confirm an SDK 722 game device/capabilities.'}
if(@($session|Where-Object {$_ -match 'ACTIVATION_NOT_VERIFIED|DECLINED'}).Count){throw 'This session contains an activation failure/decline.'}
$report=[ordered]@{schema=1;technology='Agility';sdkVersion=722;binarySha256=$build.binarySha256;gameExeSha256=$gameHash;
    actualGameActivationVerified=$true;activationBeforeDeviceVerified=$true;deviceSdkVersion=722;observedCoreSdkVersion=722;
    gameplayConfirmed=[bool]$GameplayCompleted;processId=$bridgePid;startupLine=[string]::Copy($start);
    activationLine=[string]::Copy($activation[-1]);successfulDeviceLine=[string]::Copy($success[-1]);capabilityLine=[string]::Copy($capabilities[-1]);
    evidenceDirectory=$evidence;evidenceLogSha256=Get-TechHash $evidenceLog;evidenceManifestSha256=Get-TechHash (Join-Path $evidence 'install-manifest.json');
    buildReceiptSha256=Get-TechHash (Get-TechPath $ProjectRoot 'artifacts/build/RE8AgilityBridge-build.json');testedUtc=[DateTime]::UtcNow.ToString('o');
    scope='Runtime SDK activation and capability readback on the game device; no new DXR/shader engine port'}
Write-TechJson (Get-TechPath $ProjectRoot 'artifacts/build/RE8AgilityBridge-game-test.json') $report
Write-Output "PASS: actual game device SDK=722; capabilities recorded; gameplay confirmation=$([bool]$GameplayCompleted)."
