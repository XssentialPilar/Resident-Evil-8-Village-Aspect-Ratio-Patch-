#pragma once
#include <cmath>
#include <optional>

namespace re8_patch {
struct CursorPoint { float x{}, y{}; };
// Client coordinates and backbuffer coordinates are different spaces. Convert
// absolute position once; the cursor-only canvas uses the backbuffer extent.
inline std::optional<CursorPoint> cursor_pixels(float x, float y, float client_width,
    float client_height, float buffer_width, float buffer_height) {
    if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(client_width) ||
        !std::isfinite(client_height) || !std::isfinite(buffer_width) || !std::isfinite(buffer_height) ||
        client_width <= 0 || client_height <= 0 || buffer_width <= 0 || buffer_height <= 0 ||
        x < 0 || y < 0 || x >= client_width || y >= client_height) return std::nullopt;
    return CursorPoint{x * buffer_width / client_width, y * buffer_height / client_height};
}
inline CursorPoint cursor_normalized(CursorPoint pixels, float width, float height) {
    return {2.0f * pixels.x / width - 1.0f, 1.0f - 2.0f * pixels.y / height};
}
}
