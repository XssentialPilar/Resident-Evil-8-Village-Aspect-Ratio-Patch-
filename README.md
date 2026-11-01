# Resident Evil 8: Village — Aspect Ratio & Windows Native Cursor Patch

![Resident Evil Village](https://img.shields.io/badge/Game-Resident%20Evil%20Village%20(RE8)-red.svg)
![Version](https://img.shields.io/badge/Release-v1.1.0-blue.svg)
![Platform](https://img.shields.io/badge/Platform-PC%20Windows%20(DirectX%2012)-green.svg)
![Aspect Ratio](https://img.shields.io/badge/Aspect%20Ratio-16:10%20(1920x1200%20%7C%202560x1600)-orange.svg)
![Status](https://img.shields.io/badge/Status-16:10%20Demostrable%20y%20Verificado-success.svg)
![License](https://img.shields.io/badge/License-MIT-purple.svg)

An independent patch for **Resident Evil 8: Village on Windows PC**, focused on improving the game's presentation on **16:10 displays** and addressing the mouse cursor issues associated with removing the original black bars.

**v1.1.0 is the Latest Release, not a Pre-Release.** The aspect ratio fix and native cursor integration have made progress, but one cursor issue remains.

> [!IMPORTANT]
> **Known issue in v1.1.0 — Cursor behavior during gameplay:** The native Windows cursor is now visible and usable in menus. It also hides during gameplay, but **it may take some time to disappear after leaving a menu and can occasionally reappear unexpectedly while playing**. The cursor should be visible only in the game's menus and other interactive interfaces. **I am actively working on a fix.**

## Key Features

### 1. Improved 16:10 (Verified) Display Support

- Removes the original black bars and makes better use of the display in the **tested 16:10 configuration**.
- Preserves natural image proportions without intentionally stretching the game image.
- Includes aspect ratio and field-of-view (FOV) controls for fine-tuning the presentation.

### 2. Native Windows Cursor Integration

- Disables RE Engine's original software-drawn mouse pointer, which could become misaligned after the aspect ratio adjustment.
- Uses the standard **Windows mouse pointer** for interface interaction, including:
  - Main menu
  - Pause menu (`Esc`)
  - Ethan's inventory (`Tab`)
  - Typewriters and save/load screens
  - The Duke's shop
  - Map (`M`)
  - Settings and configuration screens
- **Current limitation:** The Windows cursor may remain visible briefly after returning to gameplay or reappear unexpectedly. It should stay hidden during exploration, aiming, and combat; this behavior is still being refined.

### 3. Simplified Configuration Menu

Press `Insert` to open **Aspect Ratio Config Menu**. It provides the essential aspect ratio and FOV settings in a cleaner interface without unnecessary development options.

## Recommended FOV Settings for 16:10 (1920 × 1200)

The following settings are recommended for the tested **1920 × 1200** configuration:

| Menu Option | Recommended Value | Purpose |
| :--- | :---: | :--- |
| `Ultrawide/FOV/Aspect Ratio Fix` | **ON** | Enables the aspect ratio adjustment. |
| `16:10 Mode: Use Black Bars` | **OFF** | Removes the black bars to use the available display area. |
| `Ultrawide: Enable Vertical FOV` | **OFF** | Keeps the vertical FOV behavior consistent with the recommended setup. |
| `Ultrawide: Override FOV` | **ON** | Enables the custom FOV multiplier. |
| `Ultrawide: FOV Multiplier` | **1.715** | Recommended starting value for the tested 1920 × 1200 setup. |

> [!TIP]
> These values are included as the patch's recommended defaults. You can review them in **Aspect Ratio Config Menu** if the image or FOV does not look right on your system.

## Compatibility and Testing

**This patch has only been tested on a 16:10 display.** The documented test setup uses **1920 × 1200**. Other 16:10 resolutions, such as 2560 × 1600 and 2880 × 1800, have not been individually verified. Compatibility with **16:9, 21:9, 32:9, and other aspect ratios is unknown and not guaranteed**.

The aspect ratio badge above identifies the intended display family; it should not be interpreted as confirmation that every listed resolution has been tested.

- **Game:** Resident Evil 8: Village
- **Platform:** Windows PC (DirectX 12)
- **Release:** v1.1.0 — Latest Release

## Installation

### Option 1 — Automatic Installer (Recommended)

1. Download `Resident-Evil-8-Village-16-10-Aspect-Ratio-Patch-v1.1.0.zip` from [Releases](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).
2. Extract the ZIP file to a folder of your choice.
3. Run `install.bat`. The installer is designed to locate the Steam installation of **Resident Evil Village** and copy the required files.
4. Launch the game.

### Option 2 — Manual Installation

Copy the following into the **game's root folder** (the directory containing the game executable):

- `dinput8.dll`
- `re2_fw_config.txt` *(optional; contains the recommended configuration)*
- The complete `reframework/` folder, including `reframework/autorun/re8_aspect_ratio_fix.lua`

Default Steam path:

```text
C:\Program Files (x86)\Steam\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE
```

> [!CAUTION]
> If you already have **REFramework or other mods installed**, back up their files before installing this patch. Shared files may be overwritten or cause conflicts.

## In-Game Controls

| Key | Action |
| --- | --- |
| `Insert` | Open or close **Aspect Ratio Config Menu**. |
| `Tab` | Open Ethan's inventory. |
| `Esc` | Open the pause/options menu. |
| `M` | Open the map. |

The Windows cursor is intended for these interfaces. In v1.1.0, its disappearance after returning to gameplay may be delayed, and it may reappear unexpectedly.

## Uninstallation

- **Automatic:** Run `uninstall.bat` from the patch package.
- **Manual:** Remove `reframework/autorun/re8_aspect_ratio_fix.lua`. Remove `dinput8.dll`, `re2_fw_config.txt`, or other bundled REFramework files **only if they were installed exclusively for this patch**.

**Do not delete the entire `reframework/` folder if other mods depend on it.** Doing so may break those mods.

## Credits and Thanks

This project is based on **[REFramework by Praydog](https://github.com/praydog/REFramework)** and has been adapted specifically to address **Resident Evil Village's aspect ratio and mouse cursor issues**.

**Thank you to everyone who has downloaded and used this patch.** I sincerely appreciate your support and patience while I continue working to improve cursor behavior during gameplay.
