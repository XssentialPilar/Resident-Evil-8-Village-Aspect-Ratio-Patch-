#include "RE8GuiLayout.hpp"
#include "RE8DisplayGeometry.hpp"
#include <cassert>
#include <cmath>
#include <cstdint>
#include <iostream>

using namespace re8_patch::display;
int main() {
    // Exercise narrow, wide, portrait, high-DPI and nonstandard sizes without
    // a 16:9/16:10 branch. This is a geometry invariant, not a rendered GUI test.
    uint32_t random = 0x8210210;
    for (int i = 0; i < 100000; ++i) {
        random = random * 1664525u + 1013904223u;
        const float width = 1.0f + (random % 32768u);
        random = random * 1664525u + 1013904223u;
        const float height = 1.0f + (random % 32768u);
        const auto canvas = safe_area(width, height);
        const auto panel = config_window_bounds(width, height);
        assert(panel.max_width > 0 && panel.max_height > 0);
        assert(panel.max_width <= width && panel.max_height <= height);
        assert(canvas.x >= -0.01f && canvas.y >= -0.01f);
        assert(canvas.width > 0 && canvas.height > 0);
        assert(canvas.x + canvas.width <= width + 0.01f);
        assert(canvas.y + canvas.height <= height + 0.01f);
        const float sx = canvas.width / 1920.0f;
        const float sy = canvas.height / 1080.0f;
        assert(std::abs(sx / sy - 1.0f) < 0.00001f);
        assert(std::abs((canvas.x * 2 + canvas.width) / width - 1.0f) < 0.00001f);
        assert(std::abs((canvas.y * 2 + canvas.height) / height - 1.0f) < 0.00001f);
    }
    const GuiResolutionState native{4, 2, 7, false};
    GuiResolutionOverride state;
    auto applied = state.apply(native, 1, 0, 0);
    assert(applied.scale == 1 && applied.anchor == 0 && applied.condition == 0 && applied.enabled);
    for (int i = 0; i < 10000; ++i) applied = state.apply(applied, 1, 0, 0);
    const auto restored = state.restore(applied);
    assert(restored.scale == 4 && restored.anchor == 2 && restored.condition == 7 && !restored.enabled);
    // A second mod's changed field survives removal of our own adjustment.
    applied.scale = 9;
    const auto external = state.restore(applied);
    assert(external.scale == 9 && external.anchor == 2);
    applied = state.apply(applied, 1, 0, 0);
    assert(state.restore(applied).scale == 9);
    std::cout << "PASS: 100000 arbitrary canvas sizes, 10000 GUI ownership cycles, external changes retained\n";
}
