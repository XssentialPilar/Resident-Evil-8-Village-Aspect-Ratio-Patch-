[CmdletBinding()]
param([string]$ProjectRoot,[string]$Generator='Visual Studio 18 2026')
$ErrorActionPreference='Stop'
if (-not $ProjectRoot) { $ProjectRoot=Split-Path -Parent $PSScriptRoot }
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
. (Join-Path $PSScriptRoot 'RE8Display.Common.ps1')
$source=Join-Path $ProjectRoot 'native\agility_bridge'
$build=Join-Path $ProjectRoot 'artifacts\agility-bridge'
$generated=Join-Path $build 'generated'
[IO.Directory]::CreateDirectory($generated) | Out-Null
$systemDll=Join-Path ([Environment]::SystemDirectory) 'd3d12.dll'
$image=[IO.File]::ReadAllBytes($systemDll)
function U16([int]$offset) { [BitConverter]::ToUInt16($image,$offset) }
function U32([int]$offset) { [BitConverter]::ToUInt32($image,$offset) }
$pe=[int](U32 0x3c)
if ((U32 $pe) -ne 0x4550 -or (U16 ($pe+4)) -ne 0x8664) { throw 'Expected x64 system D3D12 PE.' }
$sections=U16 ($pe+6)
$optional=$pe+24
if ((U16 $optional) -ne 0x20b) { throw 'Expected PE32+.' }
$sectionTable=$optional+(U16 ($pe+20))
function Rva([uint32]$rva) {
    for ($index=0;$index -lt $sections;$index++) {
        $section=$sectionTable+40*$index
        $address=U32 ($section+12)
        $size=[Math]::Max((U32 ($section+8)),(U32 ($section+16)))
        if ($rva -ge $address -and $rva -lt ($address+$size)) { return [int]((U32 ($section+20))+$rva-$address) }
    }
    throw "Unmapped PE RVA $rva"
}
function CString([int]$offset) {
    $end=$offset
    while ($end -lt $image.Length -and $image[$end] -ne 0) { $end++ }
    if ($end -eq $image.Length) { throw 'Unterminated export name.' }
    [Text.Encoding]::ASCII.GetString($image,$offset,$end-$offset)
}
$exports=Rva (U32 ($optional+112))
$ordinalBase=U32 ($exports+16)
$functionCount=U32 ($exports+20)
$nameCount=U32 ($exports+24)
$functions=Rva (U32 ($exports+28))
$names=Rva (U32 ($exports+32))
$ordinals=Rva (U32 ($exports+36))
$namesByIndex=@{}
for ($index=0;$index -lt $nameCount;$index++) {
    $name=CString (Rva (U32 ($names+4*$index)))
    if ($name -notmatch '^[A-Za-z_][A-Za-z_0-9]*$') { throw "Unsupported export name syntax: $name" }
    $functionIndex=[int](U16 ($ordinals+2*$index))
    if ($namesByIndex.ContainsKey($functionIndex)) { throw 'Aliased system export requires explicit review.' }
    $namesByIndex[$functionIndex]=$name
}
$entries=@()
for ($index=0;$index -lt $functionCount;$index++) {
    if ((U32 ($functions+4*$index)) -eq 0) { continue }
    $name=$null
    if ($namesByIndex.ContainsKey([int]$index)) { $name=$namesByIndex[[int]$index] }
    $entries += [pscustomobject]@{ordinal=[int]($ordinalBase+$index);name=$name}
}
$typed=@{
    D3D12CreateDevice='BridgeD3D12CreateDevice'
    D3D12GetDebugInterface='BridgeD3D12GetDebugInterface'
    D3D12GetInterface='BridgeD3D12GetInterface'
    D3D12EnableExperimentalFeatures='BridgeD3D12EnableExperimentalFeatures'
}
foreach ($required in $typed.Keys) { if ($required -notin $entries.name) { throw "Required system export missing: $required" } }
$definition=@('LIBRARY d3d12','EXPORTS')
$assembly=@('option casemap:none','EXTERN AgilityResolveExport:PROC','.code')
$header=@('#pragma once','struct BridgeExport { unsigned ordinal; const char* name; };','inline constexpr BridgeExport bridge_exports[] = {')
foreach ($entry in $entries) {
    $symbol='AgilityForward_'+$entry.ordinal
    if ($entry.name -and $typed.ContainsKey($entry.name)) { $symbol=$typed[$entry.name] }
    else {
        # Win64 tail-forwarding preserves all argument registers and original
        # stack arguments. Undocumented exports never receive guessed C types.
        $assembly += @(
            "$symbol PROC FRAME",'    sub rsp, 0A8h','    .allocstack 0A8h','    .endprolog',
            '    mov [rsp+20h], rcx','    mov [rsp+28h], rdx','    mov [rsp+30h], r8','    mov [rsp+38h], r9',
            '    movdqu [rsp+40h], xmm0','    movdqu [rsp+50h], xmm1','    movdqu [rsp+60h], xmm2',
            '    movdqu [rsp+70h], xmm3','    movdqu [rsp+80h], xmm4','    movdqu [rsp+90h], xmm5',
            ('    mov ecx, '+$entry.ordinal),'    call AgilityResolveExport','    mov r11, rax',
            '    mov rcx, [rsp+20h]','    mov rdx, [rsp+28h]','    mov r8, [rsp+30h]','    mov r9, [rsp+38h]',
            '    movdqu xmm0, [rsp+40h]','    movdqu xmm1, [rsp+50h]','    movdqu xmm2, [rsp+60h]',
            '    movdqu xmm3, [rsp+70h]','    movdqu xmm4, [rsp+80h]','    movdqu xmm5, [rsp+90h]',
            '    add rsp, 0A8h','    jmp r11',"$symbol ENDP"
        )
    }
    if ($entry.name) {
        $definition += ('    '+$entry.name+'='+$symbol+' @'+$entry.ordinal)
        $header += ('    {'+$entry.ordinal+', "'+$entry.name+'"},')
    } else {
        $definition += ('    '+$symbol+' @'+$entry.ordinal+' NONAME')
        $header += ('    {'+$entry.ordinal+', nullptr},')
    }
}
$assembly += 'END'
$header += '};'
$encoding=New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllLines((Join-Path $generated 'd3d12.def'),$definition,$encoding)
[IO.File]::WriteAllLines((Join-Path $generated 'forwarders.asm'),$assembly,$encoding)
[IO.File]::WriteAllLines((Join-Path $generated 'system_exports.hpp'),$header,$encoding)
function Sources {
    @(@(Get-ChildItem -LiteralPath $source -File) + @(Get-Item -LiteralPath $PSCommandPath) | Sort-Object FullName | ForEach-Object {
        [ordered]@{path=$_.FullName.Substring($ProjectRoot.Length+1).Replace('\','/');sha256=Get-RE8Hash $_.FullName}
    })
}
$sources=@(Sources)
$snapshot=ConvertTo-Json -InputObject $sources -Compress
& cmake -S $source -B $build -G $Generator -A x64 "-DBRIDGE_GENERATED_DIR=$generated"
if ($LASTEXITCODE -ne 0) { throw 'Agility bridge configuration failed.' }
& cmake --build $build --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'Agility bridge compilation failed.' }
if ($snapshot -ne (ConvertTo-Json -InputObject @(Sources) -Compress)) { throw 'Bridge sources changed during compilation; rebuild.' }
$binary=Join-Path $build 'Release\d3d12.dll'
$testHost=Join-Path $build 'Release\RE8AgilityBridgeTestHost.exe'
& $testHost --selftest
if ($LASTEXITCODE -ne 0) { throw 'Agility bridge export selftest failed.' }
Write-RE8Json (Join-Path $ProjectRoot 'artifacts\build\RE8AgilityBridge-build.json') ([ordered]@{
    schema=1;technology='Agility';sdkVersion=722;buildConfiguration='Release';binary=$binary
    binarySha256=Get-RE8Hash $binary;sources=$sources;systemD3D12Sha256=Get-RE8Hash $systemDll
    systemExports=$entries;testHost=$testHost;exportSelftest='passed; no device created'
    builtUtc=[DateTime]::UtcNow.ToString('o');gameIntegrationRuntimeVerified=$false
})
Write-Output "Compiled early Agility bridge: $binary"
