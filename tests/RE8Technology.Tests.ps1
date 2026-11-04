[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$AgilityPackageRoot,[string]$DirectStoragePackageRoot)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$root=Join-Path $project ('artifacts\tests\technology-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$script:checks=0
function Assert-Test($Condition,[string]$Message){if(-not $Condition){throw $Message};$script:checks++}
function Expect-Refusal([scriptblock]$Action,[string]$Message){$failed=$false;try{&$Action | Out-Null}catch{$failed=$true};Assert-Test $failed $Message}
function New-Game([string]$Name){$path=Join-Path $root $Name;[IO.Directory]::CreateDirectory($path)|Out-Null;[IO.File]::WriteAllText((Join-Path $path 're8.exe'),'fixture');[IO.File]::WriteAllText((Join-Path $path 'dinput8.dll'),'foreign host');return $path}
function Exercise-Technology([string]$Package,[string]$Technology,[string]$NuGet){
    $game=New-Game $Technology
    $install=Join-Path $Package 'install.ps1';$uninstall=Join-Path $Package 'uninstall.ps1'
    & $install -GamePath $game -PackagePath $NuGet -AcceptPreviewLicense | Out-Null
    $manifest=Join-Path $game ('.RE8Technologies\'+$Technology+'\install-manifest.json')
    $state=Get-Content $manifest -Raw|ConvertFrom-Json
    Assert-Test ($state.status -eq 'installed') 'Installation status'
    foreach($file in $state.files){Assert-Test ((Get-FileHash (Join-Path $game $file.relative)).Hash -eq $file.sha256) 'Installed exact bytes'}
    Assert-Test ([IO.File]::ReadAllText((Join-Path $game 'dinput8.dll')) -eq 'foreign host') 'Existing host preserved'
    Expect-Refusal {& $install -GamePath $game -PackagePath $NuGet -AcceptPreviewLicense} 'Duplicate transaction refused'
    $owned=Join-Path $game $state.files[0].relative
    $backup=[IO.File]::ReadAllBytes($owned);[IO.File]::WriteAllText($owned,'modified by owner')
    Expect-Refusal {& $uninstall -GamePath $game} 'Modified runtime removal refused'
    Assert-Test (Test-Path $manifest) 'Manifest retained after refusal'
    [IO.File]::WriteAllBytes($owned,$backup)
    & $uninstall -GamePath $game | Out-Null
    Assert-Test (-not (Test-Path $manifest)) 'Manifest retired after removal'
    foreach($file in $state.files){Assert-Test (-not (Test-Path (Join-Path $game $file.relative))) 'Owned file removed'}
    Assert-Test (Test-Path (Join-Path $game 'dinput8.dll')) 'Host survives removal'
    Expect-Refusal {& $install -GamePath $game -PackagePath (Join-Path $game 're8.exe') -AcceptPreviewLicense} 'Wrong package refused'
    Assert-Test (-not (Test-Path $manifest)) 'No transaction on wrong package'
    function Get-Process { [pscustomobject]@{Path=(Join-Path $game 're8.exe')} }
    Expect-Refusal {& $install -GamePath $game -PackagePath $NuGet -AcceptPreviewLicense} 'Running game refused'
    Remove-Item Function:\Get-Process
    Assert-Test (-not (Test-Path $manifest)) 'No transaction while running'
}
$agilityNuGet=Join-Path $project 'external/packages/microsoft.direct3d.d3d12.1.722.0-preview.nupkg'
Exercise-Technology $AgilityPackageRoot 'Agility' $agilityNuGet
$foreign=New-Game 'foreign-proxy';[IO.File]::WriteAllText((Join-Path $foreign 'd3d12.dll'),'other mod')
Expect-Refusal {& (Join-Path $AgilityPackageRoot 'install.ps1') -GamePath $foreign -PackagePath $agilityNuGet -AcceptPreviewLicense} 'Foreign proxy refused'
Assert-Test ([IO.File]::ReadAllText((Join-Path $foreign 'd3d12.dll')) -eq 'other mod') 'Foreign proxy untouched'
Assert-Test (-not (Test-Path (Join-Path $foreign 'RE8Agility\D3D12\D3D12Core.dll'))) 'No partial runtime on refusal'
if($DirectStoragePackageRoot){
    $dsNuGet=Join-Path $project 'external/packages/microsoft.direct3d.directstorage.1.4.0-preview1-2603.504.nupkg'
    Exercise-Technology $DirectStoragePackageRoot 'DirectStorage' $dsNuGet
    $rollback=New-Game 'rollback';[IO.Directory]::CreateDirectory((Join-Path $rollback 'reframework'))|Out-Null
    [IO.File]::WriteAllText((Join-Path $rollback 'reframework\plugins'),'foreign obstruction')
    Expect-Refusal {& (Join-Path $DirectStoragePackageRoot 'install.ps1') -GamePath $rollback -PackagePath $dsNuGet -AcceptPreviewLicense} 'Mid-copy filesystem failure refused'
    Assert-Test (-not (Test-Path (Join-Path $rollback 'RE8DirectStorage\dstorage.dll'))) 'Runtime rolled back'
    Assert-Test ([IO.File]::ReadAllText((Join-Path $rollback 'reframework\plugins')) -eq 'foreign obstruction') 'Foreign obstruction preserved'
    & (Join-Path $DirectStoragePackageRoot 'uninstall.ps1') -GamePath $rollback | Out-Null
    Assert-Test (-not (Test-Path (Join-Path $rollback '.RE8Technologies\DirectStorage\install-manifest.json'))) 'Rolled-back transaction recoverable'
}
Write-Output "PASS: $script:checks technology installation/recovery checks. Fixtures: $root"
