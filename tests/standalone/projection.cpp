#include "RE8CameraProjection.hpp"
#include <cassert>
#include <iostream>
#include <limits>
#include <random>

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

    // Regression: camera.AspectRatio can be 1.6 while the authored content is
    // still a 1920x1080 letterbox. Keeping its native vertical FOV when filling
    // 1920x1200 magnifies objects by 1200/1080 instead of revealing the margins.
    const float native_vertical = horizontal_to_vertical(90.0f, reference_aspect);
    const CameraProjection letterboxed{native_vertical, 1.6f, true};
    for (bool vertical_axis : {false, true}) {
        CameraProjectionOverride narrow;
        const auto full = narrow.apply_re8(letterboxed, 1.6f, vertical_axis);
        const float h = full.vertical ? vertical_to_horizontal(full.fov, full.aspect) : full.fov;
        const float v = full.vertical ? full.fov : horizontal_to_vertical(full.fov, full.aspect);
        assert(near(h, 90.0f));
        const float focal = 1920.0f / (2.0f * std::tan(h * degrees_to_radians / 2.0f));
        const float native_focal = 1080.0f / (2.0f * std::tan(native_vertical * degrees_to_radians / 2.0f));
        assert(near(focal, native_focal)); // Existing geometry retains its pixel size.
        assert(near(1200.0f / (2.0f * std::tan(v * degrees_to_radians / 2.0f)), native_focal));
        const float added_top_pixels = (std::tan(v * degrees_to_radians / 2.0f)
            - std::tan(native_vertical * degrees_to_radians / 2.0f)) * focal;
        assert(near(added_top_pixels, 60.0f)); // 60 pixels above + 60 below = 120 new rows.
        const auto restored = narrow.restore(full);
        assert(near(restored.fov, letterboxed.fov));
        assert(near(restored.aspect, 1.6f)); // Calibration must not corrupt exact restore.
        assert(restored.vertical);
    }

    // Engine aiming changes remain a fresh native baseline; alternating aim,
    // output resolution and axis must not accumulate prior corrected values.
    for (int cycle = 0; cycle < 1000; ++cycle) {
        CameraProjectionOverride aim;
        const bool axis = cycle % 2 != 0;
        const float ratio = cycle % 3 == 0 ? 4.0f / 3.0f : 1.6f;
        const auto hip = aim.apply_re8(letterboxed, ratio, axis);
        const CameraProjection native_aim{40.0f, 1.6f, true};
        const auto aimed = aim.apply_re8(native_aim, ratio, axis);
        const float aim_h = aimed.vertical ? vertical_to_horizontal(aimed.fov, aimed.aspect) : aimed.fov;
        assert(near(aim_h, vertical_to_horizontal(40.0f, reference_aspect)));
        const auto repeated = aim.apply_re8(aimed, ratio, axis);
        assert(near(aimed.fov, repeated.fov));
        const auto restored = aim.restore(repeated);
        assert(near(restored.fov, 40.0f) && near(restored.aspect, 1.6f) && restored.vertical);
        assert(aim_h < (hip.vertical ? vertical_to_horizontal(hip.fov, hip.aspect) : hip.fov));
    }

    // Native Hor+ up to 32:9 is already included in the engine's horizontal
    // scalar. Correct beyond that bound, without expanding the existing view twice.
    const float ultrawide_h = vertical_to_horizontal(native_vertical, 32.0f / 9.0f);
    CameraProjectionOverride ultrawide;
    const auto wide = ultrawide.apply_re8({ultrawide_h, 32.0f / 9.0f, false}, 32.0f / 9.0f, false);
    assert(near(wide.fov, ultrawide_h));
    CameraProjectionOverride beyond;
    const auto wider = beyond.apply_re8({ultrawide_h, 48.0f / 9.0f, false}, 48.0f / 9.0f, false);
    assert(near(horizontal_to_vertical(wider.fov, wider.aspect), native_vertical));
    assert(near(beyond.restore(wider).aspect, 48.0f / 9.0f));

    std::mt19937 random{0x250};
    std::uniform_int_distribution<int> widths{320, 16384}, heights{240, 4320};
    for (int i = 0; i < 100000; ++i) {
        const float width = static_cast<float>(widths(random));
        const float height = static_cast<float>(heights(random));
        const float ratio = width / height;
        const float native_ratio = std::clamp(ratio, reference_aspect, 32.0f / 9.0f);
        const float native_h = vertical_to_horizontal(native_vertical, native_ratio);
        const CameraProjection source{i % 2 ? native_vertical : native_h, ratio, i % 2 != 0};
        CameraProjectionOverride pass;
        const auto result = pass.apply_re8(source, ratio, i % 3 == 0);
        const float h = result.vertical ? vertical_to_horizontal(result.fov, ratio) : result.fov;
        const float v = result.vertical ? result.fov : horizontal_to_vertical(result.fov, ratio);
        assert(valid_fov(h) && valid_fov(v));
        assert(h + 0.002f >= native_h && v + 0.002f >= native_vertical);
        const float x_scale = width / std::tan(h * degrees_to_radians / 2.0f);
        const float y_scale = height / std::tan(v * degrees_to_radians / 2.0f);
        assert(std::abs(x_scale / y_scale - 1.0f) < 0.0001f);
        assert(near(pass.apply_re8(result, ratio, result.vertical).fov, result.fov));
        const auto restored = pass.restore(result);
        assert(near(restored.fov, source.fov) && near(restored.aspect, source.aspect)
            && restored.vertical == source.vertical);
    }
    assert(near(re8_authored_aspect(std::numeric_limits<float>::quiet_NaN()), reference_aspect));
    CameraProjectionOverride invalid;
    const CameraProjection invalid_source{0, 1.6f, true};
    assert(invalid.apply_re8(invalid_source, 1.6f, false).fov == 0);
    assert(invalid.apply_re8(letterboxed, 0, false).fov == letterboxed.fov);
    std::cout << "PASS: camera restore, 10000 pass cycles, aim transitions, exact 16:10 pixel scale and 120 revealed rows, native Hor+, 100000 arbitrary resolutions, invalid inputs and setter limits.\n";
}
