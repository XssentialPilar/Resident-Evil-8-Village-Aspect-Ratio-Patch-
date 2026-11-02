# RE8Display 2.1.0 — verification report

The distributed runtime is an independent public-API plugin. The older bundled DLL implementation and its failed visual feedback remain in Git history and the historical reports; they are not the current runtime.

## Current corrections

- Automatic projection updates actual camera aspect and FOV as one coherent override, avoiding repeated multiplication and preserving engine aiming/scene changes.
- Screen-space GUI roots use the engine's uniform fit adjustment. Child positions, sizes and authored anchors are preserved; native hit testing and coordinate conversions run normally.
- The manual multiplier and 16:10 bars settings were removed. Optional FOV override now uses horizontal degrees at a 16:9 reference, converted to the current output.
- The private ImGui window opens with the semicolon character and supports key rebinding without changing the host shortcut.
- Logs from the earlier standalone build showed that the root Duke menu closed while its custom child driver remained open, without an authorized MenuDefine visibility result. The policy now tracks only eight exact shop/save driver types opened through their verified custom commands, queries GUIDriver.get_isDrawSelf, and clears authorization on close. No HUD or autosave heuristic was added.
- The software-cursor main visual panel is hidden, including its glow children, while the original GUI processing continues. Added map input translation is excluded.

## Executed checks

Windows x64 Release DLL builds with MSVC 19.51. Five native/ABI suites pass: geometry, coherent camera overrides, exact cursor policy, uniform GUI ownership, and loading the actual DLL to verify its exports and rejection of older APIs/wrong games. The GUI invariant is checked on 100,000 arbitrary dimensions; repeated camera/policy cycles and external changes are covered separately.

24 filesystem installation/rollback/removal checks pass with fake fixture DLLs. 17 actual-package checks confirm hashes, version 2.1.0, attribution and the three-entry drag-and-drop archive. Fixture checks do not prove game compatibility.

The latest installed native binary loaded with official REFramework nightly API 1.15, initialized 73 menu IDs and 18 lifecycle hooks, and reached visible game menus. Runtime logs from 2 November 2026 (America/Santo_Domingo) record buffers at 1280x800, 1280x960, 1280x1024, 1360x768, 1366x768, 1400x1050, 1440x1080, 1600x1024, 1600x1200, 1920x1080 and 1920x1200. These entries establish output reconfiguration, not a complete visual test of every menu at each size.

At 01:07:11 the actual GUISaveLoad.openList path authorized visibility and the owning window applied the native cursor request; closure removed it. At 01:07:19–23 the GUIShop, GUIShopMenu and GUIShopBuy custom commands were observed, with visibility retained through the child transition. Typical policy-to-window samples in that sequence were about 0.3–0.5 ms; these exclude presentation latency and are not a zero-latency guarantee.

No managed invocation exception from this plugin was found in the inspected session. A previous framework message `Present failed: 87a0001` is DXGI_STATUS_OCCLUDED (0x087A0001), a minimized/occluded-window status; it is not the DXGI_ERROR_INVALID_CALL value. This does not prove that no black screen can ever occur.

## Limits

The Windows input controller repeatedly rejected automated actions because it detected user activity. Visible menus and the runtime traces above were observed, but full automated interaction, private-menu rebinding and every rendered submenu alignment were not completed. Ultrawide, portrait, DPI variants, long play sessions, all third-party mods and a full visual pass at every listed resolution remain unverified. The source accepts dimensions without a 16:9/16:10 allowlist; mathematical generality is not presented as exhaustive hardware validation.

The public ZIP contains only RE8Display.dll, RE8Display.ini and combined license notices. The host loader, other plugins/scripts and shared settings are not bundled or overwritten. Overlapping camera/UI/cursor mods require an ownership choice. Recovery copies and build/runtime evidence remain local in .recovery/ and artifacts/; no game save data was modified by the tooling.

## Final packaging review

The final private ImGui window is bounded to the active output, wraps explanatory text, and uses vertical scrolling instead of AlwaysAutoResize. The bounds are covered by the existing 100,000-dimension suite. The required C ImGui exports for constraints and wrapping were verified in the unmodified host binary.

The /MT build retains DLL thread notifications, as required for the static CRT by [Microsoft's DisableThreadLibraryCalls contract](https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-disablethreadlibrarycalls). The built plugin imports only USER32.dll and KERNEL32.dll; it has no extra runtime DLL to distribute.

These final GUI/runtime-initialization changes compiled and passed the five suites, 24 installation tests and 17 actual-package checks. They were made after the observed runtime session described above and have not received a fresh complete in-game visual retest. Their source changes are local for the user's separate publication workflow; no release or tag was created for this final cleanup by the patch-preparation step.
