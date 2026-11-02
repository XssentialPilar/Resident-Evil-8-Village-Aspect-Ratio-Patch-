#include "RE8ViewportPolicy.hpp"

#include <cassert>
#include <iostream>

using re8_patch::display::ViewportDisplayOverride;

int main() {
    constexpr int32_t fit = 0, letterbox = 2, external = 7;
    ViewportDisplayOverride policy;
    int32_t observed = letterbox;
    int writes = 0;
    const auto apply = [&](bool enabled) {
        if (const auto command = policy.update(observed, enabled, fit)) {
            observed = *command;
            ++writes;
        }
    };
    apply(true);
    assert(writes == 1 && observed == fit && policy.owns_override());
    for (int cycle = 0; cycle < 1000; ++cycle) {
        // Device reset -> output dimensions unavailable -> Present at the same
        // size. Neither event changes SceneView.DisplayType or its ownership.
        assert(!policy.update(std::nullopt, true, fit));
        assert(policy.owns_override());
        apply(true);
        apply(true);
        assert(writes == 1 && observed == fit);
    }
    apply(false);
    assert(writes == 2 && observed == letterbox);
    // Readback acknowledges that the previous restore command succeeded.
    apply(false);
    assert(writes == 2 && !policy.owns_override());

    // Losing observations while disabled cannot abandon a pending restoration.
    apply(true);
    assert(!policy.update(std::nullopt, false, fit));
    assert(policy.owns_override());
    const auto failed_restore = policy.update(observed, false, fit);
    assert(failed_restore == letterbox);
    assert(policy.update(observed, false, fit) == letterbox); // Retry failed setter.
    observed = letterbox;
    assert(!policy.update(observed, false, fit) && !policy.owns_override());

    // An external override occurring at disable is left intact.
    apply(true);
    observed = external;
    const int before_external = writes;
    apply(false);
    assert(observed == external && writes == before_external && !policy.owns_override());

    // Engine changes while enabled are remembered before the requested Fit
    // correction is reapplied, then restored exactly on disable.
    observed = letterbox;
    apply(true);
    observed = external;
    apply(true);
    assert(observed == fit);
    apply(false);
    assert(observed == external);
    apply(false);
    assert(!policy.owns_override());

    // A view which already uses Fit is not claimed by the plugin.
    ViewportDisplayOverride already_fit;
    assert(!already_fit.update(fit, true, fit));
    assert(!already_fit.owns_override());
    assert(!already_fit.update(external, false, fit));

    // Caller restores and releases the old view before binding a fresh policy
    // to a replacement view; original DisplayType never leaks across objects.
    ViewportDisplayOverride old_view;
    assert(old_view.update(letterbox, true, fit) == fit);
    assert(old_view.update(fit, false, fit) == letterbox);
    assert(!old_view.update(letterbox, false, fit));
    ViewportDisplayOverride new_view;
    assert(new_view.update(external, true, fit) == fit);
    assert(new_view.update(fit, false, fit) == external);
    assert(!new_view.update(external, false, fit));
    assert(!new_view.owns_override() && !old_view.owns_override());

    std::cout << "PASS: persistent viewport across 1000 reset/missing-size cycles, one Fit write, disable readback/retries, external updates and view replacement.\n";
}
