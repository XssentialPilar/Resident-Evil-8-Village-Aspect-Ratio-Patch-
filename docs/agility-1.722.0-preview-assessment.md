# Local Agility SDK 1.722.0-preview assessment

Inspected on 2 November 2026. This is an inventory and integration assessment. A later isolated compatibility test loaded the runtime in its own diagnostic process; no Agility runtime was enabled in RE8 or copied into the game or public patch ZIP.

## Local package evidence

The user-provided `microsoft.direct3d.d3d12.1.722.0-preview.nupkg` is 35,693,306 bytes. SHA256:

`BF9915DBB39F7C97018D42B36E65469F11C864B805E3BC9A773EBA364208CDC3`

The nuspec identifies Microsoft.Direct3D.D3D12, version 1.722.0-preview, author Microsoft. `dotnet nuget verify --all` succeeded with exit 0, verifying Microsoft author and NuGet repository signatures. Every extracted x64 EXE/DLL has a valid Microsoft Authenticode signature. Microsoft lists this preview as SDK version 722, released 28 October 2026. [Official downloads](https://devblogs.microsoft.com/directx/directx12agility/)

The package contains x64, win32 and arm64 binaries, development headers, symbols, MSBuild props/targets and two different licenses. Only the x64 binaries and text metadata were extracted, into the ignored local `artifacts/dependencies/agility-1.722.0-preview-inventory/` directory, for static inspection. `package-inventory.json` records each archive entry's size/hash; `x64-inventory.json` records versions and signatures.

| x64 file | Bytes | SHA256 |
| --- | ---: | --- |
| D3D12Core.dll | 4,992,296 | 1A588965B12422DB5DF18F9331E244616F4F7A3893DB83A4C578F7DE50A36F13 |
| d3d12SDKLayers.dll | 5,987,128 | 813EF7D06BC052D74E690ACF1A40878932A280A34767998837D6C39E74CD7EAB |
| D3D12StateObjectCompiler.dll | 3,319,600 | 674E0F3E3D80782D6BBE76C3FA2AB1B8D693711E8B4760B6C3CC9C91B6CC014B |
| D3D12StateObjectCompiler.exe | 1,318,680 | 9B5F581EA742DDB6B85F8E5283AF86397AE05496BA0CF7488EA95B7FE13687BC |
| d3dconfig.exe | 747,832 | C284F867FD16439BE4482CC69001704C6BC19C7E069CC32FFBA30678367D578D |

The three DLLs and d3dconfig.exe report file/product version `1.722.0.0.20261026.2`; the compiler EXE has no version resource. D3D12Core is PE x64. Its exported `D3D12SDKVersion` data was read directly from the file's PE section mapping, without loading the DLL, and equals 722. The package header defines both `D3D12_PREVIEW_SDK_VERSION` 722 and retail `D3D12_SDK_VERSION` 620.

## Licensing distinction

The package README explicitly assigns `LICENSE.txt` to `build/native/bin/` and MIT `LICENSE-CODE.txt` to `build/native/include/`. The runtime license supplied in this preview contains time-sensitive pre-release terms and a prohibition on distribution/transfer in section 4(e). The MIT header license does not grant redistribution rights for these runtime binaries. This preview must not be added to a public mod ZIP on an assumption that its DLLs are MIT-licensed. [Package README and metadata](https://www.nuget.org/packages/Microsoft.Direct3D.D3D12/1.722.0-preview)

## Loader and device lifetime

The normal Agility loader selects its runtime from version/path data exported by the process's main executable. Exporting those symbols from our plugin does not meet that contract. An engine opted into Agility also needs matching runtime files in its chosen subdirectory; the debug layer is a development component. [Microsoft getting-started guide](https://devblogs.microsoft.com/directx/gettingstarted-dx12agility/)

`ID3D12SDKConfiguration::SetSDKVersion` is restricted to Windows Developer Mode and must run before device creation. Microsoft documents that calling it after a Direct3D 12 device exists removes that device. It is therefore unsuitable for RE8Display's late plugin initialization or a settings-menu toggle. [SetSDKVersion contract](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/nf-d3d12-id3d12sdkconfiguration-setsdkversion)

The newer `CreateDeviceFactory` route can load a side-by-side runtime without Developer Mode for newly created independent devices. It does not convert an existing game device or its resources. Its `ApplyToGlobalState` operation can remove existing singleton devices, so that is also unsuitable for changing RE8's active runtime. [Microsoft independent-device specification](https://microsoft.github.io/DirectX-Specs/d3d/IndependentDevices.html)

## Windows requirements and conclusion

The general Agility loader is supported on Windows 10 1909 and newer with the applicable servicing updates: 1909 revision 1350, or 2004/20H2 revision 789 and newer. The SetSDKVersion reference separately lists minimum build 20348 for that API. These are loader/API prerequisites, not proof that every preview feature works on every supported OS, driver or GPU. No compatibility experiment with this runtime was performed.

Engineering conclusion: merely adding this package cannot correct the game's camera projection or repair an invalid engine scene/viewport state. Safely replacing the game's D3D12 runtime would require a separate integration design before device creation, explicit ownership of the startup path and an appropriate redistribution license. RE8Display 2.5.0 should address its actual projection/invocation/lifecycle faults while retaining the game's existing device and runtime.

## Subsequent isolated runtime test

At 15:15:56 America/Santo_Domingo on 2 November 2026, the separate RE8AgilityProbe executable created a hardware device on NVIDIA GeForce RTX 5050 Laptop GPU. D3D12CreateDevice and GetDeviceRemovedReason returned S_OK. The loaded D3D12Core path was the private kit directory and its exported SDK version was 722; process exit code 0. The original package was verified and its core staged only beside the probe. The result is recorded in `artifacts/build/RE8Agility-runtime-test.json` and the associated `probe-result.txt`.

This proves a healthy SDK 722 device in that diagnostic process. It does not enable the runtime in RE8, exercise its renderer, establish improved performance, or remove the startup and distribution constraints described above.
