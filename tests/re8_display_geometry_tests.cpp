#include "../reframework_src/src/mods/re8/RE8DisplayGeometry.hpp"
#include <array>
#include <cassert>
#include <iostream>
#include <limits>

namespace {
bool near(float actual, float expected) { return std::abs(actual - expected) < 0.002f; }
}

int main() {
    using namespace re8_patch::display;
    const std::array<std::array<float, 2>, 11> outputs{{
        {1280, 1024}, {1440, 1080}, {1620, 1080}, {1920, 1200},
        {2560, 1600}, {1920, 1080}, {3440, 1440}, {5120, 1440},
        {7680, 1440}, {1373, 911}, {1080, 1920}
    }};
    constexpr float baseline_horizontal = 90.0f;
    const auto baseline_vertical = horizontal_to_vertical(baseline_horizontal, reference_aspect);
    for (const auto& dimensions : outputs) {
        const float aspect = dimensions[0] / dimensions[1];
        const float horizontal = expanded_fov(baseline_horizontal, reference_aspect, aspect, false, false);
        const float vertical = horizontal_to_vertical(horizontal, aspect);
        // The original horizontal and vertical coverage must both be retained.
        assert(horizontal + 0.002f >= baseline_horizontal);
        assert(vertical + 0.002f >= baseline_vertical);
        // Pixel projection has one uniform scale on both axes (circles stay round).
        const float horizontal_scale = dimensions[0] / std::tan(horizontal * degrees_to_radians / 2);
        const float vertical_scale = dimensions[1] / std::tan(vertical * degrees_to_radians / 2);
        assert(std::abs(horizontal_scale / vertical_scale - 1.0f) < 0.0001f);
        // Choosing the engine's vertical-FOV representation cannot alter the view.
        const float explicit_vertical = expanded_fov(baseline_horizontal, reference_aspect, aspect, false, true);
        assert(near(explicit_vertical, vertical));
        const float vertical_source = expanded_fov(baseline_vertical, reference_aspect, aspect, true, false);
        assert(near(vertical_source, horizontal));
        const auto safe = safe_area(dimensions[0], dimensions[1]);
        assert(near(safe.width / safe.height, reference_aspect));
        assert(safe.x >= 0 && safe.y >= 0);
        assert(near(safe.width + 2 * safe.x, dimensions[0]));
        assert(near(safe.height + 2 * safe.y, dimensions[1]));
        std::cout << dimensions[0] << 'x' << dimensions[1] << ": H=" << horizontal << " V=" << vertical << '\n';
    }
    assert(near(expanded_fov(90, reference_aspect, 32.0f / 9.0f, false, false), 126.8699f));
    assert(near(expanded_fov(90, reference_aspect, 4.0f / 3.0f, false, true), 73.7398f));
    // A native ultrawide source must not receive another Hor+ expansion.
    assert(near(expanded_fov(126.8699f, 32.0f / 9.0f, 32.0f / 9.0f, false, false), 126.8699f));
    assert(!valid_dimensions(0, 1080));
    assert(!valid_dimensions(1920, 0));
    assert(!valid_dimensions(std::numeric_limits<float>::infinity(), 1080));
    assert(!valid_fov(std::numeric_limits<float>::quiet_NaN()));
    assert(near(expanded_fov(90, 0, reference_aspect, false, false), 90));
    assert(near(expanded_fov(90, reference_aspect, 0, false, false), 90));
    assert(safe_area(0, 0).width == 0);
    std::cout << "PASS: projection/axis/safe-area invariants across 11 render outputs; invalid dimensions guarded.\n";
}
