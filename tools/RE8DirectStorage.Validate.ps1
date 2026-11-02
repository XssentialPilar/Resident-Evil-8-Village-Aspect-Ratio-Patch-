[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GamePath,[switch]$GameplayCompleted,[string]$ProjectRoot)
$ErrorActionPreference='Stop'
if(-not $ProjectRoot){$ProjectRoot=Split-Path -Parent $PSScriptRoot}
. (Join-Path $PSScriptRoot 'RE8Technology.Common.ps1')
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
$GamePath=[IO.Path]::GetFullPath($GamePath)
$build=Get-Content (Get-TechPath $ProjectRoot 'artifacts\build\RE8DirectStorageBridge-build.json') -Raw|ConvertFrom-Json
if($build.schema -ne 1 -or $build.technology -ne 'DirectStorage' -or $build.buildConfiguration -ne 'Release' -or $build.binarySha256 -isnot [string] -or $build.binarySha256 -notmatch '^[a-fA-F0-9]{64}$'){throw 'Invalid DirectStorage build receipt.'}
$binary=Get-TechPath $GamePath 'reframework\plugins\RE8DirectStorage.dll'
if((Get-TechHash $binary) -ne $build.binarySha256){throw 'The installed DLL differs from the tested build.'}
$manifest=Get-Content (Get-TechPath $GamePath '.RE8Technologies\DirectStorage\install-manifest.json') -Raw|ConvertFrom-Json
if($manifest.schema -ne 1 -or $manifest.technology -ne 'DirectStorage' -or $manifest.status -ne 'installed'){throw 'No installed DirectStorage transaction.'}
$definition=Get-TechDefinition 'DirectStorage'
$expectedManifest=@{};$expectedManifest[$definition.Target]=$build.binarySha256
foreach($runtime in $definition.Runtime){$expectedManifest[$runtime.Target]=$runtime.Hash}
$allowedManifest=@($expectedManifest.Keys)+@('RE8DirectStorage\LICENSE-preview.txt','RE8DirectStorage\NOTICES-preview.txt')
$manifestFiles=@{}
foreach($file in @($manifest.files)){
    if($file.relative -isnot [string] -or $file.relative -notin $allowedManifest -or $manifestFiles.ContainsKey($file.relative) -or $file.applied -isnot [bool] -or $file.applied -ne $true -or $file.sha256 -isnot [string] -or $file.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or (Get-TechHash (Get-TechPath $GamePath $file.relative)) -ne $file.sha256){throw 'Installed file differs from the ownership manifest.'}
    $manifestFiles[$file.relative]=$file.sha256
}
foreach($path in $allowedManifest){if(-not $manifestFiles.ContainsKey($path)){throw 'Installed manifest is missing a required file.'}}
foreach($path in $expectedManifest.Keys){if($manifestFiles[$path] -ne $expectedManifest[$path]){throw 'Wrong installed DLL or DirectStorage runtime.'}}
$source=(Get-FileHash (Get-TechPath $GamePath 're8.exe') -Algorithm SHA256).Hash
if($source -ne 'B489826FD3E8AEEA0DD0B1C4ADCF35D5C98D1B599EED022623AA73241FE21E3B'){throw 'This game executable has not been audited; record a separate validation for that build.'}
$logPath=Get-TechPath $GamePath 're2_framework_log.txt'
# Freeze the evidence before selecting counters, so the report and its checksum
# always refer to the SAME archived bytes even if the live log keeps growing.
$evidence=Get-TechPath $ProjectRoot ('artifacts\runtime\directstorage-game\verified-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($evidence)|Out-Null
$evidenceLog=Join-Path $evidence 're2_framework_log.txt'
$evidenceManifest=Join-Path $evidence 'install-manifest.json'
Copy-Item -LiteralPath $logPath -Destination $evidenceLog
Copy-Item -LiteralPath (Get-TechPath $GamePath '.RE8Technologies\DirectStorage\install-manifest.json') -Destination $evidenceManifest
$lines=[IO.File]::ReadAllLines($evidenceLog)
$initialization=-1
for($index=0;$index -lt $lines.Length;$index++){if($lines[$index] -match '\[RE8DirectStorage\] Experimental CPU PAK bridge;'){$initialization=$index}}
if($initialization -lt 0){throw 'No DirectStorage initialization in archived log.'}
$session=@($lines|Select-Object -Skip ($initialization+1))
$marker=@($session|Where-Object {$_ -match '\[RE8DirectStorage\] FIRST REAL PAK READ: DirectStorage bulk bytes'})
if(-not $marker.Count){throw 'No real PAK read marker in the game log.'}
$statistics=@($session|Where-Object {$_ -match '\[RE8DirectStorage\] active=\d+ pak_reads='})
if(-not $statistics.Count){throw 'No DirectStorage game counters.'}
# Windows PowerShell 5.1 Get-Content strings carry provider metadata; copy only
# the text so ConvertTo-Json cannot walk filesystem/provider objects.
$line=[string]::Copy($statistics[-1].ToString())
$values=@{}
foreach($match in [regex]::Matches($line,'([a-z_]+)=(\d+)')){
    $key=$match.Groups[1].Value
    if($values.ContainsKey($key)){throw "Duplicate DirectStorage log counter: $key"}
    $values[$key]=[uint64]::Parse($match.Groups[2].Value)
}
foreach($field in @('active','pak_reads','pak_bytes','timeout_disable','runtime','allocation','copy','verification_reads','verification_errors','verification_mismatch','native_compat_reads','native_compat_errors')){
    if(-not $values.ContainsKey($field)){throw "Missing validation counter: $field"}
}
if($values.active -ne 1 -or $values.pak_reads -lt 64 -or $values.pak_bytes -eq 0 -or $values.verification_reads -lt 64 -or $values.verification_reads -gt $values.pak_reads){throw 'Insufficient active DirectStorage reads/reference comparisons.'}
if($values.native_compat_reads -lt $values.pak_reads){throw 'Native file-state compatibility bookkeeping is incomplete.'}
foreach($field in @('timeout_disable','runtime','allocation','copy','verification_errors','verification_mismatch','native_compat_errors')){
    if($values[$field] -ne 0){throw "Real-game validation failed: $field=$($values[$field])"}
}
if((Get-TechHash $binary) -ne $build.binarySha256 -or (Get-TechHash $evidenceManifest) -ne (Get-TechHash (Get-TechPath $GamePath '.RE8Technologies\DirectStorage\install-manifest.json'))){throw 'Installation changed while evidence was being archived; retry validation.'}
$report=[ordered]@{schema=1;technology='DirectStorage';binarySha256=$build.binarySha256;gameExeSha256=$source;actualGameActivationVerified=$true;
    confirmedReads=$values.pak_reads;confirmedBytes=$values.pak_bytes;nativeVerifiedReads=$values.verification_reads;nativeVerifyMismatches=$values.verification_mismatch;
    referenceErrors=$values.verification_errors;timeouts=$values.timeout_disable;runtimeErrors=$values.runtime;allocationErrors=$values.allocation;copyErrors=$values.copy;
    nativeCompatibilityReads=$values.native_compat_reads;nativeCompatibilityErrors=$values.native_compat_errors;
    gameplayConfirmed=[bool]$GameplayCompleted;counterLogLine=$line;evidenceDirectory=$evidence;evidenceLogSha256=(Get-TechHash $evidenceLog);evidenceManifestSha256=(Get-TechHash $evidenceManifest);
    testedUtc=[DateTime]::UtcNow.ToString('o');scope='Observed nonalertable synchronous read-only PAK file-to-CPU-memory reads; explicit null-event OVERLAPPED supported; original decompression retained';
    gpuDecompression=$false;performanceImprovementVerified=$false;universalCompatibilityVerified=$false}
Write-TechJson (Get-TechPath $ProjectRoot 'artifacts\build\RE8DirectStorageBridge-game-test.json') $report
Write-Output ("PASS: real RE8 PAK reads={0}; bytes={1}; native comparisons={2}; mismatches=0; timeouts=0; runtime errors=0. Gameplay confirmation={3}" -f $values.pak_reads,$values.pak_bytes,$values.verification_reads,[bool]$GameplayCompleted)
