#pragma once

#include <algorithm>
#include <array>
#include <atomic>
#include <functional>
#include <mutex>
#include <span>
#include <string>
#include <string_view>
#include <utility>
#include <vector>
#include <Windows.h>
#include <reframework/API.hpp>
#include <hde64.h>
#include "RE8PluginContext.hpp"
#include "../common/RE8CursorPolicy.hpp"
#if defined(RE8_PLUGIN_WITH_MINHOOK)
#include <MinHook.h>
#endif

namespace re8_plugin {
class Cursor {
    using API = reframework::API;
    using Object = API::ManagedObject;
    using Type = API::TypeDefinition;
    using Method = API::Method;
    using Field = API::Field;
public:
    static Cursor& get() { static Cursor instance; return instance; }
    void initialize(Context& context) {
        m_context = &context;
        const auto config = context.config();
        m_enabled.store(config.enabled && config.cursor_enabled);
        m_diagnostics.store(config.diagnostics || m_environment_diagnostics);
        m_window.store(context.window());
    }
    void on_frame() {
        if (m_context == nullptr) return;
        const auto config = m_context->config();
        const bool enabled = (config.enabled && config.cursor_enabled) || m_context->own_ui_open();
        if (m_enabled.exchange(enabled) != enabled) request_apply();
        if (!enabled) restore_software_panel();
        m_diagnostics.store(config.diagnostics || m_environment_diagnostics);
        const auto window = m_context->window();
        if (window != nullptr && m_window.load() == nullptr) m_window.store(window);
        set_patch_config_open(m_context->is_drawing_ui());
        if (!m_gui_updated.exchange(false)) update("present-fallback");
    }
    void on_gui_update() { update("post-UpdateGUI"); m_gui_updated.store(true); }
    void set_patch_config_open(bool open) {
        std::scoped_lock lock{m_state_mutex};
        m_patch_config_open.store(open);
        publish(m_menu_visible.load(), "patch-config");
    }
    bool game_menu_visible() const { return m_menu_visible.load(); }
    bool authorized_menu_visible(std::string_view name) {
        std::scoped_lock lock{m_state_mutex};
        for (const auto& menu : m_menus)
            if (name == menu.field->get_name()) return menu.last_effective;
        return false;
    }
    size_t menu_count() { std::scoped_lock lock{m_state_mutex}; return m_menus.size(); }
    bool authority_ready() const { return m_ready.load(); }
    double last_apply_ms() const { return m_last_apply_us.load() / 1000.0; }

    // The public host callback must continue to return true: the host otherwise
    // calls DefWindowProc, which can replace our cursor. Our own subclass returns
    // TRUE directly for handled WM_SETCURSOR messages, on the owning UI thread.
    bool on_message(HWND window, UINT message, WPARAM, LPARAM) {
        if (message != WM_NCDESTROY && window != nullptr && !m_subclassed.load() &&
            GetWindowThreadProcessId(window, nullptr) == GetCurrentThreadId()) {
            install_window_subclass(window);
        }
        return true;
    }

    // Hide only the visual panel. The original GUI draw still runs, including
    // its layout and input bookkeeping; suppressing the whole GUI broke input.
    bool on_pre_gui_draw_element(void* element, void*) {
        if (!m_enabled.load() || !m_ready.load() || element == nullptr || m_cursor_type == nullptr) return true;
        std::scoped_lock lock{m_state_mutex};
        auto object = static_cast<Object*>(element);
        if (!valid(object)) return true;
        Object* cursor = is_type(object, m_cursor_type) ? object : nullptr;
        if (cursor == nullptr && m_component_object != nullptr && m_get_component != nullptr && m_cursor_runtime_type != nullptr) {
            const auto owner = m_component_object->invoke(object, std::vector<void*>{});
            if (!owner.exception_thrown && owner.ptr != nullptr) {
                const auto result = m_get_component->invoke(static_cast<Object*>(owner.ptr), std::vector<void*>{m_cursor_runtime_type});
                if (!result.exception_thrown) cursor = static_cast<Object*>(result.ptr);
            }
        }
        if (cursor == nullptr || m_cursor_panel_get == nullptr || m_invisible_get == nullptr || m_invisible_set == nullptr) return true;
        const auto result = m_cursor_panel_get->invoke(cursor, std::vector<void*>{});
        auto panel = !result.exception_thrown ? static_cast<Object*>(result.ptr) : nullptr;
        if (panel == nullptr) return true;
        if (panel != m_hidden_panel) {
            restore_software_panel();
            const auto invisible = m_invisible_get->invoke(panel, std::vector<void*>{});
            if (invisible.exception_thrown) return true;
            m_hidden_panel = panel; panel->add_ref();
            m_panel_was_invisible = invisible.byte != 0;
        }
        m_invisible_set->invoke(panel, std::vector<void*>{reinterpret_cast<void*>(uintptr_t{1})});
        return true;
    }

private:
    struct MenuState { Field* field{}; bool closing{}, last_showing{}, last_effective{}; };
    struct PolicyRequest { uint64_t sequence{}; bool visible{}; int64_t qpc{}; };
    struct HookSlot {
        std::function<void(int, void**)> pre;
        std::function<void()> post;
    };
    static constexpr size_t hook_capacity = 24;
    Context* m_context{};
    std::recursive_mutex m_state_mutex;
    std::mutex m_policy_mutex;
    std::vector<MenuState> m_menus;
    std::vector<void*> m_hook_entries;
    std::vector<std::pair<Method*, unsigned int>> m_hooks;
    std::array<HookSlot, hook_capacity> m_slots{};
    size_t m_slot_count{};
    Method* m_query{};
    Field* m_driver_status{};
    Type* m_driver_type{};
    Type* m_cursor_type{};
    Object* m_cursor_runtime_type{};
    Method* m_component_object{};
    Method* m_get_component{};
    Method* m_cursor_panel_get{};
    Method* m_invisible_get{};
    Method* m_invisible_set{};
    Object* m_hidden_panel{};
    bool m_panel_was_invisible{};
    bool m_initialized{};
    std::atomic<bool> m_ready{}, m_gui_updated{}, m_menu_visible{}, m_patch_config_open{};
    std::atomic<bool> m_desired{}, m_apply_pending{}, m_diagnostics{}, m_subclassed{};
    std::atomic<bool> m_enabled{true};
    std::atomic<HWND> m_window{};
    PolicyRequest m_policy;
    uint64_t m_measured_sequence{};
    std::atomic<int64_t> m_last_apply_us{};
    WNDPROC m_previous_proc{};
    HCURSOR m_arrow{LoadCursorW(nullptr, MAKEINTRESOURCEW(32512))};
    UINT m_apply_message{RegisterWindowMessageW(L"RE8Display.Cursor.Apply")};
    int m_visibility_adjustments{}; // Window-owner thread only.
    using SetCursorFn = HCURSOR (WINAPI*)(HCURSOR);
    SetCursorFn m_original_set_cursor{};
    using SetCursorPosFn = BOOL (WINAPI*)(int, int);
    SetCursorPosFn m_original_set_position{};
    const bool m_environment_diagnostics{[] {
        wchar_t value[2]{};
        return GetEnvironmentVariableW(L"RE8PATCH_CURSOR_DIAGNOSTICS", value, 2) == 1 && value[0] == L'1';
    }()};

    static API& api() { return *API::get(); }
    static bool valid(Object* object) { return object != nullptr && object->is_managed_object(); }
    static bool is_type(Object* object, Type* expected) {
        if (expected == nullptr || !valid(object)) return false;
        const auto type = object->get_type_definition();
        return type != nullptr && (type == expected || type->is_derived_from(expected));
    }
    static bool parameter(Method* method, size_t index, std::string_view expected) {
        const auto params = method->get_params();
        if (index >= params.size() || params[index].t == nullptr) return false;
        return reinterpret_cast<Type*>(params[index].t)->get_full_name() == expected;
    }
    static bool returns(Method* method, std::string_view expected) {
        const auto type = method->get_return_type();
        return type != nullptr && type->get_full_name() == expected;
    }
    static bool request_method(Method* method) {
        return method != nullptr && !method->is_static() && method->get_function_raw() != nullptr &&
            method->get_num_params() == 1 && parameter(method, 0, "app.GUIRequest.Parameter") &&
            returns(method, "app.GUIDriver.ExecuteResult.Value");
    }
    static bool focused_client(HWND window) {
        if (window == nullptr || GetForegroundWindow() != window || IsIconic(window)) return false;
        POINT point{}; RECT client{};
        return GetCursorPos(&point) && ScreenToClient(window, &point) && GetClientRect(window, &client) && PtInRect(&client, point);
    }
    static HCURSOR WINAPI set_cursor_hook(HCURSOR requested) {
        auto& self = get();
        if (self.m_enabled.load() && focused_client(self.m_window.load()))
            requested = self.m_desired.load() ? self.m_arrow : nullptr;
        return self.m_original_set_cursor != nullptr ? self.m_original_set_cursor(requested) : nullptr;
    }
    static BOOL WINAPI set_position_hook(int x, int y) {
        auto& self = get();
        if (self.m_context != nullptr && self.m_context->own_ui_open() &&
            GetForegroundWindow() == self.m_window.load()) return TRUE;
        return self.m_original_set_position != nullptr ? self.m_original_set_position(x, y) : FALSE;
    }
    void install_native_hook() {
#if defined(RE8_PLUGIN_WITH_MINHOOK)
        const auto initialized = MH_Initialize();
        if (initialized != MH_OK && initialized != MH_ERROR_ALREADY_INITIALIZED) {
            api().log_error("[RE8Display.Cursor] MinHook initialization failed (%d)", int(initialized)); return;
        }
        const auto target = GetProcAddress(GetModuleHandleW(L"user32.dll"), "SetCursor");
        const auto created = MH_CreateHook(reinterpret_cast<void*>(target), reinterpret_cast<void*>(&set_cursor_hook),
                                          reinterpret_cast<void**>(&m_original_set_cursor));
        if (created != MH_OK || MH_EnableHook(reinterpret_cast<void*>(target)) != MH_OK)
            api().log_error("[RE8Display.Cursor] SetCursor hook unavailable; enforcement degraded (%d)", int(created));
        const auto position = GetProcAddress(GetModuleHandleW(L"user32.dll"), "SetCursorPos");
        if (position != nullptr && MH_CreateHook(reinterpret_cast<void*>(position), reinterpret_cast<void*>(&set_position_hook),
            reinterpret_cast<void**>(&m_original_set_position)) == MH_OK) MH_EnableHook(reinterpret_cast<void*>(position));
#else
        api().log_warn("[RE8Display.Cursor] Built without SetCursor interception; enforcement degraded");
#endif
    }
    void install_window_subclass(HWND window) {
        SetLastError(0);
        const auto previous = SetWindowLongPtrW(window, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(&window_proc));
        if (previous == 0 && GetLastError() != 0) {
            api().log_error("[RE8Display.Cursor] Window subclass failed (%lu)", GetLastError()); return;
        }
        m_previous_proc = reinterpret_cast<WNDPROC>(previous);
        m_window.store(window);
        m_subclassed.store(true);
        request_apply();
    }
    static LRESULT CALLBACK window_proc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
        auto& self = get();
        const auto previous = self.m_previous_proc;
        if (message == self.m_apply_message && self.m_apply_message != 0) {
            self.m_apply_pending.store(false); self.apply(window); return 0;
        }
        if (message == WM_KILLFOCUS || (message == WM_ACTIVATEAPP && !wparam) ||
            (message == WM_SIZE && wparam == SIZE_MINIMIZED)) self.restore_counter();
        if (self.m_enabled.load() && message == WM_SETCURSOR && LOWORD(lparam) == HTCLIENT && focused_client(window)) {
            self.apply(window); return TRUE;
        }
        if (message == WM_SETFOCUS || (message == WM_ACTIVATEAPP && wparam)) self.request_apply();
        if (message == WM_NCDESTROY) {
            self.restore_counter();
            if (GetWindowLongPtrW(window, GWLP_WNDPROC) == reinterpret_cast<LONG_PTR>(&window_proc))
                SetWindowLongPtrW(window, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(previous));
            self.m_subclassed.store(false); self.m_window.store(nullptr);
        }
        return previous != nullptr ? CallWindowProcW(previous, window, message, wparam, lparam)
                                   : DefWindowProcW(window, message, wparam, lparam);
    }

    template<size_t I> static int pre_callback(int count, void** args, REFrameworkTypeDefinitionHandle*, unsigned long long) {
        auto& self = get();
        try { if (self.m_ready.load() && self.m_slots[I].pre) self.m_slots[I].pre(count, args); }
        catch (...) { api().log_error("[RE8Display.Cursor] Transition pre-callback failed"); }
        return REFRAMEWORK_HOOK_CALL_ORIGINAL;
    }
    template<size_t I> static void post_callback(void**, REFrameworkTypeDefinitionHandle, unsigned long long) {
        auto& self = get();
        try { if (self.m_ready.load() && self.m_slots[I].post) self.m_slots[I].post(); }
        catch (...) { api().log_error("[RE8Display.Cursor] Transition post-callback failed"); }
    }
    template<size_t... I> static constexpr auto pre_callbacks(std::index_sequence<I...>) {
        return std::array<REFPreHookFn, sizeof...(I)>{&pre_callback<I>...};
    }
    template<size_t... I> static constexpr auto post_callbacks(std::index_sequence<I...>) {
        return std::array<REFPostHookFn, sizeof...(I)>{&post_callback<I>...};
    }
    void add_hook(Method* method, std::function<void(int, void**)> pre, std::function<void()> post) {
        if (method == nullptr || m_slot_count >= hook_capacity) return;
        const auto entry = method->get_function_raw();
        if (entry == nullptr || std::find(m_hook_entries.begin(), m_hook_entries.end(), entry) != m_hook_entries.end()) return;
        MEMORY_BASIC_INFORMATION region{};
        if (VirtualQuery(entry, &region, sizeof(region)) == 0 || region.State != MEM_COMMIT ||
            (region.Protect & (PAGE_GUARD | PAGE_NOACCESS)) != 0) return;
        const auto bytes = static_cast<const uint8_t*>(entry);
        // Inspect the entire minimum patch span: ICF stubs can begin with a
        // harmless instruction before RET. Never hook a folded empty body.
        size_t decoded{};
        while (decoded < 5) {
            if (reinterpret_cast<uintptr_t>(bytes + decoded + 15) > reinterpret_cast<uintptr_t>(region.BaseAddress) + region.RegionSize) return;
            hde64s instruction{};
            const auto length = hde64_disasm(bytes + decoded, &instruction);
            const auto opcode = instruction.opcode;
            if (length == 0 || (instruction.flags & F_ERROR) != 0 || opcode == 0xC2 || opcode == 0xC3 ||
                opcode == 0xCC || opcode == 0xE9 || opcode == 0xEB || (opcode == 0xFF && instruction.modrm_reg == 4)) {
                api().log_warn("[RE8Display.Cursor] Skipping trivial/jump method %s", method->get_name()); return;
            }
            decoded += length;
        }
        static constexpr auto pres = pre_callbacks(std::make_index_sequence<hook_capacity>{});
        static constexpr auto posts = post_callbacks(std::make_index_sequence<hook_capacity>{});
        auto& slot = m_slots[m_slot_count]; slot.pre = std::move(pre); slot.post = std::move(post);
        const auto id = method->add_hook(pres[m_slot_count], posts[m_slot_count], true);
        if (id != 0) { ++m_slot_count; m_hook_entries.push_back(entry); m_hooks.emplace_back(method, id); }
        else { slot.pre = {}; slot.post = {}; api().log_error("[RE8Display.Cursor] Hook failed for %s", method->get_name()); }
    }

    void prepare() {
        const auto tdb = api().tdb();
        if (tdb == nullptr) return;
        const auto define = tdb->find_type("app.MenuDefine");
        const auto manager = tdb->find_type("app.GUIManager");
        if (define == nullptr || manager == nullptr) return;
        m_initialized = true;
        install_native_hook();
        m_query = manager->find_method("isShowingGUI(System.UInt32)");
        if (m_query == nullptr) m_query = manager->find_method("isShowingGUI");
        if (m_query == nullptr || m_query->get_num_params() != 1 || !parameter(m_query, 0, "System.UInt32") ||
            !returns(m_query, "System.Boolean") || m_query->get_function_raw() == nullptr) {
            m_query = nullptr; api().log_error("[RE8Display.Cursor] Required menu-state signature unavailable"); return;
        }
        for (auto name : re8_patch::authorized_cursor_menus) {
            auto field = define->find_field(name);
            if (field != nullptr && field->is_static() && field->get_type() != nullptr && field->get_type()->get_full_name() == "System.UInt32")
                m_menus.push_back({field});
            else api().log_warn("[RE8Display.Cursor] Menu ID unavailable: %s", name.data());
        }
        for (auto name : {"hideGUI", "suicideGUI", "forceSuicideGUI", "createGUI"}) {
            auto method = manager->find_method(name);
            if (method == nullptr || method->is_static() || !parameter(method, 0, "System.UInt32")) continue;
            const bool closing = std::string_view{name} != "createGUI";
            add_hook(method, [this, closing, name](int count, void** args) {
                if (count > 2) set_closing(static_cast<uint32_t>(reinterpret_cast<uintptr_t>(args[2])), closing, name);
            }, [this, name] { update(std::string{name} + ".post"); });
        }
        m_driver_type = tdb->find_type("app.GUIDriver");
        if (m_driver_type != nullptr) {
            m_driver_status = m_driver_type->find_field("guiStatus");
            for (auto name : {"show", "hide", "suicide"}) {
                auto method = m_driver_type->find_method(name);
                if (!request_method(method)) continue;
                const bool closing = std::string_view{name} != "show";
                add_hook(method, [this, closing, name](int count, void** args) {
                    if (count > 1) driver_transition(static_cast<Object*>(args[1]), closing, std::string{"driver."} + name);
                }, [this, name] { update(std::string{"driver."} + name + ".post"); });
            }
        }
        for (auto type_name : {"app.GUISaveLoad", "app.GUISaveDataTransition"}) {
            const auto type = tdb->find_type(type_name);
            auto method = type != nullptr ? type->find_method("openList") : nullptr;
            if (!request_method(method)) continue;
            add_hook(method, [this, type, type_name](int count, void** args) {
                if (count > 1 && is_type(static_cast<Object*>(args[1]), type))
                    driver_transition(static_cast<Object*>(args[1]), false, std::string{type_name} + ".openList");
            }, [this, type_name] { update(std::string{type_name} + ".openList.post"); });
        }
        const auto navigation = tdb->find_type("app.MenuManager");
        if (navigation != nullptr) for (auto name : {"pushMenu", "popMenu", "clear"}) {
            auto method = navigation->find_method(name);
            if (method == nullptr || method->is_static()) continue;
            if (std::string_view{name} == "clear" ? method->get_num_params() != 0 :
                (method->get_num_params() != 1 || !parameter(method, 0, "System.UInt32"))) continue;
            const bool opening = std::string_view{name} == "pushMenu";
            add_hook(method, [this, opening, name](int count, void** args) {
                if (opening && count > 2) set_closing(static_cast<uint32_t>(reinterpret_cast<uintptr_t>(args[2])), false, name);
            }, [this, name] { update(std::string{"navigation."} + name + ".post"); });
        }
        m_cursor_type = tdb->find_type("app.GUIMouseCursor");
        if (m_cursor_type != nullptr) {
            m_cursor_runtime_type = m_cursor_type->get_runtime_type();
            // The cursor arrow and its yellow hover glow occupy different
            // children. Hide their typed visual root, not only cursorPanel.
            m_cursor_panel_get = m_cursor_type->find_method("get_mainPanel");
            if (m_cursor_panel_get == nullptr) m_cursor_panel_get = m_cursor_type->find_method("get_cursorPanel");
        }
        const auto play = tdb->find_type("via.gui.PlayObject");
        if (play != nullptr) {
            m_invisible_get = play->find_method("get_ForceInvisible");
            m_invisible_set = play->find_method("set_ForceInvisible");
        }
        const auto component = tdb->find_type("via.Component");
        const auto object = tdb->find_type("via.GameObject");
        if (component != nullptr) m_component_object = component->find_method("get_GameObject");
        if (object != nullptr) m_get_component = object->find_method("getComponent(System.Type)");
        m_ready.store(true);
        api().log_info("[RE8Display.Cursor] Public API authority initialized: %zu menu IDs, %zu hooks", m_menus.size(), m_hooks.size());
        request_apply();
    }

    void update(std::string_view reason) {
        if (m_context == nullptr) return;
        std::unique_lock lock{m_state_mutex, std::try_to_lock};
        if (!lock.owns_lock()) return;
        if (!m_initialized) prepare();
        if (!m_ready.load()) return;
        bool visible = false;
        const auto manager = api().get_managed_singleton("app.GUIManager");
        if (manager != nullptr) for (auto& menu : m_menus) {
            const auto data = menu.field->get_data_raw(nullptr);
            if (data == nullptr) continue;
            const auto hash = *static_cast<const uint32_t*>(data);
            if (hash == 0) continue;
            std::array<void*, 1> args{reinterpret_cast<void*>(static_cast<uintptr_t>(hash))};
            const auto result = m_query->invoke(manager, std::span<void*>{args});
            const bool showing = !result.exception_thrown && result.byte != 0;
            const bool effective = showing && !menu.closing;
            if (m_diagnostics.load() && (showing != menu.last_showing || effective != menu.last_effective))
                api().log_info("[RE8Display.Cursor] menu-edge name=%s hash=%08x showing=%d closing=%d effective=%d reason=%.*s",
                    menu.field->get_name(), hash, int(showing), int(menu.closing), int(effective), int(reason.size()), reason.data());
            menu.last_showing = showing; menu.last_effective = effective;
            visible = visible || effective;
        }
        publish(visible, reason);
    }
    void driver_transition(Object* driver, bool closing, std::string_view reason) {
        if (m_driver_status == nullptr || !is_type(driver, m_driver_type)) return;
        const auto data = m_driver_status->get_data_raw(driver);
        const auto status = data != nullptr ? *static_cast<Object**>(data) : nullptr;
        if (!valid(status) || status->get_type_definition() == nullptr) return;
        const auto field = status->get_type_definition()->find_field("<hash>k__BackingField");
        if (field == nullptr || field->get_type() == nullptr || field->get_type()->get_full_name() != "System.UInt32") return;
        const auto hash = field->get_data_raw(status);
        if (hash != nullptr) set_closing(*static_cast<const uint32_t*>(hash), closing, reason);
    }
    void set_closing(uint32_t hash, bool closing, std::string_view reason) {
        std::scoped_lock lock{m_state_mutex};
        bool matched = false;
        for (auto& menu : m_menus) {
            const auto data = menu.field->get_data_raw(nullptr);
            if (data != nullptr && *static_cast<const uint32_t*>(data) == hash) {
                if (m_diagnostics.load()) api().log_info("[RE8Display.Cursor] lifecycle name=%s hash=%08x closing=%d previous=%d operation=%.*s",
                    menu.field->get_name(), hash, int(closing), int(menu.closing), int(reason.size()), reason.data());
                menu.closing = closing; matched = true;
            }
        }
        if (matched) update(reason);
    }
    void publish(bool visible, std::string_view reason) {
        m_menu_visible.store(visible);
        const bool desired = re8_patch::should_show_native_cursor(visible, m_patch_config_open.load(), true);
        PolicyRequest request;
        {
            std::scoped_lock lock{m_policy_mutex};
            if (m_desired.load() == desired) return;
            LARGE_INTEGER now{}; QueryPerformanceCounter(&now);
            m_policy = {m_policy.sequence + 1, desired, now.QuadPart};
            m_desired.store(desired); request = m_policy;
        }
        if (m_diagnostics.load()) api().log_info("[RE8Display.Cursor] policy seq=%llu qpc=%lld visible=%d reason=%.*s",
            static_cast<unsigned long long>(request.sequence), static_cast<long long>(request.qpc), int(request.visible), int(reason.size()), reason.data());
        request_apply();
    }
    void request_apply() {
        const auto window = m_window.load();
        if (window == nullptr || !m_subclassed.load() || m_apply_message == 0) return;
        if (GetWindowThreadProcessId(window, nullptr) == GetCurrentThreadId()) apply(window);
        else if (!m_apply_pending.exchange(true) && !SendNotifyMessageW(window, m_apply_message, 0, 0)) m_apply_pending.store(false);
    }
    void restore_counter() { while (m_visibility_adjustments > 0) { ::ShowCursor(FALSE); --m_visibility_adjustments; } }
    void restore_software_panel() {
        std::scoped_lock lock{m_state_mutex};
        if (m_hidden_panel == nullptr) return;
        if (m_invisible_get != nullptr && m_invisible_set != nullptr) {
            const auto current = m_invisible_get->invoke(m_hidden_panel, std::vector<void*>{});
            if (!current.exception_thrown && current.byte != 0)
                m_invisible_set->invoke(m_hidden_panel, std::vector<void*>{reinterpret_cast<void*>(uintptr_t{m_panel_was_invisible ? 1u : 0u})});
        }
        m_hidden_panel->release(); m_hidden_panel = nullptr;
    }
    void apply(HWND window) {
        if (!m_enabled.load() || !focused_client(window)) { restore_counter(); return; }
        PolicyRequest applied; int64_t elapsed = -1, applied_qpc = 0;
        {
            std::scoped_lock lock{m_policy_mutex};
            applied = m_policy;
            ::SetCursor(applied.visible ? m_arrow : nullptr);
            if (!applied.visible) restore_counter();
            else {
                CURSORINFO info{sizeof(CURSORINFO)};
                if (GetCursorInfo(&info) && (info.flags & CURSOR_SHOWING) == 0) {
                    for (int attempt = 0; attempt < 32 && m_visibility_adjustments < 32; ++attempt) {
                        const auto count = ::ShowCursor(TRUE); ++m_visibility_adjustments; if (count >= 0) break;
                    }
                    if (m_visibility_adjustments == 32 && GetCursorInfo(&info) && (info.flags & CURSOR_SHOWING) == 0)
                        api().log_error("[RE8Display.Cursor] Visibility correction bound reached");
                }
            }
            if (applied.qpc != 0 && applied.sequence != m_measured_sequence) {
                LARGE_INTEGER now{}, frequency{}; QueryPerformanceCounter(&now); QueryPerformanceFrequency(&frequency);
                applied_qpc = now.QuadPart; elapsed = (applied_qpc - applied.qpc) * 1000000 / frequency.QuadPart;
                m_measured_sequence = applied.sequence; m_last_apply_us.store(elapsed);
            }
        }
        if (elapsed >= 0 && m_diagnostics.load()) api().log_info("[RE8Display.Cursor] apply seq=%llu request_qpc=%lld qpc=%lld visible=%d policy_to_apply_us=%lld",
            static_cast<unsigned long long>(applied.sequence), static_cast<long long>(applied.qpc), static_cast<long long>(applied_qpc), int(applied.visible), static_cast<long long>(elapsed));
    }
};
}
