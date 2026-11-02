#include "RE8CameraProjection.hpp"
#include <cassert>
#include <iostream>

using namespace re8_patch::display;
bool near(float a, float b) { return std::abs(a - b) < 0.001f; }
int main() {
    const CameraProjection native{90, 16.0f / 9.0f, false};
    for (int cycle = 0; cycle < 10000; ++cycle) {
        CameraProjectionOverride pass;
        auto first = pass.apply(native, 1.6f, cycle % 2 != 0, false, 1.715f);
        auto second = pass.apply(first, 1.6f, cycle % 2 != 0, false, 1.715f);
        assert(near(first.fov, second.fov));
        assert(near(second.aspect, 1.6f));
        const float horizontal = second.vertical ? vertical_to_horizontal(second.fov, second.aspect) : second.fov;
        const float vertical = second.vertical ? second.fov : horizontal_to_vertical(second.fov, second.aspect);
        assert(near(1920 / std::tan(horizontal * degrees_to_radians / 2),
                    1200 / std::tan(vertical * degrees_to_radians / 2)));
        auto restored = pass.restore(second);
        assert(near(restored.fov, native.fov) && near(restored.aspect, native.aspect));
        assert(restored.vertical == native.vertical);
    }
    CameraProjectionOverride legacy;
    const auto manual = legacy.apply(native, 1.6f, false, true, 1.715f);
    assert(near(manual.fov, 154.35f)); // Legacy value retained only when explicitly selected.
    for (int i = 0; i < 1000; ++i)
        assert(near(legacy.apply(manual, 1.6f, false, true, 1.715f).fov, manual.fov));
    auto engine_aim = manual;
    engine_aim.fov = 60;
    assert(near(legacy.restore(engine_aim).fov, 60)); // Never erase a genuine engine update.
    const auto changed = legacy.apply(engine_aim, 1.6f, false, true, 1.715f);
    assert(near(changed.fov, 60 * 1.715f));
    CameraProjectionOverride limited;
    auto clamped = limited.apply(native, 1.6f, false, true, 1.715f);
    clamped.fov = 120; // Simulate an engine setter limiting our requested FOV.
    limited.confirm_applied(clamped);
    assert(near(limited.apply(clamped, 1.6f, false, true, 1.715f).fov, 154.35f));
    limited.confirm_applied(clamped); // The second native write is limited again.
    assert(near(limited.restore(clamped).fov, 90));
    std::cout << "PASS: actual camera aspect, axis capture, 10000 repeated pass cycles, legacy calibration, engine updates and setter limits.\n";
}
