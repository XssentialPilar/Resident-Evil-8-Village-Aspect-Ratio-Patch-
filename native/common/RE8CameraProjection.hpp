#pragma once
#include "RE8DisplayGeometry.hpp"

namespace re8_patch::display {
struct CameraProjection {
    float fov{};
    float aspect{};
    bool vertical{};
};

// RE8's authored FOV calibration spans 16:9 through native Hor+ up to 32:9,
// independently of the physical output. This calibration is distinct from the actual
// camera field: never overwrite the native snapshot with this inferred ratio.
inline float re8_authored_aspect(float camera_aspect) {
    if (!std::isfinite(camera_aspect) || camera_aspect <= 0.0f) return reference_aspect;
    return std::clamp(camera_aspect, reference_aspect, 32.0f / 9.0f);
}

inline bool same_projection_value(float a, float b) {
    return std::isfinite(a) && std::isfinite(b) && std::abs(a - b) < 0.0001f;
}

// A render-pass override owns only values it actually wrote. Repeated apply
// calls cannot treat an already corrected FOV as a new source calibration.
class CameraProjectionOverride {
public:
    CameraProjection apply(CameraProjection observed, float output_aspect,
                           bool output_vertical, bool manual, float multiplier,
                           bool re8_calibration = false) {
        if (!valid_fov(observed.fov) || !std::isfinite(observed.aspect) || observed.aspect <= 0 ||
            !std::isfinite(output_aspect) || output_aspect <= 0 ||
            (manual && (!std::isfinite(multiplier) || multiplier <= 0))) return observed;
        if (!m_active) {
            m_original = observed;
            m_active = true;
        } else {
            // Preserve genuine engine changes (aim, zoom, cutscene camera).
            // FOV and its axis form one quantity. A new engine/mod FOV is
            // authored in the observed axis, even if that axis equals ours.
            if (!same_projection_value(observed.fov, m_applied.fov) || observed.vertical != m_applied.vertical) {
                m_original.fov = observed.fov;
                m_original.vertical = observed.vertical;
            }
            if (!same_projection_value(observed.aspect, m_applied.aspect)) m_original.aspect = observed.aspect;
        }
        const float authored_aspect = re8_calibration
            ? re8_authored_aspect(m_original.aspect) : m_original.aspect;
        float corrected = expanded_fov(m_original.fov, authored_aspect,
                                       output_aspect, m_original.vertical, output_vertical);
        if (manual) {
            // Explicit opt-in legacy calibration: multiply the native scalar
            // before changing its axis, exactly as the old 1.715 setting did.
            // Converting native vertical -> horizontal first applies an extra
            // expansion and was the concrete regression in the failed build.
            corrected = std::clamp(m_original.fov * multiplier, 1.0f, 179.0f);
        }
        // The physical viewport and actual camera must use the SAME aspect.
        m_applied = {corrected, output_aspect, output_vertical};
        return m_applied;
    }

    CameraProjection apply_re8(CameraProjection observed, float output_aspect,
                               bool output_vertical) {
        return apply(observed, output_aspect, output_vertical, false, 1.0f, true);
    }

    CameraProjection restore(CameraProjection observed) const {
        if (!m_active) return observed;
        if (same_projection_value(observed.fov, m_applied.fov) && observed.vertical == m_applied.vertical) {
            observed.fov = m_original.fov;
            observed.vertical = m_original.vertical;
        }
        if (same_projection_value(observed.aspect, m_applied.aspect)) observed.aspect = m_original.aspect;
        return observed;
    }

    void confirm_applied(CameraProjection actual) {
        m_applied = actual; // Account for engine-side setter limits.
    }

private:
    bool m_active{};
    CameraProjection m_original{};
    CameraProjection m_applied{};
};
} // namespace re8_patch::display
