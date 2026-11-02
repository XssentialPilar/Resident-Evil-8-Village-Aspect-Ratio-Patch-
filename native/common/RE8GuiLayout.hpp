#pragma once
#include <cstdint>
#include <algorithm>
#include <cmath>

namespace re8_patch::display {
struct ConfigWindowBounds { float max_width{}, max_height{}; };
inline ConfigWindowBounds config_window_bounds(float width, float height) {
    if (!std::isfinite(width) || !std::isfinite(height) || width <= 0 || height <= 0) return {};
    const float margin = std::min(12.0f, std::min(width, height) * 0.1f);
    return {width - margin * 2, height - margin * 2};
}
struct GuiResolutionState {
    int32_t scale{};
    int32_t anchor{};
    int32_t condition{};
    bool enabled{};
};

// Root views alone receive the engine's uniform resolution adjustment. Child
// widget sizes, scales, positions and designer anchors are never rewritten.
class GuiResolutionOverride {
public:
    GuiResolutionState apply(GuiResolutionState observed, int32_t fit, int32_t center, int32_t always) {
        if (!m_active) { m_original = observed; m_active = true; }
        else {
            if (observed.scale != m_applied.scale) m_original.scale = observed.scale;
            if (observed.anchor != m_applied.anchor) m_original.anchor = observed.anchor;
            if (observed.condition != m_applied.condition) m_original.condition = observed.condition;
            if (observed.enabled != m_applied.enabled) m_original.enabled = observed.enabled;
        }
        m_applied = {fit, center, always, true};
        return m_applied;
    }
    GuiResolutionState restore(GuiResolutionState observed) const {
        if (!m_active) return observed;
        if (observed.scale == m_applied.scale) observed.scale = m_original.scale;
        if (observed.anchor == m_applied.anchor) observed.anchor = m_original.anchor;
        if (observed.condition == m_applied.condition) observed.condition = m_original.condition;
        if (observed.enabled == m_applied.enabled) observed.enabled = m_original.enabled;
        return observed;
    }
private:
    bool m_active{};
    GuiResolutionState m_original{};
    GuiResolutionState m_applied{};
};
}
