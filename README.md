# Resident Evil Village — Display & Native Cursor

Version **2.1.0** is being prepared as an independent **REFramework plugin**. Its package contains `reframework/plugins/RE8Display.dll` and `reframework/data/RE8Display.ini`. It does not include or replace `dinput8.dll`, edit shared framework settings, or replace other mods. Runtime verification is in progress; see the [2.1.0 report](docs/release-2.1.0.md) for actual results and limits.

The previous bundled implementation is preserved in Git history, source patches and recovery tools. It is not the runtime shipped by the independent plugin. The [original v1.1.0 documentation](docs/legacy-release-v1.1.0.md) remains available.

## Behavior

- Output dimensions come from the current DXGI swap chain. Camera aspect and FOV are corrected together without accumulating adjustments; aiming and scene changes remain under engine control.
- Screen-space interface roots use proportional resolution adjustment. Nested widget positions, sizes and anchors are not individually rewritten. Text, cards and icons are not assigned separate horizontal and vertical stretch factors.
- Automatic projection and proportional UI are enabled by default. The old manual `1.715` calibration is **not inherited**. A manual multiplier remains an explicit option in the plugin's own settings.
- The Windows cursor is authorized by exact game menu identifiers. HUD, ammunition, autosaves and interaction prompts do not authorize it. Save/typewriter lists have their own typed reopen path.
- Additional map dragging is deferred. The game retains map input and mouse coordinate conversions.

Valid output dimensions are accepted without a resolution allowlist. Mathematical uniform-scale tests are recorded separately from rendered-menu verification. Mods that independently control the same camera, GUI scaling or cursor require an explicit ownership choice; no finite test run proves compatibility with every third-party mod.

## Installation

1. Close the game and remove the previous bundled aspect patch using its own uninstaller. Keep its backups.
2. Install unmodified REFramework with **plugin API 1.15 or newer**. Stable v1.5.9.1 has API 1.10 and is too old; see the official [nightly downloads](https://github.com/praydog/REFramework-nightly/releases).
3. Disable a separate REFramework ultrawide/FOV correction or another display patch before enabling this plugin's display correction. Shared settings are preserved by the installer.
4. Extract the complete RE8Display package and run:

```bat
install.bat "C:\path\to\Resident Evil Village"
```

The folder must contain `re8.exe` and the existing REFramework loader. Only the plugin DLL and its configuration are installed. Old autorun scripts belonging to this patch are backed up and retired. Other plugins, scripts, save files, shared settings and existing personal `RE8Display.ini` settings are preserved.

Press **`;`** to open the independent **Aspect Ratio Config Menu**. Its **Change menu key** button remaps this shortcut; **Reset menu key to ;** restores the default character using the current keyboard layout. The host keeps its own Insert binding. Manual FOV, multiplier, FOV axis and proportional UI controls are present in this window. If the host C ImGui interface is unavailable, use the private INI: `ManualFOV=0` and `UniformUI=1` select automatic behavior. `MenuKey=0` means the semicolon character.

To remove the plugin:

```bat
uninstall.bat "C:\path\to\Resident Evil Village"
```

Removal checks ownership and backups before changing files. A modified DLL blocks removal; modified personal configuration is retained. The entire `reframework/` folder is never deleted.

## Build and verify

The standalone source includes its small pinned SDK/MinHook dependencies. No full REFramework source checkout is required. Windows x64, CMake and Visual Studio 2026 C++ Build Tools are used:

```powershell
.\tools\RE8Display.Build.ps1
.\tools\RE8Display.Test.ps1
.\tools\RE8Display.Package.ps1
```

Build/package receipts bind the DLL hash to the source fingerprint. Packaging does not publish a release. Code is in `native/plugin/`, engine-independent logic in `native/common/`, tests in `tests/standalone/`, and dependency provenance in `external/standalone-dependencies.json`.

The older `RE8Patch.*` tools and `patches/` are retained for recovery and audit of the previous bundled implementation. They are not the standalone build/install path.

## Credits

Maintained by XssentialPilar. REFramework and its SDK are by [Praydog and contributors](https://github.com/praydog/REFramework); interception uses [MinHook](https://github.com/TsudaKageyu/minhook). Licenses and provenance are retained. Resident Evil Village belongs to Capcom; neither the game nor its assets are distributed here.
