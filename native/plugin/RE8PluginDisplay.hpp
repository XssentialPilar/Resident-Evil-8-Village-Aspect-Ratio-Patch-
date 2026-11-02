#pragma once
#include <array>
#include <bit>
#include <cstring>
#include <mutex>
#include <optional>
#include <string_view>
#include <unordered_map>
#include <vector>
#include "RE8PluginContext.hpp"
#include "RE8PluginCursor.hpp"
#include "../common/RE8CameraProjection.hpp"
#include "../common/RE8GuiLayout.hpp"

namespace re8_plugin {
// Only the public host API is used here. No SDK internals, fixed memory offsets,
// core Graphics settings, synthetic input or hard-coded camera object names.
class PluginDisplay {
    using API = reframework::API;
    using Object = API::ManagedObject;
    using Method = API::Method;
    using Projection = re8_patch::display::CameraProjection;
    using GuiState = re8_patch::display::GuiResolutionState;
    struct Size { float width{}, height{}; };
    struct ViewState { Size size{}, custom{}; int32_t display{}; };
    struct GuiEntry {
        re8_patch::display::GuiResolutionOverride state;
        uint64_t seen{};
    };
public:
    static PluginDisplay& get() { static PluginDisplay value; return value; }

    void on_frame() {
        std::scoped_lock lock{m_mutex};
        if (!initialize()) return;
        ++m_epoch;
        // The render pass has finished by the host ImGui/present callback.
        restore_cameras();
        const auto config = Context::get().config();
        cleanup_gui(!config.enabled || !config.display_enabled || !config.uniform_ui);
        if (!config.enabled || !config.display_enabled) restore_viewport();
    }

    void on_pre_application_entry(const char* entry) {
        if (entry == nullptr) return;
        std::scoped_lock lock{m_mutex};
        if (!initialize()) return;
        const std::string_view name{entry};
        if (name == "UnlockScene" || name == "UpdateBehavior") restore_cameras();
        if (name == "UpdateBehavior" || name == "UpdateGUI" || name == "LockScene") {
            apply_viewport();
            if (name == "UpdateGUI") refresh_gui();
        }
    }

    void on_post_application_entry(const char* entry) {
        if (entry == nullptr || std::string_view{entry} != "LockScene") return;
        std::scoped_lock lock{m_mutex};
        if (!initialize()) return;
        apply_viewport();
        // Render only: gameplay/aim code must never consume our corrected FOV as
        // its next native baseline. Restore before UnlockScene/next behavior.
        apply_camera();
    }

    bool on_pre_gui_draw_element(Object* element, void*) {
        std::scoped_lock lock{m_mutex};
        if (element == nullptr || !initialize()) return true;
        const auto config = Context::get().config();
        auto view = root_view(element);
        if (view == nullptr) return true;
        if (!config.enabled || !config.display_enabled || !config.uniform_ui) {
            restore_gui(view);
            return true;
        }
        // Solid full-screen fades deliberately cover the entire output.
        if (is_black_fade(element)) return true;
        apply_gui(view);
        return true; // Never suppress layout, interaction, or the original draw.
    }

private:
    std::recursive_mutex m_mutex;
    bool m_ready{};
    uint64_t m_epoch{};
    Object* m_view{};
    ViewState m_view_original{}, m_view_applied{};
    bool m_view_active{};
    std::unordered_map<Object*, re8_patch::display::CameraProjectionOverride> m_cameras;
    std::unordered_map<Object*, GuiEntry> m_gui;
    Method *m_main_view{}, *m_primary_camera{}, *m_size_get{}, *m_size_set{},
        *m_custom_get{}, *m_custom_set{}, *m_display_get{}, *m_display_set{},
        *m_fov_get{}, *m_fov_set{}, *m_aspect_get{}, *m_aspect_set{},
        *m_vertical_get{}, *m_vertical_set{}, *m_projection_get{},
        *m_gui_get_view{}, *m_view_type{}, *m_parent{}, *m_gui_size{},
        *m_scale_get{}, *m_scale_set{}, *m_anchor_get{}, *m_anchor_set{},
        *m_condition_get{}, *m_condition_set{}, *m_adjust_get{}, *m_adjust_set{},
        *m_component_object{}, *m_object_component{}, *m_name_get{}, *m_string_equals{};
    Object* m_gui_runtime_type{};
    Object* m_black_fade_name{};
    int32_t m_fit{}, m_letterbox{}, m_perspective{}, m_screen{}, m_fit_small{}, m_center{}, m_always{};

    static std::optional<reframework::InvokeRet> invoke(Method* method, Object* object,
                                                        std::vector<void*> args = {}) {
        if (method == nullptr || method->get_function_raw() == nullptr) return std::nullopt;
        const auto result = method->invoke(object, args);
        if (result.exception_thrown) return std::nullopt;
        return result;
    }
    static void* integer_argument(int32_t value) {
        return reinterpret_cast<void*>(static_cast<uintptr_t>(static_cast<uint32_t>(value)));
    }
    static void* float_argument(float value) {
        return reinterpret_cast<void*>(static_cast<uintptr_t>(std::bit_cast<uint32_t>(value)));
    }
    static std::optional<int32_t> enum_value(std::string_view type, std::string_view name) {
        const auto tdb = Context::get().api().tdb();
        if (tdb == nullptr) return std::nullopt;
        const auto definition = tdb->find_type(type);
        if (definition == nullptr) return std::nullopt;
        const auto field = definition->find_field(name);
        if (field == nullptr) return std::nullopt;
        auto data = field->get_init_data();
        if (data == nullptr) data = field->get_data_raw(nullptr, true);
        if (data == nullptr) return std::nullopt;
        int32_t value{};
        std::memcpy(&value, data, sizeof(value));
        return value;
    }
    static bool same_size(Size a, Size b) {
        return re8_patch::display::same_projection_value(a.width, b.width) &&
               re8_patch::display::same_projection_value(a.height, b.height);
    }
    static std::optional<Size> size_result(Method* method, Object* object, bool require_positive = true) {
        auto result = invoke(method, object);
        if (!result) return std::nullopt;
        Size size{};
        std::memcpy(&size, result->bytes.data(), sizeof(size));
        if (!std::isfinite(size.width) || !std::isfinite(size.height) ||
            (require_positive && !re8_patch::display::valid_dimensions(size.width, size.height))) return std::nullopt;
        return size;
    }

    bool initialize() {
        if (m_ready) return true;
        auto& api = Context::get().api();
        const auto tdb = api.tdb();
        if (tdb == nullptr || tdb->find_type("via.SceneView") == nullptr) return false;
        const auto method = [tdb](const char* type, const char* name) { return tdb->find_method(type, name); };
        m_main_view = method("via.SceneManager", "get_MainView");
        m_primary_camera = method("via.SceneView", "get_PrimaryCamera");
        m_size_get = method("via.SceneView", "get_Size"); m_size_set = method("via.SceneView", "set_Size");
        m_custom_get = method("via.SceneView", "get_CustomDisplaySize"); m_custom_set = method("via.SceneView", "set_CustomDisplaySize");
        m_display_get = method("via.SceneView", "get_DisplayType"); m_display_set = method("via.SceneView", "set_DisplayType");
        m_fov_get = method("via.Camera", "get_FOV"); m_fov_set = method("via.Camera", "set_FOV");
        m_aspect_get = method("via.Camera", "get_AspectRatio"); m_aspect_set = method("via.Camera", "set_AspectRatio");
        m_vertical_get = method("via.Camera", "get_VerticalEnable"); m_vertical_set = method("via.Camera", "set_VerticalEnable");
        m_projection_get = method("via.Camera", "get_ProjectionType");
        m_gui_get_view = method("via.gui.GUI", "get_View");
        m_view_type = method("via.gui.View", "get_ViewType"); m_gui_size = method("via.gui.View", "get_ScreenSize");
        m_parent = method("via.gui.PlayObject", "get_Parent");
        m_scale_get = method("via.gui.TransformObject", "get_ResAdjustScale"); m_scale_set = method("via.gui.TransformObject", "set_ResAdjustScale");
        m_anchor_get = method("via.gui.TransformObject", "get_ResAdjustAnchor"); m_anchor_set = method("via.gui.TransformObject", "set_ResAdjustAnchor");
        m_condition_get = method("via.gui.TransformObject", "get_ResAdjustCondition"); m_condition_set = method("via.gui.TransformObject", "set_ResAdjustCondition");
        m_adjust_get = method("via.gui.TransformObject", "get_ResolutionAdjust"); m_adjust_set = method("via.gui.TransformObject", "set_ResolutionAdjust");
        m_component_object = method("via.Component", "get_GameObject");
        m_object_component = method("via.GameObject", "getComponent(System.Type)");
        m_name_get = method("via.GameObject", "get_Name");
        m_string_equals = method("System.String", "Equals(System.String)");
        const auto fit = enum_value("via.DisplayType", "Fit");
        const auto letterbox = enum_value("via.DisplayType", "Uniform16x9");
        const auto perspective = enum_value("via.ProjectionType", "PerspectiveFovRH");
        const auto screen = enum_value("via.gui.ViewType", "Screen");
        const auto uniform_scale = enum_value("via.gui.ResolutionAdjustScale", "FitSmallRatioAxis");
        const auto center = enum_value("via.gui.ResolutionAdjustAnchor", "CenterCenter");
        const auto always = enum_value("via.gui.ResolutionAdjustCondition", "Always");
        if (!fit || !letterbox || !perspective || !screen || !uniform_scale || !center || !always) return false;
        for (auto required : {m_main_view, m_primary_camera, m_size_get, m_size_set, m_custom_get, m_custom_set,
                m_display_get, m_display_set, m_fov_get, m_fov_set, m_aspect_get, m_aspect_set,
                m_vertical_get, m_vertical_set, m_projection_get, m_gui_get_view, m_view_type,
                m_scale_get, m_scale_set, m_anchor_get, m_anchor_set, m_condition_get, m_condition_set,
                m_adjust_get, m_adjust_set}) {
            if (required == nullptr || required->get_function_raw() == nullptr) return false;
        }
        m_fit = *fit; m_letterbox = *letterbox; m_perspective = *perspective; m_screen = *screen;
        m_fit_small = *uniform_scale; m_center = *center; m_always = *always;
        m_gui_runtime_type = api.typeof("via.gui.GUI");
        if (m_gui_runtime_type != nullptr) m_gui_runtime_type->add_ref();
        m_black_fade_name = api.create_managed_string_normal("BlackFade");
        if (m_black_fade_name != nullptr) m_black_fade_name->add_ref();
        m_ready = true;
        api.log_info("[RE8Display] Public API controller ready; own automatic projection and root-only uniform GUI; legacy Graphics settings ignored");
        return true;
    }

    Object* main_view() const {
        auto manager = Context::get().api().get_native_singleton("via.SceneManager");
        if (manager == nullptr) return nullptr;
        const auto result = invoke(m_main_view, reinterpret_cast<Object*>(manager));
        return result ? static_cast<Object*>(result->ptr) : nullptr;
    }
    std::optional<ViewState> read_view(Object* view) const {
        const auto size = size_result(m_size_get, view), custom = size_result(m_custom_get, view, false);
        const auto display = invoke(m_display_get, view);
        if (!size || !custom || !display) return std::nullopt;
        return ViewState{*size, *custom, static_cast<int32_t>(display->dword)};
    }
    void write_view(Object* view, ViewState state) const {
        // Value-type arguments are pointers to their data in the public invoke
        // protocol (same rule used by the host ObjectExplorer).
        invoke(m_custom_set, view, {&state.custom});
        invoke(m_size_set, view, {&state.size});
        invoke(m_display_set, view, {integer_argument(state.display)});
    }
    void restore_viewport() {
        if (m_view == nullptr) return;
        if (const auto observed = read_view(m_view); observed && m_view_active) {
            auto restored = *observed;
            if (same_size(restored.size, m_view_applied.size)) restored.size = m_view_original.size;
            if (same_size(restored.custom, m_view_applied.custom)) restored.custom = m_view_original.custom;
            if (restored.display == m_view_applied.display) restored.display = m_view_original.display;
            write_view(m_view, restored);
        }
        m_view->release(); m_view = nullptr; m_view_active = false;
    }
    void apply_viewport() {
        const auto config = Context::get().config();
        if (!config.enabled || !config.display_enabled) { restore_viewport(); return; }
        const auto dimensions = Context::get().output_dimensions();
        auto view = main_view();
        if (view == nullptr || !dimensions) return;
        const auto state = read_view(view);
        if (!state) return;
        if (view != m_view) {
            restore_viewport(); m_view = view; m_view->add_ref();
            m_view_original = *state; m_view_active = true;
        } else {
            if (!same_size(state->size, m_view_applied.size)) m_view_original.size = state->size;
            if (!same_size(state->custom, m_view_applied.custom)) m_view_original.custom = state->custom;
            if (state->display != m_view_applied.display) m_view_original.display = state->display;
        }
        const Size output{(*dimensions)[0], (*dimensions)[1]};
        ViewState desired{output, output, m_fit};
        write_view(view, desired);
        if (const auto actual = read_view(view)) m_view_applied = *actual;
        else m_view_applied = desired;
    }

    std::optional<Projection> read_camera(Object* camera) const {
        const auto fov = invoke(m_fov_get, camera), aspect = invoke(m_aspect_get, camera), vertical = invoke(m_vertical_get, camera);
        if (!fov || !aspect || !vertical || !re8_patch::display::valid_fov(fov->f) ||
            !std::isfinite(aspect->f) || aspect->f <= 0.0f) return std::nullopt;
        return Projection{fov->f, aspect->f, vertical->byte != 0};
    }
    void write_camera(Object* camera, Projection projection) const {
        invoke(m_aspect_set, camera, {float_argument(projection.aspect)});
        invoke(m_vertical_set, camera, {integer_argument(projection.vertical ? 1 : 0)});
        invoke(m_fov_set, camera, {float_argument(projection.fov)});
    }
    void apply_camera() {
        const auto config = Context::get().config();
        const auto dimensions = Context::get().output_dimensions();
        if (!config.enabled || !config.display_enabled || !dimensions || m_view == nullptr) return;
        const float ratio = (*dimensions)[0] / (*dimensions)[1];
        const auto result = invoke(m_primary_camera, m_view);
        auto camera = result ? static_cast<Object*>(result->ptr) : nullptr;
        if (camera == nullptr) return;
        const auto type = invoke(m_projection_get, camera);
        if (!type || static_cast<int32_t>(type->dword) != m_perspective) return; // Map/orthographic cameras remain native.
        const auto observed = read_camera(camera);
        if (!observed) return;
        auto [entry, inserted] = m_cameras.try_emplace(camera);
        if (inserted) camera->add_ref();
        auto corrected = entry->second.apply(*observed, ratio, config.vertical_fov, false, 1.0f);
        if (config.fov_override && !Cursor::get().game_menu_visible()) {
            corrected.fov = re8_patch::display::expanded_fov(config.fov_degrees,
                re8_patch::display::reference_aspect, ratio, false, config.vertical_fov);
        }
        write_camera(camera, corrected);
        if (const auto actual = read_camera(camera)) entry->second.confirm_applied(*actual);
    }
    void restore_cameras() {
        for (auto& [camera, state] : m_cameras) {
            if (const auto observed = read_camera(camera)) write_camera(camera, state.restore(*observed));
            camera->release();
        }
        m_cameras.clear();
    }

    Object* component_object(Object* element) const {
        const auto result = invoke(m_component_object, element);
        return result ? static_cast<Object*>(result->ptr) : nullptr;
    }
    bool is_black_fade(Object* element) const {
        if (m_name_get == nullptr || m_string_equals == nullptr || m_black_fade_name == nullptr) return false;
        auto object = component_object(element);
        const auto name = object != nullptr ? invoke(m_name_get, object) : std::nullopt;
        if (!name || name->ptr == nullptr) return false;
        const auto equal = invoke(m_string_equals, static_cast<Object*>(name->ptr), {m_black_fade_name});
        return equal && equal->byte != 0;
    }
    Object* root_view(Object* element) const {
        if (element->get_type_definition() == nullptr) return nullptr;
        Object* gui = nullptr;
        const auto element_type = element->get_type_definition();
        if (element_type->get_full_name() == "via.gui.GUI" || element_type->is_derived_from("via.gui.GUI")) gui = element;
        else if (m_object_component != nullptr && m_gui_runtime_type != nullptr) {
            const auto object = component_object(element);
            const auto result = object != nullptr ? invoke(m_object_component, object, {m_gui_runtime_type}) : std::nullopt;
            if (result) gui = static_cast<Object*>(result->ptr);
        }
        if (gui == nullptr) return nullptr;
        const auto result = invoke(m_gui_get_view, gui);
        auto view = result ? static_cast<Object*>(result->ptr) : nullptr;
        if (view == nullptr) return nullptr;
        const auto type = invoke(m_view_type, view);
        if (!type || static_cast<int32_t>(type->dword) != m_screen) return nullptr;
        if (m_parent != nullptr) {
            const auto parent = invoke(m_parent, view);
            if (parent && parent->ptr != nullptr) return nullptr; // No nested scaling.
        }
        // Preserve the authored ScreenSize; it is the engine's reference canvas,
        // not another name for the physical output dimensions.
        if (m_gui_size != nullptr && !size_result(m_gui_size, view)) return nullptr;
        return view;
    }
    std::optional<GuiState> read_gui(Object* view) const {
        const auto scale = invoke(m_scale_get, view), anchor = invoke(m_anchor_get, view),
            condition = invoke(m_condition_get, view), enabled = invoke(m_adjust_get, view);
        if (!scale || !anchor || !condition || !enabled) return std::nullopt;
        return GuiState{static_cast<int32_t>(scale->dword), static_cast<int32_t>(anchor->dword),
                        static_cast<int32_t>(condition->dword), enabled->byte != 0};
    }
    void write_gui(Object* view, GuiState state) const {
        invoke(m_scale_set, view, {integer_argument(state.scale)});
        invoke(m_anchor_set, view, {integer_argument(state.anchor)});
        invoke(m_condition_set, view, {integer_argument(state.condition)});
        invoke(m_adjust_set, view, {integer_argument(state.enabled ? 1 : 0)});
    }
    void apply_gui(Object* view) {
        const auto observed = read_gui(view);
        if (!observed) return;
        auto [entry, inserted] = m_gui.try_emplace(view);
        if (inserted) view->add_ref();
        entry->second.seen = m_epoch;
        write_gui(view, entry->second.state.apply(*observed, m_fit_small, m_center, m_always));
    }
    void restore_gui(Object* view) {
        const auto entry = m_gui.find(view);
        if (entry == m_gui.end()) return;
        if (const auto observed = read_gui(view)) write_gui(view, entry->second.state.restore(*observed));
        view->release(); m_gui.erase(entry);
    }
    void cleanup_gui(bool all) {
        for (auto it = m_gui.begin(); it != m_gui.end();) {
            // References are held only while a root is actively drawing. Closed
            // screens are restored/released after two completed present epochs.
            if (all || m_epoch - it->second.seen > 2) {
                if (const auto observed = read_gui(it->first)) write_gui(it->first, it->second.state.restore(*observed));
                it->first->release(); it = m_gui.erase(it);
            } else ++it;
        }
    }
    void refresh_gui() {
        const auto config = Context::get().config();
        if (!config.enabled || !config.display_enabled || !config.uniform_ui) { cleanup_gui(true); return; }
        // Keep the SAME engine resolution transform active for native mouse
        // hit-testing and drawing. No physical/virtual coordinate replacement.
        for (auto& [view, entry] : m_gui) {
            if (const auto observed = read_gui(view))
                write_gui(view, entry.state.apply(*observed, m_fit_small, m_center, m_always));
        }
    }
};
}
