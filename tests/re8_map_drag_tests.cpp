#include "re8/RE8MapDragPolicy.hpp"
#include <cassert>
#include <iostream>
using namespace re8_patch;
int main() {
    // Test masks are arbitrary; runtime uses the reflected L/C/R/EX0/EX1 values.
    constexpr uint32_t left = 1, right = 2, center = 4, wheel = 8;
    for (int cycle = 0; cycle < 10000; ++cycle) {
        MapDragPolicy policy;
        auto click = policy.update(true, true, false);
        assert(!click.dragging);
        assert(map_drag_buttons(left | wheel, left, left, center, MapButtonSample::Down, click) == (left | wheel));
        auto drag = policy.update(true, true, true);
        assert(drag.dragging && drag.started);
        assert(map_drag_buttons(left | wheel, left, left, center, MapButtonSample::Held, drag) == (center | wheel));
        assert(map_drag_buttons(0, left, left, center, MapButtonSample::Down, drag) == center);
        auto steady = policy.update(true, true, false);
        assert(steady.dragging && !steady.started);
        auto release = policy.update(true, false, false);
        assert(release.ended);
        assert(map_drag_buttons(left, left, left, center, MapButtonSample::Up, release) == center);
        auto outside = policy.update(false, true, true);
        assert(map_drag_buttons(left | wheel, left, left, center, MapButtonSample::Held, outside) == (left | wheel));
    }
    MapDragPolicy policy;
    auto assigned = policy.update(true, true, false);
    assert(map_drag_buttons(right, right, left, center, MapButtonSample::Down, assigned) == left);
    auto disabled = policy.update(false, true, true);
    assert(map_drag_buttons(right, right, left, center, MapButtonSample::Down, disabled) == right);
    assert(map_drag_buttons(wheel, 0, left, center, MapButtonSample::Held, assigned) == wheel);
    std::cout << "PASS: click-to-expand, hold/move-to-pan, release, configurable source, unchanged wheel and inactive contexts across 10000 cycles.\n";
}
