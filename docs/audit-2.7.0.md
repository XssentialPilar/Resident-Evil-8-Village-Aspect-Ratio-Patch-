# RE8Display 2.7.0 — seven-point delivery audit

This audit distinguishes implementation, automated checks and observed gameplay. It does not certify every monitor, driver, game build or future scenario.

| Requested point | Implementation / evidence | Remaining limit |
| --- | --- | --- |
| 1. Restore the original cursor | Enabled by default. Absolute Windows client coordinates map once to the actual backbuffer. The typed cursor's pixel canvas bypasses nested resolution adjustment; the original arrow/effects/animations and game clicks remain. Windows-only mode and fallback remain available. The user confirmed the corrected candidate successful; the log reports `ABSOLUTE_SYNC active`. | This observation applies to the tested game build/session; it is not a zero-latency claim beyond the game's rendered frame. |
| 2. Improve patch performance | Camera/GUI setters compare observed values; GUI roots are processed once per epoch; the last visible menu is queried first; configuration writes coalesce off the render thread; stable backbuffer detection is polled at most four times per second. | No controlled before/after FPS benchmark has been recorded. |
| 3. Improve ImGui | Bounded, scrollable window, grouped settings, full-width FOV slider, original/Windows cursor choice and restore-all-defaults including FOV and shortcut. | Full UI behavior across every display/DPI combination is not exhaustively tested. |
| 4. Improve display detection | Actual DXGI texture/resource extent, descriptor fallback, monitor extent reported separately, reset/size/display/DPI events trigger refresh. Position-mapping tests cover 4:3, 16:10, 16:9, ultrawide, 4K and client/backbuffer differences. | A geometry test is not a physical test on each monitor or exclusive scaling configuration. |
| 5. Reduce adjustment-induced hitches | Redundant property writes and synchronous INI writes while dragging were removed. Scene render-resource dimensions remain engine-owned. DirectStorage collection no longer waits for the I/O mutex on Present. | No guarantee that unrelated game/driver/shader-loading hitches are eliminated. |
| 6. Improve Agility / DirectStorage | Separate optional bridges: Agility selects the private runtime at startup and reports the actual device SDK/capabilities. DirectStorage performs eligible raw PAK reads to CPU memory with native comparisons/fallback. The exact new binaries passed a fresh combined game test: SDK 722 confirmed; 22,957 PAK reads / 5,653,036,407 bytes, 64 native comparisons and no recorded verification/timeout/runtime/compatibility errors. The user confirmed no load failures, crashes or new hitches. | **Partial relative to the requested advanced features.** No RE8 shader/DXR port to clustered geometry, PTLAS, SER, OMM or new shader models. No Zstd/GACL asset conversion, GPU decompression or CreatorID GPU scheduling in the game. Those are not activated by installing newer DLLs. |
| 7. Polish and prevent regressions | Seven native/ABI suites, installer/rollback tests, exact ZIP-entry hashes, version checks, optional-module export/status ABI checks and DirectStorage native-contract/fault tests. Backups and exact DLL identities are retained. | No software audit can establish absence of all present or future bugs. Historical results are not reused for new DLLs. |

## Microsoft implementation requirements

The SDK release describes new APIs which an engine must adopt; the bridge does not rewrite RE8's ray-tracing structures or shaders. [Microsoft Agility 1.722 / 1.620 release](https://devblogs.microsoft.com/directx/agilitysdk-1-620-retail-and-1-722-preview/).

Microsoft specifically explains that replacing DirectStorage DLLs does not enable preview features: assets need the matching preparation/compression and the game must explicitly use the APIs. [Microsoft DirectStorage 1.4 announcement and developer reply](https://devblogs.microsoft.com/directx/directstorage-1-4-release-adds-support-for-zstandard/).

## Release decision

The display patch can be delivered as a validated release candidate within the scope above. It must not be advertised as completing all advanced engine features in point 6, providing universal compatibility, eliminating all hitches, or guaranteeing FPS/VRAM/loading improvements. The optional modules remain separate and removable. Publication is left to the user's release workflow.
