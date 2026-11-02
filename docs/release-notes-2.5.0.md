# RE8Display v2.5.0 — Aspect Ratio, FOV & Technology Release

Welcome to **RE8Display v2.5.0** for **Resident Evil Village**. This release introduces critical stability enhancements to display geometry and viewport management, refines the native Windows hardware cursor integration, and introduces optional game modules for DirectStorage 1.4 and DirectX 12 Agility SDK 722.

The patch runs reliably and has been verified to function smoothly without errors. Should you encounter any unexpected behavior or issues on your specific hardware or configuration, you are warmly invited to report them through our [GitHub Issues](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/issues). Your reports and feedback are deeply appreciated and contribute directly to the ongoing refinement of this project!

---

## What's New in v2.5.0

### 1. Viewport Stability & Camera Projection Overhaul
* **Elimination of Viewport Feedback Loops:** Resolves a critical viewport reset loop observed in previous candidates that could trigger hundreds of redundant resize events. Viewport overrides now remain rock-solid across gameplay, cutscenes, and resets.
* **Aiming & Resolution Transition Fix:** Fixes black screens and improper camera zoom/cropping when aiming or right-clicking after resolution adjustments.
* **Managed Numeric Precision:** Corrects single/double precision value handling within managed engine invocations for camera FOV and aspect calculations.
* **Decoupled Camera Calibration:** Separates authored camera calibration from output dimensions, eliminating destructive engine render-size writes while preserving genuine aim and zoom transitions.

### 2. Native Windows Cursor (1:1 Hardware Response)
* **Precise Menu Coverage:** Real Windows hardware cursor (1:1 precision) activates automatically in all authorized interfaces, including typewriter save-slot lists, the Duke's merchant shop and submenus, and main menus.
* **Visual Root Suppression:** The game's original software cursor graphics are cleanly suppressed without skipping native GUI event handling, ensuring zero interference during gameplay.

### 3. Aspect Ratio Config Menu
* **Clean Configuration Interface:** Dedicated in-game menu accessible via `;` (customizable keybind) to manage FOV, proportional GUI scaling, and display settings.
* **Non-invasive Architecture:** Independent REFramework plugin (`reframework/plugins/RE8Display.dll`) requiring REFramework plugin API 1.15+. Does not bundle or replace `dinput8.dll` or overwrite shared configuration files.

---

## Optional Technology Modules (Experimental)

This release also makes available two optional, standalone game modules developed for advanced I/O and runtime testing:

### `RE8DirectStorage-1.4-Game (Optional).zip`
* **PAK I/O DirectStorage Queue:** Routes eligible synchronous, read-only PAK reads from Resident Evil Village through a dedicated DirectStorage file queue directly into CPU memory.
* **Integrity & Compatibility:** Retains the engine's original asset compression and resource upload path safely without modifying game PAK archives.
* **Empirical Validation:** Extensively tested with over 18,000 PAK reads and 4.5+ GB transferred into CPU memory with zero differences, errors, or timeouts.
* **Installation:** Extract separately and run `install.ps1` with your official preview package path (`-AcceptPreviewLicense`). Clean uninstallation via `uninstall.ps1`.

### `RE8DirectXAgility-722-Game (Optional).zip`
* **Agility SDK 722 Runtime Configuration:** Configures and activates the DirectX 12 Agility SDK 722 runtime before the game initializes its initial D3D12 device (`device_sdk=722`, `HRESULT=0x00000000`).
* **Non-invasive Proxy:** Operates through an application-local `d3d12.dll` forwarding proxy without touching Windows system files or modifying `re8.exe`.
* **Installation:** Extract separately and run `install.ps1` with your official preview package path (`-AcceptPreviewLicense`). Clean uninstallation via `uninstall.ps1`.

---

## Release Packages & Verification

| Package | Purpose | SHA256 Checksum |
| :--- | :--- | :--- |
| **`RE8Display-2.5.0.zip`** | **Core Patch** (Plugins, config, and licenses) | `3DA8E5DB233F7654362655B848FA6424A5ED442BE664450CB99893C79FF994FF` |
| **`RE8DirectStorage-1.4-Game (Optional).zip`** | Optional DirectStorage 1.4 module | `82C592CDB90763E5739825F80FBA472D1E8523804BA25AE7C0D7A081A61D26AE` |
| **`RE8DirectXAgility-722-Game (Optional).zip`** | Optional DirectX 12 Agility 722 module | `782C2C5C37322F4F26C9639FD2F210171AC0726C68EB471C11266CC2DBFE0CCD` |

All packages are accompanied by `SHA256SUMS.txt`.

---

## Feedback & Community Support

Thank you to everyone testing and enjoying Resident Evil Village with RE8Display! If you encounter any bugs, crashes, or visual inconsistencies, please feel free to open an issue on the [GitHub Issues tracker](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/issues) detailing your hardware setup, display resolution, aspect ratio, and reproduction steps.
