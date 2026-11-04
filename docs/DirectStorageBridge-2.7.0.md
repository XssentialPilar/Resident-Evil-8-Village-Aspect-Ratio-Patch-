# RE8 DirectStorage 1.4 bridge — 2.7.0 candidate

Optional, separate from RE8Display. This candidate avoids waiting for the I/O mutex on the render thread during deferred collection and skips the startup-verification mutex after the first 64 successful comparisons. Status snapshots also avoid that mutex. Idle private handles are still released promptly to preserve Windows sharing semantics. Integrity checks and native fallback remain enabled.

Extract this ZIP to a separate directory outside the game. Read and accept the original Microsoft preview license first. Close RE8 normally, then run in PowerShell (the flag records your acceptance):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -GamePath "C:\path\to\game" -PackagePath "C:\path\to\microsoft.direct3d.directstorage.1.4.0-preview1-2603.504.nupkg" -AcceptPreviewLicense
```

The installer requires the original exact Microsoft package, verifies hashes and ownership, rejects conflicts and creates rollback records. The bridge installs under `reframework\plugins\`; the private runtime goes under `RE8DirectStorage\`. It does not replace Windows files, repackage assets or modify the executable. A compatible REFramework host (public API 1.15+) must already be installed.

Remove with `uninstall.ps1 -GamePath "C:\path\to\game"` while RE8 is closed. Do not mix old and new bridge/runtime files. Counters in `re2_framework_log.txt` demonstrate actual requests, bytes, native comparisons and fallback/error counts.

This bridge routes eligible synchronous, read-only PAK requests to CPU memory. Original engine decompression and GPU uploads remain. Zstd/GACL asset conversion, GPU decompression, CreatorID-based GPU scheduling and instantaneous loads are not implemented. The existing game assets are not silently converted by a newer DLL.

This exact new binary passed isolated/fault-harness validation and a fresh combined game test: 22,957 PAK reads, 5,653,036,407 bytes, 64 successful native comparisons and no recorded verification, timeout, runtime or native-compatibility errors. The user reported no load failures, crashes or new hitches. Microsoft preview runtime DLLs are not included; use the original package under its license.
