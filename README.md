# Resident Evil Village — RE8Display v2.5.0

**RE8Display** is an independent plugin for [REFramework](https://github.com/praydog/REFramework), developed to improve aspect ratio handling, camera field of view (FOV), proportional interface scaling, and native Windows cursor behavior in **Resident Evil Village**.

**[Download RE8Display and view release notes](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases)**

> [!IMPORTANT]
> **RE8Display v2.5.0 requires an unmodified REFramework host with plugin API 1.15 or newer.** It does not include or replace `dinput8.dll`. Remove any older bundled aspect patch before upgrading, and disable other corrections that control the same camera or interface fields.

> [!NOTE]
> **What's new in v2.5.0:** This release resolves the viewport resizing/flicker loop (which previously triggered hundreds of resizes during gameplay) and fixes the aiming/camera disruption when switching resolutions. It corrects the managed numeric representation of Single/double values, properly separates authored camera calibration from output dimensions, and eliminates engine render-size writes.

## Features

- **Automatic display adaptation:** Aspect ratio and FOV corrections use the actual output dimensions rather than a fixed list of supported resolutions.
- **Proportional interface scaling:** Screen-space GUI elements are adjusted relative to the current output dimensions.
- **Dedicated configuration:** The private **Aspect Ratio Config Menu** provides automatic FOV handling, an optional degree-based override, and a rebindable shortcut.
- **Targeted cursor and menu handling:** Exact menu identifiers and typed drivers handle the Duke's shop and submenus, typewriter save-slot lists, and other authorized interfaces. HUD elements, ammunition indicators, and autosave notifications do not authorize the Windows cursor.
- **Non-invasive packaging:** The plugin uses its own DLL and private INI without replacing the framework loader or shared configuration.

The game's original software cursor visual root is suppressed while its native GUI processing is preserved.

**Map controls remain native in v2.5.0.** Additional mouse-dragging functionality has been deferred to maintain stability.

## Optional Technology Modules

Two independent, optional modules are available alongside the main release:

- **`RE8DirectStorage-1.4-Game (Optional).zip`**: Routes eligible read-only PAK reads through a DirectStorage 1.4 file queue into CPU memory while retaining the game's original asset decompression.
- **`RE8DirectXAgility-722-Game (Optional).zip`**: Configures the Agility SDK 722 preview runtime before the game initializes its DirectX 12 device.

*These modules are completely optional, separate from RE8Display, and do not modify core game files.* See [`docs/technology-integration-status.md`](docs/technology-integration-status.md) for installation instructions, prerequisites, and technical verification reports.

## Requirements

- **Game:** Resident Evil Village on Windows PC
- **Architecture:** Windows x64
- **Framework:** Unmodified REFramework with **plugin API 1.15 or newer**
- **Release package:** `RE8Display-2.5.0.zip`

The official [REFramework nightly builds](https://github.com/praydog/REFramework-nightly/releases) provide a suitable source for newer framework builds.

**REFramework stable v1.5.9.1 uses plugin API 1.10 and is not compatible with RE8Display v2.5.0.** Confirm the API version of the host you have installed before proceeding.

## Installation

1. **Close Resident Evil Village completely.**
2. Install or verify a compatible, unmodified REFramework host (plugin API 1.15 or newer).
3. Download `RE8Display-2.5.0.zip` from the [Releases page](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).
4. Extract the ZIP archive.
5. Copy its **`reframework` folder** into the game's root directory—the folder containing `re8.exe`. Allow Windows to merge the folders if prompted.
6. Launch the game and press **`;`** to open **Aspect Ratio Config Menu**.

### Package contents

The release ZIP contains **exactly these three files**:

```text
reframework/
├── plugins/
│   ├── RE8Display.dll
│   └── RE8Display.LICENSE.txt
└── data/
    └── RE8Display.ini
```

The package **does not include `dinput8.dll`**, modify shared REFramework settings, or remove other plugins and scripts.

### Upgrading from older bundled versions

If you previously installed the bundled aspect ratio patch (including v1.1.0):

1. Close the game and back up your existing configuration.
2. Run that older patch's **original uninstaller** to remove its own files.
3. Keep its backups, and restore or reinstall an unmodified REFramework host if necessary.
4. Disable REFramework's separate **Graphics ultrawide correction** and any other mod that writes to the same aspect ratio, FOV, or UI fields.
5. Install RE8Display v2.5.0 using the instructions above.

**Do not run multiple aspect/FOV fixes against the same game fields simultaneously.** Competing modifications may cause unexpected results.

When updating RE8Display itself, keep a backup of `reframework/data/RE8Display.ini` if you want to preserve your personal settings.

## Settings and Controls

Press **`;`** (semicolon) to open **Aspect Ratio Config Menu**.

- **Change menu key:** Assign another shortcut.
- **Reset menu key to ;:** Restore the semicolon character according to your current keyboard layout.
- **Automatic FOV:** Enabled by default.
- **Override FOV:** Optionally specify a horizontal field of view in degrees, referenced to the 16:9 base and scaled for the active display aspect ratio.
- **Proportional GUI Scaling:** Enabled by default.
- **Diagnostics:** Optional diagnostic logging for troubleshooting.

The REFramework host menu shortcut (`Insert`) remains completely independent.

## Validation and Compatibility

Version 2.5.0 has undergone automated validation:

- **Seven native and ABI test suites** covering geometry, camera projection, cursor policies, uniform GUI layout, managed numeric invocation, viewport policy, and plugin ABI.
- **24 installation and recovery checks**.
- **17 package verification checks**.
- Tests across arbitrary canvas dimensions and real-world resolutions.

### Coexistence with other mods

Display correction and cursor control can be **disabled independently** when another mod should own one of those features.

RE8Display restores only the fields that it owns. Game saves, unrelated plugins, scripts, and the REFramework loader are outside its installation and removal scope.

## Troubleshooting

- **The plugin does not load:** Verify that REFramework is unmodified, exposes **plugin API 1.15 or newer**, and that `RE8Display.dll` is in `reframework/plugins/` under the folder containing `re8.exe`.
- **The aspect ratio or FOV behaves unexpectedly:** Disable REFramework's separate Graphics ultrawide correction and any other mod that controls the same camera or interface fields. Try the plugin's automatic FOV mode before applying a manual override.
- **The menu shortcut does not respond:** Remember that the default is the `;` character for your active keyboard layout. The REFramework host's `Insert` shortcut is separate.
- **Settings are lost after an update:** Restore your backup of `reframework/data/RE8Display.ini`, provided it is compatible with the installed version.
- **A problem begins after installation:** Close the game, remove only the RE8Display plugin files listed below, and restore any personal configuration backups. Do not remove shared REFramework components.

## Uninstallation

1. Close the game.
2. Remove `reframework/plugins/RE8Display.dll`.
3. Remove `reframework/plugins/RE8Display.LICENSE.txt`.
4. Remove `reframework/data/RE8Display.ini` **only if you do not want to retain your private settings**.

Do **not** delete `dinput8.dll`, the complete `reframework` directory, shared configuration files, other plugins, or game save data. They are not owned by RE8Display.

## Build from Source

The repository includes the small, pinned public SDK and **MinHook** dependencies required for standalone builds. A full REFramework source checkout is not necessary.

Requirements for local building:

- Windows x64
- CMake
- Visual Studio 2022 C++ Build Tools (or Visual Studio 2026)

Run from the repository root in PowerShell:

```powershell
.\tools\RE8Display.Build.ps1
.\tools\RE8Display.Test.ps1
.\tools\RE8Display.Package.ps1
```

The build tools also accept `-Generator 'Visual Studio 17 2022'`.

### Source layout

| Path | Purpose |
| --- | --- |
| `native/` | Native plugin implementation and technology bridges |
| `tests/standalone/` | Standalone native, viewport, numeric, and ABI tests |
| `external/standalone-dependencies.json` | Dependency provenance and pinning |
| `docs/release-2.5.0.md` | Verification report and technical scope |

### Release workflow

The `v2.5.0` tag runs the GitHub Actions **build, test, and package** workflow and publishes the verified release assets under [Releases](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).

## Credits and License Notices

**Maintained by [XssentialPilar](https://github.com/XssentialPilar).**

- [REFramework and its SDK](https://github.com/praydog/REFramework) — Praydog and contributors
- [MinHook](https://github.com/TsudaKageyu/minhook) — API interception dependency
- **Resident Evil Village** — Capcom

The required license notices accompany the plugin. No Resident Evil Village game assets are distributed in this repository's release package.

**Thank you to everyone who uses, tests, and supports RE8Display.** Feedback and careful verification continue to guide its development.

If you encounter **any bugs or unexpected behavior**, you are warmly welcome to report them through the repository's [Issues section](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/issues). When possible, please include your resolution, display aspect ratio, REFramework version, and steps to reproduce the issue. Your feedback helps make the patch better for everyone!
