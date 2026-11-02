## RE8Display 2.5.0

Corrects the managed numeric invocation used for camera FOV/aspect, separates authored camera calibration from output dimensions, and removes engine render-size writes. The viewport override now remains stable through resets and skips redundant Fit writes, addressing the feedback loop observed as 811 resizes in about 151 seconds in the preceding candidate.

The intended framing reveals vertical scene content on narrower outputs and horizontal content on wider outputs while preserving aim/zoom changes. The ZIP contains only the independent plugin DLL, private INI and notices. Requires official REFramework plugin API 1.15 or newer; the host loader is not bundled. Optional Agility/DirectStorage work is separate and does not enable those technologies inside RE8.

The private menu uses `;` by default and can be rebound. Manual FOV multiplier and 16:10 bar controls remain removed. The native cursor's exact shop/save handling is retained. Custom map dragging remains deferred.

Validation: seven native/ABI suites, 24 installation/recovery checks and 17 package checks passed. The latest viewport fix still requires a fresh complete in-game visual retest; universal resolution/mod compatibility and absence of black screens or flicker are not claimed. See `docs/release-2.5.0.md` and `docs/validation-2.5.0.json` for exact scope and final artifact identity.
