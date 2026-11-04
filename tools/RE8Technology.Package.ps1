[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('Agility','DirectStorage')][string]$Technology,[string]$ProjectRoot,[switch]$ValidateOnly,[switch]$Candidate,[ValidateSet('1.0.0','2.7.0')][string]$PackageVersion='1.0.0')
if (-not $ProjectRoot) { $ProjectRoot=Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'RE8Technology.Common.ps1')
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
$definition=Get-TechDefinition $Technology
$stem=if($Technology -eq 'Agility'){'agility'}else{'directstorage'}
$receiptName=if($Technology -eq 'Agility'){'RE8AgilityBridge-build.json'}else{'RE8DirectStorageBridge-build.json'}
$receipt=Get-Content -LiteralPath (Get-TechPath $ProjectRoot ('artifacts\build\'+$receiptName)) -Raw | ConvertFrom-Json
$expectedBinary=Get-TechPath $ProjectRoot ('artifacts\'+$stem+'-bridge\Release\'+$definition.Binary)
if ($receipt.schema -ne 1 -or $receipt.technology -ne $Technology -or $receipt.buildConfiguration -ne 'Release' -or [IO.Path]::GetFullPath($receipt.binary) -ne $expectedBinary -or (Get-TechHash $expectedBinary) -ne $receipt.binarySha256) { throw 'Stale or invalid bridge build receipt.' }
$gameVerified=$false
if($Technology -eq 'Agility' -and -not $Candidate) {
    $proof=Get-Content -LiteralPath (Get-TechPath $ProjectRoot 'artifacts/build/RE8AgilityBridge-game-test.json') -Raw|ConvertFrom-Json
    if($proof.schema -ne 1 -or $proof.technology -ne 'Agility' -or $proof.binarySha256 -ne $receipt.binarySha256 -or
        $proof.actualGameActivationVerified -isnot [bool] -or -not $proof.actualGameActivationVerified -or
        $proof.gameplayConfirmed -isnot [bool] -or -not $proof.gameplayConfirmed -or $proof.deviceSdkVersion -ne 722 -or
        $proof.gameExeSha256 -ne 'B489826FD3E8AEEA0DD0B1C4ADCF35D5C98D1B599EED022623AA73241FE21E3B') {
        throw 'Final Agility packaging requires SDK confirmation and user gameplay confirmation for this exact DLL.'
    }
    $evidenceBase=Get-TechPath $ProjectRoot 'artifacts/runtime/agility-game'
    $evidence=[IO.Path]::GetFullPath($proof.evidenceDirectory).TrimEnd('\','/')
    if(-not $evidence.StartsWith($evidenceBase+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Agility evidence is outside this project archive.'}
    $evidence=Get-TechPath $ProjectRoot $evidence.Substring($ProjectRoot.TrimEnd('\','/').Length+1)
    $log=Get-TechPath $evidence 'bridge.log'; $manifest=Get-TechPath $evidence 'install-manifest.json'
    if((Get-TechHash $log) -ne $proof.evidenceLogSha256 -or (Get-TechHash $manifest) -ne $proof.evidenceManifestSha256 -or
        (Get-TechHash (Get-TechPath $ProjectRoot 'artifacts/build/RE8AgilityBridge-build.json')) -ne $proof.buildReceiptSha256){throw 'Agility evidence/build checksum mismatch.'}
    $lines=[IO.File]::ReadAllLines($log)
    if($proof.successfulDeviceLine -notin $lines -or $proof.activationLine -notin $lines -or $proof.capabilityLine -notin $lines -or
        $proof.successfulDeviceLine -notmatch 'FIRST_DEVICE HRESULT=0x00000000 active=1 device_sdk=722 .*observed_core_sdk=722') {throw 'Agility device evidence mismatch.'}
    $installed=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
    foreach($path in @($definition.Target)+@($definition.Runtime|ForEach-Object Target)) {
        $entry=@($installed.files|Where-Object relative -eq $path)
        $hash=if($path -eq $definition.Target){$receipt.binarySha256}else{($definition.Runtime|Where-Object Target -eq $path).Hash}
        if($entry.Count -ne 1 -or $entry[0].applied -isnot [bool] -or -not $entry[0].applied -or $entry[0].sha256 -ne $hash){throw 'Agility archived installation identity mismatch.'}
    }
    $gameVerified=$true
}
if($Candidate -and $Technology -eq 'DirectStorage' -and -not $receipt.harnessVerified) { throw 'Candidate packaging still requires isolated harness verification.' }
if($Technology -eq 'DirectStorage' -and -not $Candidate) {
    # Integrity checks against accidental stale/edited receipts. These local
    # artifacts are not a cryptographic attestation against a fabricated set.
    function Read-ValidationUInt($Object,[string]$Name) {
        $property=$Object.PSObject.Properties[$Name]
        if(-not $property){throw "Missing integer validation field: $Name"}
        $value=$property.Value
        if(-not ($value -is [byte] -or $value -is [sbyte] -or $value -is [int16] -or $value -is [uint16] -or $value -is [int32] -or $value -is [uint32] -or $value -is [int64] -or $value -is [uint64]) -or $value -lt 0){throw "Validation field must be a nonnegative integer: $Name"}
        return [uint64]$value
    }
    function Assert-ValidationTrue($Object,[string]$Name) {
        $property=$Object.PSObject.Properties[$Name]
        if(-not $property -or $property.Value -isnot [bool] -or $property.Value -ne $true){throw "Validation field must be boolean true: $Name"}
    }
    $gameTestPath=Get-TechPath $ProjectRoot 'artifacts\build\RE8DirectStorageBridge-game-test.json'
    if(-not (Test-Path -LiteralPath $gameTestPath -PathType Leaf)) { throw 'Final DirectStorage packaging requires a real-game validation receipt for this exact binary. Use a private staging folder for diagnostic candidates.' }
    $gameTest=Get-Content -LiteralPath $gameTestPath -Raw|ConvertFrom-Json
    if((Read-ValidationUInt $gameTest 'schema') -ne 1 -or $gameTest.technology -isnot [string] -or $gameTest.technology -ne 'DirectStorage' -or $gameTest.binarySha256 -isnot [string] -or $gameTest.binarySha256 -ne $receipt.binarySha256 -or $gameTest.gameExeSha256 -isnot [string] -or $gameTest.gameExeSha256 -ne 'B489826FD3E8AEEA0DD0B1C4ADCF35D5C98D1B599EED022623AA73241FE21E3B'){throw 'Game validation identity differs from the audited executable/compiled DLL.'}
    Assert-ValidationTrue $gameTest 'actualGameActivationVerified'
    Assert-ValidationTrue $gameTest 'gameplayConfirmed'
    if($gameTest.evidenceDirectory -isnot [string] -or $gameTest.evidenceLogSha256 -isnot [string] -or $gameTest.evidenceLogSha256 -notmatch '^[a-fA-F0-9]{64}$' -or $gameTest.counterLogLine -isnot [string]){throw 'Invalid archived evidence fields.'}
    $evidenceBase=Get-TechPath $ProjectRoot 'artifacts\runtime\directstorage-game'
    $evidenceFull=[IO.Path]::GetFullPath($gameTest.evidenceDirectory).TrimEnd('\','/')
    if(-not $evidenceFull.StartsWith($evidenceBase+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Game evidence must be inside this project archive.'}
    $projectBase=$ProjectRoot.TrimEnd('\','/')
    $evidence=Get-TechPath $projectBase $evidenceFull.Substring($projectBase.Length+1)
    $evidenceLog=Get-TechPath $evidence 're2_framework_log.txt'
    if((Get-TechHash $evidenceLog) -ne $gameTest.evidenceLogSha256){throw 'Archived game log checksum mismatch.'}
    $lines=[IO.File]::ReadAllLines($evidenceLog)
    $initialization=-1
    for($index=0;$index -lt $lines.Length;$index++){if($lines[$index] -match '\[RE8DirectStorage\] Experimental CPU PAK bridge;'){$initialization=$index}}
    if($initialization -lt 0){throw 'Archived log has no DirectStorage initialization.'}
    $session=@($lines | Select-Object -Skip ($initialization+1))
    $markers=@($session|Where-Object {$_ -match '\[RE8DirectStorage\] FIRST REAL PAK READ: DirectStorage bulk bytes'})
    $statistics=@($session|Where-Object {$_ -match '\[RE8DirectStorage\] active=\d+ pak_reads='})
    if(-not $markers.Count -or -not $statistics.Count -or $statistics[-1] -cne $gameTest.counterLogLine){throw 'Receipt does not match the latest archived session counter line.'}
    $values=@{}
    foreach($match in [regex]::Matches($statistics[-1],'([a-z_]+)=(\d+)')){
        $key=$match.Groups[1].Value
        if($values.ContainsKey($key)){throw "Duplicate log counter: $key"}
        $values[$key]=[uint64]::Parse($match.Groups[2].Value)
    }
    $counterFields=@{confirmedReads='pak_reads';confirmedBytes='pak_bytes';nativeVerifiedReads='verification_reads';nativeVerifyMismatches='verification_mismatch';referenceErrors='verification_errors';timeouts='timeout_disable';runtimeErrors='runtime';allocationErrors='allocation';copyErrors='copy';nativeCompatibilityReads='native_compat_reads';nativeCompatibilityErrors='native_compat_errors'}
    foreach($field in $counterFields.Keys){
        $counter=$counterFields[$field]
        if(-not $values.ContainsKey($counter) -or (Read-ValidationUInt $gameTest $field) -ne $values[$counter]){throw "Receipt/log counter mismatch: $field"}
    }
    if(-not $values.ContainsKey('active') -or $values.active -ne 1 -or $values.pak_reads -lt 64 -or $values.pak_bytes -eq 0 -or $values.verification_reads -lt 64 -or $values.verification_reads -gt $values.pak_reads -or $values.native_compat_reads -lt $values.pak_reads){throw 'Insufficient active, verified, file-state-compatible PAK reads.'}
    foreach($counter in @('timeout_disable','runtime','allocation','copy','verification_errors','verification_mismatch','native_compat_errors')){if($values[$counter] -ne 0){throw "Nonzero game error counter: $counter"}}
    $manifestPath=Get-TechPath $evidence 'install-manifest.json'
    $manifestHashProperty=$gameTest.PSObject.Properties['evidenceManifestSha256']
    if($manifestHashProperty -and ($manifestHashProperty.Value -isnot [string] -or $manifestHashProperty.Value -ne (Get-TechHash $manifestPath))){throw 'Archived manifest checksum mismatch.'}
    $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
    if((Read-ValidationUInt $manifest 'schema') -ne 1 -or $manifest.technology -isnot [string] -or $manifest.technology -ne 'DirectStorage' -or $manifest.status -isnot [string] -or $manifest.status -ne 'installed'){throw 'Archived manifest is not an installed DirectStorage transaction.'}
    $expectedManifest=@{}
    $expectedManifest[$definition.Target]=$receipt.binarySha256
    foreach($runtimeFile in $definition.Runtime){$expectedManifest[$runtimeFile.Target]=$runtimeFile.Hash}
    $allowedManifest=@($expectedManifest.Keys)+@('RE8DirectStorage\LICENSE-preview.txt','RE8DirectStorage\NOTICES-preview.txt')
    $manifestFiles=@{}
    foreach($file in @($manifest.files)){
        if($file.relative -isnot [string] -or $file.relative -notin $allowedManifest -or $manifestFiles.ContainsKey($file.relative) -or $file.sha256 -isnot [string] -or $file.sha256 -notmatch '^[a-fA-F0-9]{64}$'){throw 'Invalid or duplicate archived manifest path/hash.'}
        Assert-ValidationTrue $file 'applied'
        $manifestFiles[$file.relative]=$file.sha256
    }
    foreach($path in $allowedManifest){if(-not $manifestFiles.ContainsKey($path)){throw 'Archived manifest is missing an installed file.'}}
    foreach($path in $expectedManifest.Keys){if($manifestFiles[$path] -ne $expectedManifest[$path]){throw 'Archived manifest does not identify the compiled DLL/expected runtimes.'}}
    $gameVerified=$true
}
if (@($receipt.sources).Count -lt 2) { throw 'Incomplete source receipt.' }
$seen=@{}
foreach($source in $receipt.sources) {
    $reviewedHeader=$Technology -eq 'DirectStorage' -and $source.path -eq 'artifacts/dependencies/directstorage-1.4-preview-inventory/native/include/dstorage.h' -and $source.sha256 -eq 'ED5CCC1C84C57FC35EE13708DE1044F08E18B623D083F991BF85C420C8623D78'
    if ($seen.ContainsKey($source.path) -or (-not $reviewedHeader -and $source.path -notmatch '^(native/(agility_bridge|directstorage_bridge)/|tools/RE8(Agility|DirectStorage)Bridge\.Build\.ps1$|external/reframework-sdk/)') -or (Get-TechHash (Get-TechPath $ProjectRoot $source.path)) -ne $source.sha256) { throw 'Bridge source mismatch.' }
    $seen[$source.path]=$true
}
if($ValidateOnly){Write-Output 'PASS: bridge build/source and archived game validation integrity checks; no ZIP created.';return}
$stage=Get-TechPath $ProjectRoot ('artifacts\'+$stem+'-game-package-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $stage 'payload')) | Out-Null
Copy-Item -LiteralPath $expectedBinary -Destination (Join-Path $stage ('payload\'+$definition.Binary))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'RE8Technology.Common.ps1') -Destination (Join-Path $stage 'common.ps1')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'RE8Technology.Install.ps1') -Destination (Join-Path $stage 'install.ps1')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'RE8Technology.Uninstall.ps1') -Destination (Join-Path $stage 'uninstall.ps1')
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'LICENSE') -Destination (Join-Path $stage 'LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $ProjectRoot ('docs\'+$Technology+'Bridge-README.md')) -Destination (Join-Path $stage 'README.md')
if($Candidate -or $PackageVersion -eq '2.7.0') {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot ('docs\'+$Technology+'Bridge-2.7.0.md')) -Destination (Join-Path $stage 'README.md') -Force
}
if($Technology -eq 'DirectStorage') {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot 'artifacts\dependencies\directstorage-1.4-preview-inventory\LICENSE-CODE.txt') -Destination (Join-Path $stage 'MICROSOFT-HEADERS-MIT.txt')
}
Write-TechJson (Join-Path $stage 'package.json') ([ordered]@{schema=1;technology=$Technology;version=$(if($Candidate){'2.7.0-candidate'}else{$PackageVersion});binary=('payload/'+$definition.Binary);binarySha256=$receipt.binarySha256;privatePreviewTesting=$true;runtimeRedistributed=$false;actualGameActivationVerified=$gameVerified})
$zipName=if($Technology -eq 'Agility'){'RE8Agility-722-Game.zip'}else{'RE8DirectStorage-1.4-Game.zip'}
if($Candidate) { $zipName=if($Technology -eq 'Agility'){'RE8Agility-722-Game-2.7.0-candidate.zip'}else{'RE8DirectStorage-1.4-Game-2.7.0-candidate.zip'} }
elseif($PackageVersion -eq '2.7.0') { $zipName=if($Technology -eq 'Agility'){'RE8Agility-722-Game-2.7.0.zip'}else{'RE8DirectStorage-1.4-Game-2.7.0.zip'} }
$zip=Get-TechPath $ProjectRoot ('dist\'+$zipName)
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($zip)) | Out-Null
$temporary=$zip+'.pending'
if (Test-Path -LiteralPath $temporary) { throw 'An unfinished archive exists.' }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($stage,$temporary,[IO.Compression.CompressionLevel]::Optimal,$false)
$archive=[IO.Compression.ZipFile]::OpenRead($temporary)
try {
    $expected=@(('payload/'+$definition.Binary),'common.ps1','install.ps1','uninstall.ps1','LICENSE.txt','README.md','package.json')
    if($Technology -eq 'DirectStorage'){$expected+= 'MICROSOFT-HEADERS-MIT.txt'}
    $actual=@($archive.Entries | ForEach-Object {$_.FullName.Replace('\','/')})
    if(@(Compare-Object $expected $actual).Count) { throw 'Unexpected game archive contents.' }
} finally { $archive.Dispose() }
Move-Item -LiteralPath $temporary -Destination $zip -Force
$hash=Get-TechHash $zip
[IO.File]::WriteAllText(($zip+'.sha256'),($hash+'  '+$zipName+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
Write-TechJson (Get-TechPath $ProjectRoot ('artifacts\build\RE8'+$Technology+'Bridge-package.json')) ([ordered]@{schema=1;technology=$Technology;directory=$stage;archive=$zip;sha256=$hash;binarySha256=$receipt.binarySha256;runtimeRedistributed=$false;actualGameActivationVerified=$gameVerified})
Write-Output "Game module package: $zip"
Write-Output "Staging: $stage"
Write-Output "SHA256: $hash"
