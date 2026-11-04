# RE8 Agility 722 bridge — 2.7.0 candidate

Optional, separate from RE8Display. This candidate adds read-only reporting of the actual forwarded device SDK, highest shader model and DXR tier. No live device/runtime switching or experimental feature enablement is performed.

Extract this ZIP to a separate directory outside the game. Read and accept the original Microsoft preview license first. Close RE8 normally, then run in PowerShell (the flag records your acceptance):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -GamePath "C:\path\to\game" -PackagePath "C:\path\to\microsoft.direct3d.d3d12.1.722.0-preview.nupkg" -AcceptPreviewLicense
```

The game directory contains `re8.exe`. Use the original exact Microsoft package. The installer checks the matching package/runtime hashes, conflicting files and ownership; it creates rollback records. It installs the proxy beside `re8.exe` and the private runtime under `RE8Agility\D3D12\`. It does not replace Windows system DirectX files or edit the executable.

Remove it with the included `uninstall.ps1 -GamePath "C:\path\to\game"` while RE8 is closed. Do not overwrite another mod's `d3d12.dll`. Read `RE8Agility\bridge.log` for `FIRST_DEVICE` SDK confirmation and `CAPABILITIES`; a DLL's presence alone does not confirm activation.

This exact binary passed export/status ABI tests and a new combined game test. The game device confirmed SDK 722; the user reported no load failures, crashes or new hitches. Prior binaries retain separate evidence. Support on a device does not mean RE8 uses clustered geometry, PTLAS, SER, OMM or new shader models. Those require an engine/shader integration that this bridge does not implement. No FPS or VRAM improvement is promised.

Microsoft preview runtime DLLs are excluded from this ZIP. Use of the preview is subject to Microsoft's package license.
