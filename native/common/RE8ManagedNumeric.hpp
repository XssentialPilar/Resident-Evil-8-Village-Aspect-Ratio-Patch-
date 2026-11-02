#pragma once

#include <bit>
#include <cmath>
#include <cstdint>
#include <limits>
#include <optional>

namespace re8_patch::managed {
// The RE Engine managed invoke wrapper promotes System.Single values to double
// in its pointer-sized argument/result slots. Direct typed native calls do not.
// Match the public host's Lua binding (Sdk.cpp build_args/parse_data).
inline uintptr_t encode_system_single_argument(float value) {
    static_assert(sizeof(uintptr_t) == sizeof(double), "RE8 requires a 64-bit target");
    return static_cast<uintptr_t>(std::bit_cast<uint64_t>(static_cast<double>(value)));
}

inline std::optional<float> decode_system_single_result(uint64_t slot) {
    const double value = std::bit_cast<double>(slot);
    if (!std::isfinite(value) ||
        value > static_cast<double>(std::numeric_limits<float>::max()) ||
        value < -static_cast<double>(std::numeric_limits<float>::max())) return std::nullopt;
    return static_cast<float>(value);
}
} // namespace re8_patch::managed
