#include "RE8PluginContext.hpp"
#include "RE8PluginCursor.hpp"
#include "RE8PluginDisplay.hpp"
#include <exception>

namespace re8_plugin {
namespace {
HMODULE plugin_module{};
std::atomic<bool> active{false};
std::atomic<bool> initialized{false};

// Invoke the host's exported C wrappers in the host's UI callback. No plugin
// ImGui context, renderer or C++ ImGui object is shared across DLL boundaries.
class ConfigPanel {
public:
    bool initialize(HMODULE host) {
        tree = resolve<Tree>(host, "igTreeNode_Str");
        tree_pop = resolve<Void>(host, "igTreePop");
        text = resolve<Text>(host, "igTextUnformatted");
        checkbox = resolve<Checkbox>(host, "igCheckbox");
        slider = resolve<Slider>(host, "igSliderFloat");
        separator = resolve<Void>(host, "igSeparator");
        button = resolve<Button>(host, "igSmallButton");
        begin = resolve<Begin>(host, "igBegin");
        end = resolve<Void>(host, "igEnd");
        set_size = resolve<SetSize>(host, "igSetNextWindowSize");
        size_constraints = resolve<SizeConstraints>(host, "igSetNextWindowSizeConstraints");
        push_wrap = resolve<PushWrap>(host, "igPushTextWrapPos");
        pop_wrap = resolve<Void>(host, "igPopTextWrapPos");
        return available = tree && tree_pop && text && checkbox && slider && separator && button && begin && end;
    }
    void draw() const {
        if (!available || !tree("Aspect Ratio Config Menu")) return;
        struct Pop { Void function; ~Pop() { function(); } } pop{tree_pop};
        say("RE8Display 2.5.0");
        const auto shortcut = "Open menu: " + Context::get().menu_key_name();
        say(shortcut.c_str());
        if (button("Open display settings")) Context::get().set_own_ui_open(true);
    }
    void draw_window() const {
        auto& context = Context::get();
        if (!available || !context.own_ui_open()) return;
        bool open = true;
        const auto dimensions = context.output_dimensions().value_or(std::array<float, 2>{640, 480});
        const auto bounds = re8_patch::display::config_window_bounds(dimensions[0], dimensions[1]);
        if (size_constraints) size_constraints({std::min(300.0f, bounds.max_width), std::min(160.0f, bounds.max_height)},
            {bounds.max_width, bounds.max_height}, nullptr, nullptr);
        if (set_size) set_size({std::min(480.0f, bounds.max_width), std::min(460.0f, bounds.max_height)}, 4);
        // A bounded, scrollable window; AlwaysAutoResize allowed long labels to
        // push the old panel outside small outputs and clip its bottom controls.
        if (begin("Aspect Ratio Config Menu - RE8Display 2.5.0", &open, 0)) draw_controls();
        end();
        context.set_own_ui_open(open);
    }
    void draw_controls() const {
        auto& context = Context::get();
        auto value = context.config();
        say("RE8Display 2.5.0");
        const auto shortcut = "Menu key: " + context.menu_key_name();
        say(shortcut.c_str());
        if (context.capturing_key()) say("Press a key to assign it. Escape cancels.");
        else if (button("Change menu key")) context.capture_key();
        if (button("Reset menu key to ;")) { value.menu_key = 0; context.set_config(value); }
        bool changed = checkbox("Enable RE8Display", &value.enabled);
        changed = checkbox("Native cursor in game menus", &value.cursor_enabled) || changed;
        changed = checkbox("Enable display correction", &value.display_enabled) || changed;
        if (value.display_enabled) {
            separator();
            changed = checkbox("Override FOV", &value.fov_override) || changed;
            if (value.fov_override) {
                say("Horizontal FOV (degrees)");
                changed = slider("##RE8DisplayFOVDegrees", &value.fov_degrees, 40.0f, 120.0f, "%.1f", 0) || changed;
            }
            else say("Automatic FOV: preserves the game's camera and aiming changes.");
            changed = checkbox("Use vertical FOV", &value.vertical_fov) || changed;
            changed = checkbox("Proportional game interface", &value.uniform_ui) || changed;
        }
        separator();
        say("Map input: original game controls.");
        changed = checkbox("Cursor diagnostics", &value.diagnostics) || changed;
        if (const auto dimensions = context.output_dimensions()) {
            char message[128]{};
            std::snprintf(message, sizeof(message), "Render output: %.0f x %.0f (%.4f:1)",
                (*dimensions)[0], (*dimensions)[1], (*dimensions)[0] / (*dimensions)[1]);
            say(message);
        } else say("Render output temporarily unavailable.");
        say("Other FOV/aspect mods must not override the same camera concurrently.");
        if (changed) context.set_config(value);
        if (button("Reload saved settings")) context.load_config();
    }
private:
    using Tree = bool (*)(const char*);
    using Void = void (*)();
    using Text = void (*)(const char*, const char*);
    using Checkbox = bool (*)(const char*, bool*);
    using Slider = bool (*)(const char*, float*, float, float, const char*, int);
    using Button = bool (*)(const char*);
    using Begin = bool (*)(const char*, bool*, int);
    struct Vec2 { float x, y; };
    using SetSize = void (*)(Vec2, int);
    using SizeConstraints = void (*)(Vec2, Vec2, void*, void*);
    using PushWrap = void (*)(float);
    Tree tree{}; Void tree_pop{}; Text text{}; Checkbox checkbox{};
    Slider slider{}; Void separator{}; Button button{}; bool available{};
    Begin begin{}; Void end{}; SetSize set_size{};
    SizeConstraints size_constraints{}; PushWrap push_wrap{}; Void pop_wrap{};
    template<typename Function> static Function resolve(HMODULE module, const char* name) {
        return reinterpret_cast<Function>(GetProcAddress(module, name));
    }
    void say(const char* message) const {
        const bool wrap = push_wrap != nullptr && pop_wrap != nullptr;
        if (wrap) push_wrap(0.0f);
        text(message, nullptr);
        if (wrap) pop_wrap();
    }
};
ConfigPanel panel;

template<typename Function> void guarded(const char* name, Function&& function) noexcept {
    if (!active.load(std::memory_order_acquire)) return;
    try { function(); }
    catch (const std::exception& error) { Context::get().api().log_error("[RE8Display] %s callback: %s", name, error.what()); }
    catch (...) { Context::get().api().log_error("[RE8Display] %s callback failed", name); }
}
void on_present() {
    guarded("present", [] {
        Context::get().refresh_renderer();
        Cursor::get().on_frame();
    });
}
void on_device_reset() { guarded("device-reset", [] {
    Context::get().invalidate_renderer();
    PluginDisplay::get().invalidate_renderer();
}); }
bool on_message(void* window, unsigned int message, unsigned long long wparam, long long lparam) {
    bool consumed = false;
    guarded("window-message", [&] {
        const auto handle = static_cast<HWND>(window);
        Context::get().observe_window(handle);
        Cursor::get().on_message(handle, message, static_cast<WPARAM>(wparam), static_cast<LPARAM>(lparam));
        consumed = Context::get().handle_message(handle, message, static_cast<WPARAM>(wparam), static_cast<LPARAM>(lparam));
        Cursor::get().set_patch_config_open(Context::get().is_drawing_ui());
    });
    // The cursor's own WndProc handles WM_SETCURSOR; preserve host dispatch.
    return !consumed;
}
void on_pre_behavior() { guarded("pre-behavior", [] { PluginDisplay::get().on_pre_application_entry("UpdateBehavior"); }); }
void on_post_behavior() { guarded("post-behavior", [] {
    Cursor::get().on_behavior_update();
    PluginDisplay::get().on_post_application_entry("UpdateBehavior");
}); }
void on_pre_gui() { guarded("pre-gui", [] { PluginDisplay::get().on_pre_application_entry("UpdateGUI"); }); }
void on_pre_lock_scene() { guarded("pre-lock-scene", [] { PluginDisplay::get().on_pre_application_entry("LockScene"); }); }
void on_post_lock_scene() { guarded("post-lock-scene", [] { PluginDisplay::get().on_post_application_entry("LockScene"); }); }
void on_pre_unlock_scene() { guarded("pre-unlock-scene", [] { PluginDisplay::get().on_pre_application_entry("UnlockScene"); }); }
void on_post_gui() {
    guarded("post-gui", [] {
        Cursor::get().on_gui_update();
        PluginDisplay::get().on_post_application_entry("UpdateGUI");
    });
}
bool on_gui_draw(void* element, void* primitive_context) {
    bool cursor_result{true}; bool display_result{true};
    guarded("gui-draw", [&] {
        cursor_result = Cursor::get().on_pre_gui_draw_element(element, primitive_context);
        display_result = PluginDisplay::get().on_pre_gui_draw_element(
            static_cast<reframework::API::ManagedObject*>(element), primitive_context);
    });
    return cursor_result && display_result;
}
void on_draw_ui(REFImGuiFrameCbData*) { guarded("config-panel", [] { panel.draw(); }); }
void on_imgui_frame(REFImGuiFrameCbData*) { guarded("independent-panel", [] { panel.draw_window(); }); }
} // namespace
} // namespace re8_plugin

extern "C" __declspec(dllexport) void reframework_plugin_required_version(REFrameworkPluginVersion* required) {
    if (required == nullptr) return;
    required->major = 1;
    required->minor = 15;
    required->patch = 0;
    required->game_name = "RE8";
}

extern "C" __declspec(dllexport) bool reframework_plugin_initialize(const REFrameworkPluginInitializeParam* param) {
    using namespace re8_plugin;
    // Version check precedes any access to the API 1.15 tail of the function table.
    if (param == nullptr || param->version == nullptr || param->functions == nullptr || param->sdk == nullptr ||
        param->version->major != 1 || param->version->minor < 15 ||
        param->version->game_name == nullptr || std::string_view{param->version->game_name} != "RE8") return false;
    if (initialized.exchange(true)) return true;
    bool callbacks_registered{false};
    try {
        reframework::API::initialize(param);
        auto& context = Context::get();
        context.initialize(plugin_module, param);
        const auto& functions = context.functions();
        if (!functions.on_present || !functions.on_device_reset || !functions.on_message ||
            !functions.on_pre_application_entry || !functions.on_post_application_entry ||
            !functions.on_pre_gui_draw_element || !functions.on_imgui_draw_ui || !functions.on_imgui_frame || !functions.is_drawing_ui) return false;
        if (!panel.initialize(static_cast<HMODULE>(param->reframework_module))) {
            context.api().log_warn("[RE8Display] Host cimgui exports unavailable; use RE8Display.ini for settings");
        }
        bool success{true};
        auto registration = [&](bool result) { callbacks_registered = callbacks_registered || result; success = success && result; };
        registration(functions.on_present(&on_present));
        registration(functions.on_device_reset(&on_device_reset));
        registration(functions.on_message(&on_message));
        registration(functions.on_pre_application_entry("UpdateBehavior", &on_pre_behavior));
        registration(functions.on_post_application_entry("UpdateBehavior", &on_post_behavior));
        registration(functions.on_pre_application_entry("UpdateGUI", &on_pre_gui));
        registration(functions.on_post_application_entry("UpdateGUI", &on_post_gui));
        registration(functions.on_pre_application_entry("LockScene", &on_pre_lock_scene));
        registration(functions.on_post_application_entry("LockScene", &on_post_lock_scene));
        registration(functions.on_pre_application_entry("UnlockScene", &on_pre_unlock_scene));
        registration(functions.on_pre_gui_draw_element(&on_gui_draw));
        registration(functions.on_imgui_draw_ui(&on_draw_ui));
        registration(functions.on_imgui_frame(&on_imgui_frame));
        if (!success) {
            context.api().log_error("[RE8Display] Callback registration failed; plugin remains resident but inactive");
            return callbacks_registered; // No unregister API: never unload live callback addresses.
        }
        Cursor::get().initialize(context);
        active.store(true, std::memory_order_release);
        context.api().log_info("[RE8Display] Plugin %s initialized; public API 1.15, own INI, no replacement loader", version);
        return true;
    } catch (const std::exception& error) {
        if (param->functions->log_error) param->functions->log_error("[RE8Display] Initialization failed: %s", error.what());
    } catch (...) {
        if (param->functions->log_error) param->functions->log_error("[RE8Display] Initialization failed");
    }
    active.store(false, std::memory_order_release);
    if (callbacks_registered) {
        auto disabled = Context::get().config(); disabled.enabled = false;
        Context::get().set_config(disabled, false);
    }
    return callbacks_registered;
}

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        re8_plugin::plugin_module = module;
        // Built with /MT: the static CRT requires thread attach/detach calls.
    }
    return TRUE;
}
