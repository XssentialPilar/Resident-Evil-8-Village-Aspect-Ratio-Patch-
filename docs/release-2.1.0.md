# RE8Display 2.1.0 — verification report

Status: development candidate; runtime validation in progress. No new release has yet been published by this work.

The user reported distorted FOV and incorrect Duke interface proportions on the prior bundled candidate, at 1920×1200. The supplied screenshots are `re8_2026_11_01_23_49_22_247.png` and `re8_2026_11_01_23_58_56_991.png`. They show the older installed DLL, not the subsequently compiled source. The active shared configuration retained manual FOV `1.715` and had proportional UI disabled.

## Changes

2.1.0 separates the implementation into a REFramework plugin and a private INI. It no longer distributes a modified framework loader. REFramework's mod loader, script runner, configuration and existing files remain available to other mods.

The display path uses actual output aspect, a coherent camera projection snapshot, and automatic FOV by default. Legacy manual calibration is not silently imported. Proportional adjustment is enabled on screen-space GUI roots rather than applying scale/position changes to individual child controls. The native engine retains hit testing and cursor coordinate conversions.

Cursor behavior retains the exact-menu authorization policy, with explicit save-list reopen hooks and exact save transition identifiers. Map remapping is excluded from this version.

## Validation ledger

- Standalone filesystem installation/rollback/removal fixtures: **24 passed**. These fixtures contain fake DLLs and do not prove runtime behavior.
- Standalone native Windows x64 Release DLL build: **passed**.
- Five standalone suites: **passed** (camera projection, geometry, cursor policy, 100,000 arbitrary GUI canvas sizes, and actual DLL export/API-version refusal checks).
- Plugin loading and arrival in gameplay with unmodified REFramework API 1.15 at 1920×1200: **observed**. Full menu alignment, gameplay FOV, and save cursor checks remain pending.
- Multiple rendered aspect ratios and resize transitions: pending.
- Coexistence with another script/plugin: pending.

The uniform-scale algorithm is dimension-driven; it has no special restriction to 16:9 or 16:10. Actual rendered results must still be recorded separately. Other mods that change the same camera, GUI scaling or native cursor are not automatically conflict-free. The plugin restores only its own field values and offers separate display/cursor switches so ownership can be selected explicitly.

No map-input fix, zero-latency claim, universal mod-compatibility claim or unperformed gameplay test is included in this report.

## Latest feedback and correction

The first standalone candidate still showed a faint yellow software-cursor glow in the inventory. The screenshot also shows the separate host Graphics ultrawide correction enabled with a manual multiplier of 1.949; running both controllers is not a valid comparison of this plugin alone.

The latest build hides the typed GUIMouseCursor main visual panel, including its cursor/glow children, while retaining the original GUI draw and input bookkeeping. It adds a private ImGui window opened with the semicolon character by default, a key capture/remapping control, and visible manual FOV/multiplier settings. This shortcut leaves the host Insert binding untouched. Game mouse warping is suppressed only while this private menu is open and the game owns focus.

The latest build was compiled, passed automated checks and installed after the game closed. Computer Use was then stopped by the user's physical Escape key before a fresh visual retest. The glow and shortcut corrections are therefore **implemented but not visually confirmed**. No successful universal gameplay validation is claimed.
