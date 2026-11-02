#pragma once

#include <cstdint>
#include <optional>

namespace re8_patch::display {
// One policy belongs to one SceneView. A DXGI reset or an unavailable output
// size does not change that view's ownership or its persistent DisplayType.
class ViewportDisplayOverride {
public:
    std::optional<int32_t> update(std::optional<int32_t> observed, bool enabled, int32_t fit) {
        if (!observed) return std::nullopt;

        if (!enabled) {
            if (!m_owned) return std::nullopt;
            if (*observed == m_applied && *observed != m_original) {
                // Retain ownership until a readback confirms the restoration.
                // A failed setter can therefore be retried safely next cycle.
                return m_original;
            }
            // Restored successfully, or another writer changed the value.
            m_owned = false;
            return std::nullopt;
        }

        if (!m_owned) {
            if (*observed == fit) return std::nullopt; // No mutation, no ownership.
            m_original = *observed;
            m_applied = fit;
            m_owned = true;
        } else if (*observed != m_applied) {
            // A genuine engine/mod update becomes the new restoration value.
            m_original = *observed;
        }

        m_applied = fit;
        return *observed == fit ? std::nullopt : std::optional<int32_t>{fit};
    }

    bool owns_override() const { return m_owned; }

private:
    bool m_owned{};
    int32_t m_original{};
    int32_t m_applied{};
};
} // namespace re8_patch::display
