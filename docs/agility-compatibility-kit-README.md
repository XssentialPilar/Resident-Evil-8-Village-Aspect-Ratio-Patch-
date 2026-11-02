# RE8 Agility 722 — optional compatibility kit

This separate diagnostic kit creates its own Direct3D 12 device in its own process. It reports the selected GPU, loaded D3D12Core path, SDK version and device-removed reason. It does **not** enable Agility in RE8, launch/inject into the game, modify settings or edit the registry. Keep it outside the game folder. RE8Display does not depend on this kit.

## Local setup

The preview runtime is not redistributed in this ZIP. Download your own original Microsoft.Direct3D.D3D12 1.722.0-preview package from [Microsoft's NuGet listing](https://www.nuget.org/packages/Microsoft.Direct3D.D3D12/1.722.0-preview). Extract this kit to a separate folder.

In PowerShell in that folder, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -PackagePath 'C:\path\microsoft.direct3d.d3d12.1.722.0-preview.nupkg'
```

The script verifies the exact package SHA256 and saves its runtime license locally. Read the terms. If you accept them for local use, rerun with `-AcceptPreviewLicense`. The script extracts only the x64 D3D12Core.dll into this kit's `D3D12` folder, verifies its exact SHA256 and Microsoft Authenticode signature, and preserves any different existing runtime. It never installs a system or game runtime. Do not redistribute the resulting local DLL/package.

Run these separately:

```powershell
.\RE8AgilityProbe.exe --selftest
.\RE8AgilityProbe.exe
```

`--help` and `--selftest` do not create devices. Running without arguments creates a hardware D3D12 device only for this diagnostic process. A pass requires a healthy device and an actual loaded SDK version of 722; a fallback to another runtime is a failure. Output is printed to the console. Exit codes are described by `--help`.

Windows and graphics drivers must support the requested runtime. Unsupported systems report a failure; this kit does not change Developer Mode or any other system setting. Detailed loader and license constraints are in `agility-assessment.md`.

## What a pass means

A pass proves that this separate executable can create its own healthy device using SDK 722 on that machine at that time. It does not prove that RE8 can use that runtime, that the game will render correctly, or that a black-screen regression is fixed. Game integration needs its own startup/device-lifetime design and validation. Calling SetSDKVersion after the game's device exists can remove that device and is deliberately excluded.

The public ZIP contains the probe, setup script, this README, assessment and the probe's license. The Microsoft preview runtime, NuGet archive, debug layers, development symbols and compiler tools are excluded.
