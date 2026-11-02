#include "../native/common/RE8GuiLayout.hpp"
#include "../native/common/RE8DisplayGeometry.hpp"
#include <cassert>
#include <iostream>
using namespace re8_patch::display;
int main() {
    // Values are deliberately non-default to catch overwritten designer state.
    const GuiResolutionState native{1, 6, 2, false};
    GuiResolutionOverride root;
    auto applied = root.apply(native, 2, 4, 0);
    for (int i = 0; i < 10000; ++i) {
        const auto repeated = root.apply(applied, 2, 4, 0);
        assert(repeated.scale == 2 && repeated.anchor == 4 && repeated.condition == 0 && repeated.enabled);
    }
    const auto restored = root.restore(applied);
    assert(restored.scale == 1 && restored.anchor == 6 && restored.condition == 2 && !restored.enabled);
    auto mod_update = applied;
    mod_update.anchor = 8;
    assert(root.restore(mod_update).anchor == 8); // Preserve another mod's update.
    // 1920x1080 authored root -> 1920x1200: one uniform pixel scale, 60px margins.
    const auto area = safe_area(1920, 1200);
    assert(area.width == 1920 && area.height == 1080 && area.x == 0 && area.y == 60);
    assert(area.width / 1920 == area.height / 1080);
    std::cout << "PASS: uniform root policy, 10000 repeat applications, reversible designer state, external changes and 16:10 safe canvas.\n";
}
