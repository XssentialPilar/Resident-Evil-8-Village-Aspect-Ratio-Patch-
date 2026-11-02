# Agility 722 and RE8 — integration feasibility

This assessment distinguishes the separate compatibility probe from integration into the game's renderer. The probe does not enable Agility in RE8.

## Evidence from this game installation

Static inspection of the installed Windows x64 `re8.exe` completed successfully with `dumpbin /headers /exports`. The executable is 214,973,416 bytes, reports version `1,2,3,9`, and has SHA256 `B489826FD3E8AEEA0DD0B1C4ADCF35D5C98D1B599EED022623AA73241FE21E3B`. Its PE export table declares 351 names. Neither `D3D12SDKVersion` nor `D3D12SDKPath` is exported.

A recursive filename inventory found no D3D12-named files inside the game folder. The running game's module inventory showed `C:\WINDOWS\SYSTEM32\d3d12.dll` and `C:\WINDOWS\SYSTEM32\D3D12Core.dll`, alongside the official REFramework loader and our plugin. This establishes that the observed game session uses the system runtime. It does not establish how every other build or mod configuration behaves.

The static dump and structured evidence are retained locally under `artifacts/dependencies/agility-1.722.0-preview-inventory/re8-static-exports.txt` and `re8-integration-evidence.json`. Inspection did not modify the game or its process.

## Why adding DLLs or plugin exports is insufficient

Microsoft's normal loader contract reads the version/path exports from the process's main executable. Exporting those values from RE8Display.dll does not opt the game executable into Agility. Copying a runtime into a directory without configuring that startup contract does not demonstrate activation. [Microsoft integration guide](https://devblogs.microsoft.com/directx/gettingstarted-dx12agility/)

The reflected plugin API initializes this plugin from REFramework's frame path: `PluginLoader::on_frame` calls `init_d3d_pointers` before `initialize_plugins`. The earlier `PluginLoader::early_init` maps plugin DLLs shortly after unpacking; that is distinct from the public plugin initialization callback and supplies no guarantee that an arbitrary worker launched from DllMain will run before the game's first graphics device.

`ID3D12SDKConfiguration::SetSDKVersion` requires Developer Mode and must run before device creation. Using it on the game's active device removes the device. No menu toggle or late initialization should attempt this. [SetSDKVersion documentation](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/nf-d3d12-id3d12sdkconfiguration-setsdkversion)

`CreateDeviceFactory` supports separate devices from a side-by-side runtime without Developer Mode. This does not migrate existing game resources. Applying a factory's configuration globally can remove existing singleton devices, including devices already created by an engine, framework or overlay. [Microsoft independent-device specification](https://microsoft.github.io/DirectX-Specs/d3d/IndependentDevices.html)

## Possible future integration design

An actual integration would need controlled execution before the first relevant device is created. A dedicated launcher/bootstrap could coordinate this in a new process, configure the chosen runtime, then allow the engine to initialize. That remains an engineering proposal, not a validated implementation. It would require proof of startup ordering, supported game builds, renderer/device ownership, API availability, failure handling and compatibility with Steam, REFramework, overlays and other startup injectors.

A replacement dinput8/dxgi/d3d12 proxy would compete for names already used by other components. Patching executable exports would modify the game's executable and has build/integrity implications. Neither approach meets an unqualified promise of compatibility with every other mod. Starting a worker from a plugin's DllMain supplies no timing guarantee and would need separate loader-lock and startup analysis.

The preview package's runtime license also restricts redistribution. Its headers' MIT license does not authorize shipping the runtime DLL. These constraints remain separate from whether a local hardware probe succeeds; see `agility-1.722.0-preview-assessment.md`.

## Maximum verified scope

Keep RE8Display's aspect/FOV/cursor corrections independent of Agility. The optional kit can verify only its own executable's ability to create a healthy device with the selected runtime, without touching RE8. A pass is useful compatibility evidence for later integration work, but must not be described as game integration or proof that RE8 rendering problems are fixed. No complete game integration or universal conflict-free result has been verified.
