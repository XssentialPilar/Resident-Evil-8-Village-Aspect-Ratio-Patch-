# Resident Evil Village — RE8Display v2.1.0

**RE8Display** is an independent plugin for [REFramework](https://github.com/praydog/REFramework), developed to improve aspect ratio handling, camera field of view (FOV), proportional interface scaling, and native Windows cursor behavior in **Resident Evil Village**.

**[Download RE8Display and view release notes](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases)**

> [!IMPORTANT]
> **RE8Display v2.1.0 requires an unmodified REFramework host with plugin API 1.15 or newer.** It does not include or replace `dinput8.dll`. Remove the older bundled aspect patch before upgrading, and disable other corrections that control the same camera or interface fields.

> [!WARNING]
> **Verified display compatibility: 16:10 only.** RE8Display has been tested and confirmed to work on a **16:10 display**. Other aspect ratios have **not yet been visually verified**. After switching to a resolution with a different aspect ratio, **aiming or pressing the right mouse button may trigger a black screen**. I acknowledge this as a known issue that still needs to be addressed. The tested 16:10 configuration remains the confirmed working setup.

## Features

- **Automatic display adaptation:** Aspect ratio and FOV corrections use the actual output dimensions rather than a fixed list of supported resolutions.
- **Proportional interface scaling:** Screen-space GUI elements are adjusted relative to the current output dimensions.
- **Dedicated configuration:** The private **Aspect Ratio Config Menu** provides automatic FOV handling, an optional degree-based override, and a rebindable shortcut.
- **Targeted cursor and menu handling:** Exact menu identifiers and typed drivers handle the Duke's shop and submenus, typewriter save-slot lists, and other authorized interfaces. HUD elements, ammunition indicators, and autosave notifications do not authorize the Windows cursor.
- **Non-invasive packaging:** The plugin uses its own DLL and private INI without replacing the framework loader or shared configuration.

The game's original software cursor visual root is suppressed while its native GUI processing is preserved.

**Map controls remain native in v2.1.0.** Additional mouse-dragging functionality has not yet been implemented.

## Requirements

- **Game:** Resident Evil Village on Windows PC
- **Architecture:** Windows x64
- **Framework:** Unmodified REFramework with **plugin API 1.15 or newer**
- **Release package:** `RE8Display-2.1.0.zip`

The official [REFramework nightly builds](https://github.com/praydog/REFramework-nightly/releases) provide a suitable source for newer framework builds.

**REFramework stable v1.5.9.1 uses plugin API 1.10 and is not compatible with RE8Display v2.1.0.** Confirm the API version of the host you have installed before proceeding.

## Installation

1. **Close Resident Evil Village completely.**
2. Install or verify a compatible, unmodified REFramework host (plugin API 1.15 or newer).
3. Download `RE8Display-2.1.0.zip` from the [Releases page](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).
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
5. Install RE8Display v2.1.0 using the instructions above.

**Do not run multiple aspect/FOV fixes against the same game fields simultaneously.** Competing modifications may cause unexpected results.

When updating RE8Display itself, keep a backup of `reframework/data/RE8Display.ini` if you want to preserve your personal settings.

## Settings and Controls

Press **`;`** (semicolon) to open **Aspect Ratio Config Menu**.

- **Change menu key:** Assign another shortcut.
- **Reset menu key to ;:** Restore the semicolon character according to your current keyboard layout.
- **Automatic FOV:** Enabled by default.
- **Override FOV:** Optionally specify a **horizontal FOV angle in degrees**, defined relative to a 16:9 reference and converted for the active output.
- **Proportional GUI scaling:** Enabled by default.

The older **manual FOV multiplier** and **16:10 black-bar** controls have been removed, along with their previous configuration behavior.

The REFramework host's own **Insert** shortcut remains unchanged; the RE8Display menu uses its separate, configurable shortcut.

### Cursor and interface behavior

The plugin distinguishes supported interactive menus from informational HUD elements.

- The Duke's shop submenus and typewriter save-slot lists use their corresponding typed drivers.
- Ammunition indicators, HUD notifications, and autosave messages do **not** authorize cursor visibility.
- The software cursor visual root is hidden without skipping the game's original GUI processing.
- The map retains its native interaction controls; additional map dragging is deferred.

These controls are designed to reduce cursor conflicts while preserving menu interaction. Do not interpret the implementation checks below as a guarantee of perfect behavior with every third-party mod.

## Validation and Compatibility

The source accepts current output dimensions **without a resolution allowlist**.

| Verification performed | Reported result |
| --- | --- |
| Native and ABI test suites | **5 passed** |
| Installation and recovery checks | **24 passed** |
| Package checks | **17 passed** |
| Arbitrary proportional-canvas dimensions exercised | **100,000** |
| Output resolutions recorded in local runtime logs | **11** |

Local runtime logs include output changes across 11 resolutions—from **1280 × 800 / 1280 × 1024** through **1920 × 1200**—and activation of the actual save and Duke buy drivers.

**Current confirmed aspect ratio: 16:10.** Although the implementation accepts arbitrary output dimensions and has passed the automated checks above, **actual gameplay on other aspect ratios has not been confirmed**. In particular, changing to a different aspect ratio can cause a black screen when aiming or right-clicking. This is a recognized limitation of the current release.

> [!NOTE]
> These automated and runtime results do **not** establish visual correctness on every monitor, complete ultrawide or portrait-display compatibility, or conflict-free operation with every third-party mod. No universal zero-latency guarantee is made.

For the exact scope, evidence, and remaining limitations, see the **[v2.1.0 verification report](docs/release-2.1.0.md)**.

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
- Visual Studio 2026 C++ Build Tools

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
| `native/` | Native plugin implementation |
| `tests/standalone/` | Standalone native and ABI tests |
| `external/standalone-dependencies.json` | Dependency provenance and pinning |
| `docs/release-2.1.0.md` | Verification report and observed limits |

The older `RE8Patch.*` tools, `patches/`, and [v1.1.0 documentation](docs/legacy-release-v1.1.0.md) are intentionally retained for recovery and auditing of the earlier bundled implementation. They are not part of the three-file v2.1.0 release package.

### Release workflow

The `v2.1.0` tag runs the GitHub Actions **build, test, and package** workflow and publishes the verified three-file ZIP under [Releases](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).

Local build tools retain recovery receipts and verification reports outside the public ZIP.

## Credits and License Notices

**Maintained by [XssentialPilar](https://github.com/XssentialPilar).**

- [REFramework and its SDK](https://github.com/praydog/REFramework) — Praydog and contributors
- [MinHook](https://github.com/TsudaKageyu/minhook) — API interception dependency
- **Resident Evil Village** — Capcom

The required license notices accompany the plugin. No Resident Evil Village game assets are distributed in this repository's release package.

**Thank you to everyone who uses, tests, and supports RE8Display.** Feedback and careful verification continue to guide its development.

If you encounter **any additional bugs or unexpected behavior**, I would sincerely appreciate a report through the repository's Issues section. When possible, include your resolution, aspect ratio, REFramework version, and steps to reproduce the problem. **Your reports help me identify issues and continue improving the patch.**
