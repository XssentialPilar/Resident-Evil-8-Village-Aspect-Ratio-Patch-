# Resident Evil Village — RE8Display 2.1.0

An independent REFramework plugin for proportional interface scaling, camera aspect/FOV correction and the native Windows cursor in game menus. [Downloads and release notes](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).

## Install

Close the game, extract **RE8Display-2.1.0.zip**, then copy its `reframework` folder into the folder containing `re8.exe`. The ZIP contains exactly three files:

- `reframework/plugins/RE8Display.dll`
- `reframework/data/RE8Display.ini`
- `reframework/plugins/RE8Display.LICENSE.txt`

Use an unmodified REFramework host with **plugin API 1.15 or newer**, available in the official [nightly builds](https://github.com/praydog/REFramework-nightly/releases). Stable v1.5.9.1 uses API 1.10 and is too old. The patch does not bundle or replace `dinput8.dll`.

Remove older bundled versions of this aspect patch using their original uninstaller before upgrading; keep their backups. Disable the host's separate Graphics ultrawide correction and any other mod controlling the same display fields. The new plugin neither changes shared REFramework settings nor removes other mods. Keep a copy of your private INI when updating if you want to retain custom settings.

## Settings

Press **`;`** to open **Aspect Ratio Config Menu**. Use **Change menu key** to rebind it, or **Reset menu key to ;** to return to the semicolon character for the current keyboard layout. The host retains its Insert shortcut.

Automatic FOV is the default. **Override FOV** provides an optional horizontal angle in degrees, defined at the 16:9 reference and converted for the current output. The manual multiplier and 16:10 black-bar options have been removed, including their old configuration behavior. Proportional GUI scaling is enabled by default.

The cursor policy includes exact menu IDs and the actual typed shop/save drivers used by the Duke's submenus and typewriter slot lists. HUD, ammunition and autosave indicators do not authorize the cursor. The software cursor's visual root is hidden without skipping its original GUI processing. Map input remains native; added map dragging is deferred.

## Validation and compatibility

The source accepts current output dimensions without a resolution allowlist. Five native/ABI suites, 24 installation/recovery checks, 17 package checks and 100,000 arbitrary proportional-canvas sizes pass. Runtime logs record output changes across 11 resolutions, from 1280x800/1280x1024 through 1920x1200, and activation of the actual save and Duke buy drivers. This does not establish visual correctness on every monitor or compatibility with every mod. See [the verification report](docs/release-2.1.0.md) for the scope actually observed.

Only fields owned by this plugin are restored. Display and cursor can be disabled separately to assign ownership when another mod changes the same features. Save files, other plugins/scripts and the framework loader are outside this plugin's installation ownership.

## Source and build

The small pinned public SDK and MinHook dependencies are included; a full REFramework checkout is unnecessary. On Windows x64 with CMake and Visual Studio 2026 C++ Build Tools:

```powershell
.\tools\RE8Display.Build.ps1
.\tools\RE8Display.Test.ps1
.\tools\RE8Display.Package.ps1
```

The build tools also accept `-Generator 'Visual Studio 17 2022'`. Tag `v2.1.0` runs the GitHub Actions build/test/package workflow and publishes the verified three-file ZIP under Releases. Local tools keep recovery receipts and reports outside the public ZIP.

Source is in `native/`, tests in `tests/standalone/`, and dependency provenance in `external/standalone-dependencies.json`. Older `RE8Patch.*` tools, `patches/` and [v1.1.0 documentation](docs/legacy-release-v1.1.0.md) are retained for recovery and audit of the previous bundled implementation.

## Credits

Maintained by XssentialPilar. [REFramework and its SDK](https://github.com/praydog/REFramework) are by Praydog and contributors; interception uses [MinHook](https://github.com/TsudaKageyu/minhook). Required license notices accompany the plugin. Resident Evil Village belongs to Capcom; no game assets are distributed here.
