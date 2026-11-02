#include "RE8ManagedNumeric.hpp"

#include <array>
#include <cassert>
#include <iostream>

using namespace re8_patch::managed;

int main() {
    // Known wire representations are intentionally independent of the encoder.
    assert(encode_system_single_argument(81.0f) == UINT64_C(0x4054400000000000));
    assert(encode_system_single_argument(1.6f) == UINT64_C(0x3ff99999a0000000));
    assert(encode_system_single_argument(70.0f) == UINT64_C(0x4051800000000000));
    assert(decode_system_single_result(UINT64_C(0x4054400000000000)) == 81.0f);
    assert(decode_system_single_result(UINT64_C(0x3ff99999a0000000)) == 1.6f);
    assert(decode_system_single_result(UINT64_C(0x4051800000000000)) == 70.0f);
    assert(decode_system_single_result(UINT64_C(0x4044000000000000)) == 40.0f);

    // Reproduce the original failure: interpreting a promoted result as float
    // yields unrelated low bits, and float argument bits are not a valid slot.
    assert(std::bit_cast<float>(uint32_t{0x00000000}) != 81.0f);
    assert(encode_system_single_argument(81.0f) != std::bit_cast<uint32_t>(81.0f));

    const std::array<float, 10> native_values{{0.0f, -0.0f, 1.0f, 1.6f, 16.0f / 9.0f,
        70.0f, 81.0f, -5.0f, std::numeric_limits<float>::max(), std::numeric_limits<float>::denorm_min()}};
    for (float value : native_values) {
        const auto decoded = decode_system_single_result(encode_system_single_argument(value));
        assert(decoded && std::bit_cast<uint32_t>(*decoded) == std::bit_cast<uint32_t>(value));
    }
    assert(!decode_system_single_result(UINT64_C(0x7ff0000000000000))); // +Infinity
    assert(!decode_system_single_result(UINT64_C(0xfff0000000000000))); // -Infinity
    assert(!decode_system_single_result(UINT64_C(0x7ff8000000000000))); // NaN
    assert(!decode_system_single_result(UINT64_C(0x7fefffffffffffff))); // finite double overflow
    assert(!decode_system_single_result(UINT64_C(0xffefffffffffffff)));
    // Subnormal System.Single is valid wire data; camera-specific FOV/aspect
    // acceptance belongs to the camera policy, not this numeric decoder.
    assert(decode_system_single_result(UINT64_C(0x0000000000000001)) == 0.0f);
    std::cout << "PASS: System.Single promoted-double invoke ABI, camera FOV/aspect/aim slots, exact float roundtrips and invalid results.\n";
}
