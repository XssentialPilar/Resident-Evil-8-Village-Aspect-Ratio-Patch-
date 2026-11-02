#pragma once

#include <algorithm>
#include <cmath>

namespace re8_patch::display {
inline constexpr float reference_aspect = 16.0f / 9.0f;
inline constexpr float degrees_to_radians = 0.017453292519943295f;

inline bool valid_dimensions(float width, float height) {
    return std::isfinite(width) && std::isfinite(height) && width > 0.0f && height > 0.0f;
}

inline bool valid_fov(float degrees) {
    return std::isfinite(degrees) && degrees > 0.0f && degrees < 180.0f;
}

inline float horizontal_to_vertical(float horizontal, float aspect) {
    return 2.0f * std::atan(std::tan(horizontal * degrees_to_radians * 0.5f) / aspect) / degrees_to_radians;
}

inline float vertical_to_horizontal(float vertical, float aspect) {
    return 2.0f * std::atan(std::tan(vertical * degrees_to_radians * 0.5f) * aspect) / degrees_to_radians;
}

// Preserve horizontal coverage on narrow outputs (Vert+), vertical coverage on
// wide outputs (Hor+). This adjusts projection, never stretches a finished image.
// source_aspect is the camera's current projection, including native Hor+.
inline float expanded_fov(float source_fov, float source_aspect, float target_aspect,
                          bool source_vertical, bool target_vertical) {
    if (!valid_fov(source_fov) || !std::isfinite(source_aspect) || source_aspect <= 0.0f ||
        !std::isfinite(target_aspect) || target_aspect <= 0.0f) {
        return source_fov;
    }
    const float horizontal = source_vertical ? vertical_to_horizontal(source_fov, source_aspect) : source_fov;
    const float target_horizontal = target_aspect > source_aspect
        ? vertical_to_horizontal(horizontal_to_vertical(horizontal, source_aspect), target_aspect)
        : horizontal;
    const float result = target_vertical ? horizontal_to_vertical(target_horizontal, target_aspect) : target_horizontal;
    return std::clamp(result, 1.0f, 179.0f);
}

struct SafeArea {
    float x;
    float y;
    float width;
    float height;
};

// A centered, uniformly scaled 16:9 reference canvas; useful for diagnostics
// and matching the engine's FitSmallRatioAxis policy. No per-widget anchors
// are invented here; the engine retains responsibility for those controls.
inline SafeArea safe_area(float width, float height) {
    if (!valid_dimensions(width, height)) {
        return {};
    }
    const float safe_width = std::min(width, height * reference_aspect);
    const float safe_height = std::min(height, width / reference_aspect);
    return {(width - safe_width) * 0.5f, (height - safe_height) * 0.5f, safe_width, safe_height};
}
} // namespace re8_patch::display
