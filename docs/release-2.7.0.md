# RE8Display 2.7.0 — validated release candidate

Based on the preserved 2.5.0 source. The corrected cursor and combined optional modules passed user gameplay verification on the audited RE8 build. This is not a claim of universal compatibility or a published release.

## Changes

- Original game cursor visuals and effects enabled by default (`GameCursor=1`). A separate setting selects Windows-only cursor visuals. Gameplay input and clicks remain the game's original controls.
- Cursor panels support both GameObject and Component callbacks. Windows cursor visuals are hidden while the original cursor is drawing, with a Windows fallback when it is unavailable. No shape stretching or synthetic click duplication.
- Absolute Windows client position is converted to backbuffer coordinates once, then written into the cursor's layout panel on a dedicated pixel-coordinate GUI canvas. Native `updateMousePosition` is followed by correction and the draw callback corrects again immediately before rendering. Nested cursor resolution adjustment is disabled with ownership-based restoration; authored child scale, rotation and animations remain. The general HUD adjustment excludes that cursor canvas. Point/Size/vector signatures come from the live game metadata; no fixed reference resolution or guessed struct-return hook is used. Live alignment and gameplay were confirmed by the user; other builds, displays and scenarios require their own checks.
- Menu discovery queries the last visible menu first instead of scanning every menu every frame. Full discovery resumes immediately when it closes.
- Camera/GUI setters execute only when a property differs. Shared GUI roots are applied once per behavior epoch, preserving the existing render-only projection lifecycle and native camera baseline.
- Configuration saves coalesce on a background worker after 250 ms without changes. The worker and plugin are retained until process exit; no worker joins under loader lock. Allow the save interval before exiting the process.
- Rendering dimensions come from the actual DXGI backbuffer when available, with descriptor fallback. Monitor mode is reported separately. Reset/size/display/DPI events trigger refresh; steady-state polling is bounded to four times per second.
- Grouped, bounded, scrollable ImGui settings; full-width FOV slider; restore-all-defaults button, including automatic FOV, cursor mode and `;` shortcut.

## Optional modules

Two separate candidate ZIPs preserve the optional nature of the bridges. They do not replace the system DirectX installation or alter the game executable/assets. Their private preview runtimes must be installed using the original Microsoft packages and the included installer.

DirectStorage: render-thread collection uses a nonblocking lock; status snapshots avoid the I/O mutex; completed startup verification avoids the verification mutex. Idle private handles are promptly released, preserving native sharing semantics. Actual raw PAK reads still target CPU memory; RE8 performs its original decompression and uploads. Zstd/GACL/GPU decompression and instantaneous loading are **not implemented or claimed**.

Agility: the startup bridge reports SDK confirmation, highest supported shader model and DXR tier from the real forwarded device. Capabilities are not proof that RE8 uses new shaders, clustered geometry, PTLAS, SER or OMM. These require separate engine/asset/shader work; no such engine port is included.

Microsoft references:
- https://devblogs.microsoft.com/directx/agilitysdk-1-620-retail-and-1-722-preview/
- https://devblogs.microsoft.com/directx/directstorage-1-4-release-adds-support-for-zstandard/

## Validation boundaries

Build/test receipts accompany the local development package. New real-game evidence identifies these exact three DLLs: the user confirmed cursor success and a combined optional-module test without loading failures, crashes or new hitches. Agility confirmed a real SDK 722 device; DirectStorage completed 22,957 PAK reads / 5,653,036,407 bytes, 64 native comparisons and zero recorded verification, timeout, runtime or compatibility errors. Earlier 2.5.0 results remain separate. Reported water/lighting faults from prior experiments have not been certified fixed by this candidate.

The archive contains only the display DLL, its private default INI and required notices. The independent toolkit, old fog experiments, Microsoft runtimes, shared host settings and game saves are excluded.
