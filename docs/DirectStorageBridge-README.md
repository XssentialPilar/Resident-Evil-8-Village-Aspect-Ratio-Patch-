# RE8 DirectStorage 1.4 — PAK I/O game module

This separate REFramework plugin routes eligible nonalertable synchronous, read-only PAK reads from RE8 through a DirectStorage file queue into CPU memory. It supports the explicit null-event OVERLAPPED offsets used by the audited game build. Bulk payloads come from DirectStorage; a native one-byte read preserves Windows file-object state and EOF behavior. The first 64 successful payloads are compared completely against independent native reads before delivery. A difference disables the bridge and uses the original reader.

The game keeps its original asset compression and resource upload path. The bridge does not convert assets to Zstd/GDeflate or provide GPU decompression. Unsupported asynchronous/event-based reads, sizes outside 64 KiB–8 MiB and unavailable runtime/hooks remain native. This is a bounded hybrid file-I/O adapter, not a rewrite of the engine's GPU asset pipeline.

Requires an existing REFramework host with plugin API 1.15 or newer. Close RE8, extract the ZIP separately, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -GamePath 'C:\path\Resident Evil Village' -PackagePath 'C:\path\microsoft.direct3d.directstorage.1.4.0-preview1-2603.504.nupkg' -AcceptPreviewLicense
```

Read the original preview license before accepting it for private development testing. Setup verifies the original package hash and Microsoft runtime hashes/signatures. The ZIP redistributes no Microsoft runtime. The plugin goes to `reframework/plugins/RE8DirectStorage.dll`; its two private runtime files go to `RE8DirectStorage/`. Save files, Windows DLLs and other plugins are outside its installation ownership.

Launch RE8 normally and inspect `[RE8DirectStorage]` in `re2_framework_log.txt`. Successful PAK reads, nonzero bytes and `verification_reads=64` establish actual use and the sampled byte comparison. `verification_mismatch`, `verification_errors`, `native_compat_errors`, `timeout_disable` and `runtime` must remain zero. A plugin-load message or native fallback alone does not establish activation. Synchronous reads may not improve performance; unsupported asynchronous I/O remains native. Other I/O modifications can cause hook refusal. No universal compatibility or speed increase is claimed.

The final package is created only after validation of the exact installed DLL in the real game and a completed gameplay test. Native harness checks cover completion status, count, LastError, file cursor, offsets above 4 GiB, EOF, duplicate/recycled handles, concurrency, errors, native fallback and injected data mismatch. These checks do not prove every hardware/mod combination or every future game build.

To remove with the game closed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -GamePath 'C:\path\Resident Evil Village'
```

Removal validates owned hashes before deleting files, preserves logs and leaves the display patch, other mods and the game untouched.
