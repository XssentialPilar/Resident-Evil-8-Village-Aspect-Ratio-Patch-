# Resident Evil Village — Aspect Ratio & Native Cursor Patch

An independent Windows PC patch based on REFramework by Praydog, maintained by XssentialPilar.

**v1.1.0 remains the latest published release.** This source tree contains development changes; it is not a new release or a claim that the remaining gameplay cursor and map issues are resolved. See the [technical report](docs/technical-report.md) for actual build results, runtime attempts and outstanding checks.

The published v1.1.0 can delay hiding the Windows cursor after leaving a menu and can show it unexpectedly during gameplay. Its documented display test was **1920 × 1200 (16:10)**. Other resolutions and aspect ratios were not individually verified. The previous release documentation, including its known issue, testing limits and installation instructions, is preserved [unchanged here](docs/legacy-release-v1.1.0.md). Published downloads remain in [Releases](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).

## Current development work

The native implementation replaces broad GUI-triggered cursor activation with an explicit RE8 menu policy. The authorized interfaces are the main menu and its submenus, pause, settings, the Duke's shop and submenus, Ethan's inventory, save/load screens, the map and the patch configuration menu. HUD updates, ammunition, notifications and interaction prompts do not authorize the cursor. See the [cursor controller notes](docs/cursor-controller.md).

Map input keeps the engine's original coordinate conversions, relative motion, buttons and wheel handling. The previous global coordinate overrides have been removed; natural map navigation still requires in-game verification.

Projection calculations use the current render output dimensions. The manual FOV multiplier **1.715** remains available; disabling the manual override selects the automatic calculation. **Aspect Ratio Config Menu** still opens with `Insert`. The [display and map evidence](docs/aspect-evidence.md) explains the implemented calculations and the limits of proportional UI handling.

Compilation and automated tests do not establish gameplay correctness or universal display compatibility. The [validation matrix](docs/validation-matrix.md) separates executed checks from pending cursor, map, resolution, DPI and display-mode tests.

## Source organization

| Path | Purpose |
| --- | --- |
| `runtime/reframework/autorun/re8_display.lua` | Patch configuration migration and diagnostics |
| `config/` | Initial configuration values |
| `reframework_src/` | Local external REFramework checkout and build; reconstructed separately |
| `patches/` | Reviewable changes against the recorded upstream source revision |
| `external/` | Source provenance and separate legacy binary revision |
| `tools/` | Build, tests, packaging, installation and removal |
| `tests/` | Native policy, geometry, Lua and file-operation tests |
| `docs/` | Technical evidence, validation matrix and file audit |
| `licenses/` | Patch, REFramework and dependency notices |
| `artifacts/`, `dist/` | Local outputs excluded from Git |
| `.recovery/` | Recoverable prior files; excluded from Git and packages |

The external names `dinput8.dll`, `reframework/`, `re2_fw_config.txt` and REFramework APIs retain their loading and compatibility contracts. New patch modules use names such as `RE8NativeCursor`, `RE8CursorPolicy`, `RE8DisplayGeometry` and `re8_display`. See the [file audit](docs/file-audit.md) for the naming exceptions, retired files and installation ownership rules.

## Build and test from a source checkout

These commands are for the **source repository**. Install packages intentionally omit source code, tests and build tools. Reconstruct the external checkout at the exact recorded revision and apply the patches as described in `patches/README.md` in the [source repository](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-). Do not apply those patches again to an already modified checkout.

The current tools use Windows x64, Visual Studio 2026 Build Tools with C++, CMake and the recorded dependencies. From the source root:

```powershell
.\tools\RE8Patch.Test.ps1
.\tools\RE8Patch.Build.ps1
.\tools\RE8Patch.Package.ps1
```

The package command checks the build receipt, source fingerprint and DLL hash before producing a local development candidate. It does not publish a GitHub release. Reports and licenses accompany the candidate; old packages, sources, tests and development logs do not.

## Install or remove a development candidate

Close the game. Extract the complete candidate package, then run its installer with the directory containing `re8.exe`:

```bat
install.bat "C:\path\to\Resident Evil Village"
uninstall.bat "C:\path\to\Resident Evil Village"
```

The installer verifies package hashes, backs up replaced files, preserves existing configuration and retires the old patch Lua to avoid running both scripts. Removal uses that installation manifest to restore original files and preserve other mods. It stops if another mod changed an installed runtime file. Never delete the entire `reframework/` directory when other mods depend on it.

## Credits and thanks

Based on [REFramework by Praydog](https://github.com/praydog/REFramework), with patch work by XssentialPilar. Original licenses and attribution are retained in `LICENSE` and `licenses/`. Resident Evil Village belongs to Capcom; the game is not included.

Thank you to everyone who has downloaded and used this patch. Your support and patience are appreciated while the remaining cursor behavior and compatibility checks are addressed.
