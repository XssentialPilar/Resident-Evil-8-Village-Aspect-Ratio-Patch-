# RE8 Agility 722 — game module

This optional x64 d3d12 proxy configures Agility SDK 722 before the first forwarded device creation. It forwards the system loader's exports, keeps the selected factory alive, and logs the actual device SDK. It does not alter Windows files, the game executable, REFramework or RE8Display.

Close RE8. Extract this ZIP to a separate folder and use PowerShell there:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -GamePath 'C:\path\Resident Evil Village' -PackagePath 'C:\path\microsoft.direct3d.d3d12.1.722.0-preview.nupkg' -AcceptPreviewLicense
```

The original preview package is required for a private development test. Read its license before accepting. Its Microsoft runtime is not redistributed in this ZIP. Setup verifies the original archive hash and runtime hash/signature, then copies only the exact x64 Core to `RE8Agility/D3D12/` and our proxy to the game root. An existing d3d12.dll causes a refusal rather than an overwrite.

Launch RE8 normally. `RE8Agility/bridge.log` must show `ACTIVATED` and a successful `FIRST_DEVICE` with `device_sdk=722` before claiming activation. A `DECLINED` entry means native forwarding, not successful integration. Existing Core/device ownership, missing API/runtime or failed SDK selection cause native forwarding; the bridge does not change an already running device. The game may bypass an app-local proxy, which must be verified in its actual process.

This changes runtime selection; it does not automatically enable every new SDK rendering feature or promise a performance gain. Compatibility with every driver, overlay and mod is not established. The preview runtime has separate Microsoft restrictions. Keep this module optional and separate from the display patch.

To remove with RE8 closed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -GamePath 'C:\path\Resident Evil Village'
```

Removal verifies all owned files before changing anything. Modified files cause refusal. Logs and other mods are preserved. Do not manually overwrite proxy files while RE8 runs.
