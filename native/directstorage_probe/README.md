# DirectStorage 1.4 compatibility kit

Standalone Windows x64 diagnostic. **This does not add DirectStorage to RE8, change its streaming, repair rendering, or demonstrate an FPS improvement.** Keep this kit outside the game folder.

The public ZIP includes our compiled probe, setup script and license notices. It contains no Microsoft runtime DLL, NuGet package, GPU shader or game mod. The original preview is not licensed by the MIT notice supplied for our code or the SDK headers.

## Safe checks without the preview runtime

```powershell
.\bin\RE8DirectStorageProbe.exe --help
.\bin\RE8DirectStorageProbe.exe --selftest
```

These commands do not load DirectStorage. The selftest checks deterministic data generation and CRC32 corruption detection.

## Isolated compatibility test

The local package must be exactly `microsoft.direct3d.directstorage.1.4.0-preview1-2603.504.nupkg`, SHA-256 `5E0EC8178EDD0F5B6EDABA8EC89D3540DC2AE17A9D2DD70E5737ADAC3F50C590`. The setup script accepts only that package and the reviewed x64 DLL hashes with valid Microsoft signatures. It refuses to overwrite different files and rejects kit paths inside RE8 or through reparse points.

The package's original `LICENSE.txt` applies to `native/bin/`, while `LICENSE-CODE.txt` applies only to headers. The preview binary terms restrict distribution and operational use; this kit grants no additional rights. Review the original terms and use an applicable Microsoft authorization for the intended test. Do not redistribute the private runtime files prepared by setup.

```powershell
powershell -NoProfile -File .\tools\RE8DirectStorage.Setup.ps1 -PackagePath 'C:\path\microsoft.direct3d.directstorage.1.4.0-preview1-2603.504.nupkg'
.\bin\RE8DirectStorageProbe.exe --probe
```

Setup only extracts the reviewed files beside the probe, along with the original package terms/notices; it does not execute the runtime. Use a fresh extraction if setup reports an existing private terms directory. Do not zip that prepared private folder for publication.

The explicit probe loads `dstoragecore.dll` and `dstorage.dll` by absolute paths from its own executable folder, with DLL-directory and System32 dependency search flags. It does not change system DLL search settings. It creates a uniquely named 1 MiB deterministic test file in that same folder and reads it through a DirectStorage file queue into ordinary CPU memory. It waits for completion, checks the HRESULT and compares every byte plus a CRC32 checksum. The test file is removed on ordinary completion/failure. A hard deadline terminates only this isolated probe if a runtime call hangs; in that case its uniquely named test file may remain for manual removal.

No GPU device, GPU decompression, game data, benchmark or throughput/timing result is used. DirectStorage GPU compatibility, native RE8 integration and performance remain untested. A PASS verifies only this small uncompressed file-to-memory request in the tested environment.

## Building

From the source repository, first retain the reviewed SDK headers in `artifacts/dependencies/directstorage-1.4-preview-inventory/native/include/` and their `LICENSE-CODE.txt` in the inventory root. Then run:

```powershell
powershell -NoProfile -File .\tools\RE8DirectStorage.Build.ps1
powershell -NoProfile -File .\tools\RE8DirectStorage.Package.ps1
```

The project dynamically resolves the runtime exports; it does not link `dstorage.lib`. The default build uses Visual Studio 18 2026 x64 and a static Microsoft C runtime; the build script accepts `-Generator` for another installed Visual Studio generator. Package creation excludes all Microsoft binaries and private runtime terms folders.
