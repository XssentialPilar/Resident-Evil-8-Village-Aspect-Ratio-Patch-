# RE8Display 2.5.0 — verification report

## Reported failures and implemented corrections

The user's 2 November 2026 captures show changed framing when correction is enabled at 1920x1200 and a black 3D scene while the reticle, ammunition or menus remain visible. The user reports that selecting another resolution and aiming triggers the black scene. Passing arithmetic tests in 2.1.0 did not detect these rendering failures.

Three concrete implementation faults were addressed:

- The RE Engine managed invocation wrapper represents System.Single arguments/results as promoted doubles in pointer-sized slots. Reading their low bits as float and sending raw 32-bit float bits corrupted FOV/aspect values. The plugin now encodes/decodes the wrapper's actual representation, validates invocation error codes and rejects invalid numeric results. Typed native calls retain their separate ABI.
- RE8's authored camera calibration is distinct from physical output aspect. The projection policy preserves native horizontal coverage on narrower outputs to reveal vertical content, and native vertical coverage on wider outputs to reveal horizontal content. It captures/restores the actual native camera state and preserves aim/zoom changes without compounding correction.
- The plugin no longer writes engine-owned SceneView Size/CustomDisplaySize from swapchain dimensions. It changes only the required DisplayType. A reset no longer restores letterboxing and immediately re-enables Fit: that feedback loop repeatedly resized the swapchain. The persistent viewport policy skips redundant setters, keeps ownership across missing dimensions/resets, and restores its field only when disabled or changing views. Managed scene mutations run in engine application-entry callbacks; DXGI reset callbacks only publish invalidation.

Screen-space interface roots retain uniform scaling, authored child layout and native hit testing. Cursor shop/save handling, the bounded private semicolon menu and rebinding remain. Manual FOV multiplier and 16:10 bar controls remain removed; custom map dragging remains deferred.

## Executed checks and diagnostic evidence

The Windows x64 Release DLL compiled with MSVC 19.51. Seven native/ABI suites passed: geometry, camera projection, exact cursor policy, uniform GUI ownership, promoted-double invocation, persistent viewport ownership and actual plugin loading/API rejection. Checks include 100,000 arbitrary canvas dimensions, repeated projection/aim transitions and 1,000 viewport reset/missing-dimension cycles. The latter requires one Fit write rather than a setter on every cycle.

24 filesystem installation/recovery checks and 17 actual-package checks passed, for 41 checks outside the native suites. Recovery covers 2.1.0 and 2.5.0 ownership manifests. Package checks verify the native version, hashes, notices and exact three-entry archive. These tests do not render the game.

The preserved runtime log `artifacts/runtime/2.5.0/float-fixed-reset-loop.log` records 811 swapchain resize calls between 14:33:28.799 and 14:36:00.147 on 2 November 2026, America/Santo_Domingo: 151.348 seconds. It belongs to the earlier candidate after the numeric ABI correction but before the persistent viewport fix. Projection readbacks there show, for example, native horizontal FOV 40, source aspect 1.777778 and actual output aspect 1.600000 at 1920x1200. The latest flicker/performance report pertains to that preceding candidate. It is not evidence that the later viewport fix has received a complete visual retest.

The core DLL SHA256 is `54B6C44D04242F705198CDA7F79FE966BE6A70A03FADCA4C5783BD26FD5C0ABF`. The build receipt was refreshed after narrowing the fingerprint to the main target's actual source roots; it remains `9BD8CEEF91C4131BCADA3984F3F9C146F51B5A8F8668D842AE47DE75F4177E51`. Optional probe targets are separate inputs. The compiled DLL did not change during this receipt refresh.

The later log `artifacts/runtime/2.5.0/reset-loop-fixed-observation.log` records no ResizeBuffers calls between 15:10:28.051 and 15:16:06.719, a 338.668-second interval, with the persistent-viewport candidate. This is evidence that the earlier continuous reset cascade did not persist in that interval. Other resizes accompany output/window changes. It is not visual verification of shadows or proof of stable frame rate. Observed outputs include 1152x864, 1920x1200 and 1920x1181, with valid camera readbacks.

## Remaining runtime validation

A fresh complete in-game visual pass of the latest viewport fix remains pending. The final candidate has not been verified across every aim/zoom transition, menu, resolution, ultrawide/portrait monitor, DPI variant, extended play session or third-party mod. No claim is made that every black screen, flicker or compatibility problem is resolved. The source accepts dimensions without a resolution allowlist; this is not exhaustive hardware validation. The earlier [2.1.0 report](release-2.1.0.md) remains historical evidence.

## Package and ownership

The main public drag-and-drop ZIP contains exactly:

- `reframework/plugins/RE8Display.dll`
- `reframework/data/RE8Display.ini`
- `reframework/plugins/RE8Display.LICENSE.txt`

The official REFramework host with plugin API 1.15 or newer is a separate prerequisite. No host loader, shared settings, development files or other mods are included. The private semicolon menu and native menu cursor remain part of the plugin. Manual FOV multiplier and 16:10 bar controls remain removed. Custom map dragging remains deferred.

The local recovery uninstaller accepts both 2.1.0 and 2.5.0 manifests with the existing schema and path/hash ownership checks. Runtime files must only be replaced with the game stopped. Full compatibility with every third-party mod or display is not claimed.

Agility and DirectStorage are separate optional modules, not dependencies of the display patch. The later real-game Agility bridge log confirms a successful RE8 device using SDK 722. The later DirectStorage game bridge completed 18,011 PAK reads / 4,543,855,912 bytes into CPU memory; the first 64 reads matched independent native reads completely, with zero mismatches, errors or timeouts. The user completed gameplay without loading errors or hangs. This does not validate GPU decompression, a performance improvement, all display corrections or universal compatibility. The independent compatibility probes remain historical diagnostics. Preview runtime binaries and NuGet archives are excluded from public ZIPs; installers require the user's original package. See [technology integration status](technology-integration-status.md) and [DirectStorage game validation](DirectStorageBridge-validation.md).
