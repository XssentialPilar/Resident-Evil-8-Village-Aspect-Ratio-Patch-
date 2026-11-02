#pragma once
#include <Windows.h>
#include <dxgi.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <functional>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>
#include <reframework/API.hpp>

namespace re8_plugin {
inline constexpr char version[] = "2.1.0";

struct Config {
    bool enabled{true};
    bool cursor_enabled{true};
    bool display_enabled{true};
    bool fov_override{false};
    float fov_degrees{81.0f};
    bool vertical_fov{false};
    bool uniform_ui{true};
    bool diagnostics{false};
    int map_drag_button{0}; // Native controls; no speculative remapping.
    int menu_key{0}; // 0 = the ';' character in the current keyboard layout.
};

// Own state only. No private REFramework object, global config or renderer hook.
class Context {
public:
    static Context& get() { static Context instance; return instance; }
    reframework::API& api() const { return *reframework::API::get(); }
    const REFrameworkPluginFunctions& functions() const { return *m_param->functions; }
    const REFrameworkPluginInitializeParam& parameters() const { return *m_param; }

    void initialize(HMODULE module, const REFrameworkPluginInitializeParam* param) {
        m_param = param;
        std::array<wchar_t, 32768> path{};
        const DWORD length = GetModuleFileNameW(module, path.data(), static_cast<DWORD>(path.size()));
        if (length == 0 || length >= path.size()) throw std::runtime_error("Cannot locate RE8Display.dll");
        // PluginLoader loads <persistent>/reframework/plugins/RE8Display.dll.
        m_config_path = std::filesystem::path{path.data()}.parent_path().parent_path() / L"data" / L"RE8Display.ini";
        load_config();
        refresh_renderer();
    }

    Config config() const { std::scoped_lock lock{m_config_mutex}; return m_config; }
    void set_config(Config value, bool persist = true) {
        if (!std::isfinite(value.fov_degrees)) value.fov_degrees = 81.0f;
        value.fov_degrees = std::clamp(value.fov_degrees, 40.0f, 120.0f);
        value.map_drag_button = std::clamp(value.map_drag_button, 0, 5);
        value.menu_key = std::clamp(value.menu_key, 0, 255);
        { std::scoped_lock lock{m_config_mutex}; m_config = value; }
        if (persist) save_config(value);
    }
    const std::filesystem::path& config_path() const { return m_config_path; }

    void load_config() {
        Config value;
        auto boolean = [&](const wchar_t* key, bool fallback) {
            return GetPrivateProfileIntW(L"RE8Display", key, fallback ? 1 : 0, m_config_path.c_str()) != 0;
        };
        value.enabled = boolean(L"Enabled", value.enabled);
        value.cursor_enabled = boolean(L"NativeCursor", value.cursor_enabled);
        value.display_enabled = boolean(L"DisplayEnabled", value.display_enabled);
        value.fov_override = boolean(L"OverrideFOV", value.fov_override);
        value.vertical_fov = boolean(L"VerticalFOV", value.vertical_fov);
        value.uniform_ui = boolean(L"UniformUI", value.uniform_ui);
        value.diagnostics = boolean(L"Diagnostics", value.diagnostics);
        value.map_drag_button = GetPrivateProfileIntW(L"RE8Display", L"MapDragButton", 0, m_config_path.c_str());
        value.menu_key = GetPrivateProfileIntW(L"RE8Display", L"MenuKey", 0, m_config_path.c_str());
        wchar_t multiplier[64]{};
        GetPrivateProfileStringW(L"RE8Display", L"FOVDegrees", L"81.0", multiplier, 64, m_config_path.c_str());
        wchar_t* end{};
        const float parsed = std::wcstof(multiplier, &end);
        if (end != multiplier && *end == L'\0') value.fov_degrees = parsed;
        set_config(value, false);
    }

    HWND window() const { return m_window.load(std::memory_order_acquire); }
    void observe_window(HWND window) {
        if (window != nullptr) m_window.store(window, std::memory_order_release);
    }
    bool own_ui_open() const { return m_own_ui_open.load(); }
    void set_own_ui_open(bool open) { m_own_ui_open.store(open); if (!open) m_capture_key.store(false); }
    bool capturing_key() const { return m_capture_key.load(); }
    void capture_key() { m_capture_key.store(true); }
    bool is_drawing_ui() const { return own_ui_open() || (m_param != nullptr && functions().is_drawing_ui != nullptr && functions().is_drawing_ui()); }
    std::string menu_key_name() const {
        const auto key = config().menu_key;
        if (key == 0) return ";";
        const auto scan = MapVirtualKeyW(static_cast<UINT>(key), MAPVK_VK_TO_VSC);
        char name[64]{};
        if (GetKeyNameTextA(static_cast<LONG>(scan << 16), name, sizeof(name)) > 0) return name;
        return std::to_string(key);
    }
    // Runs on the window owner after the host has fed ImGui's Win32 backend.
    // A private shortcut leaves the host's Insert binding and config untouched.
    bool handle_message(HWND target, UINT message, WPARAM key, LPARAM detail) {
        if (GetForegroundWindow() != target) return false;
        if (message == WM_KEYDOWN && (detail & (1LL << 30)) == 0) {
            if (capturing_key()) {
                if (key == VK_ESCAPE) m_capture_key.store(false);
                else if (key != VK_SHIFT && key != VK_CONTROL && key != VK_MENU && key != VK_LWIN && key != VK_RWIN) {
                    auto value = config(); value.menu_key = static_cast<int>(key); set_config(value); m_capture_key.store(false);
                }
                return true;
            }
            auto value = config();
            const SHORT mapped = value.menu_key == 0 ? VkKeyScanExW(L';', GetKeyboardLayout(0)) : static_cast<SHORT>(value.menu_key);
            bool matches = mapped != -1 && key == (mapped & 0xff);
            if (value.menu_key == 0) {
                const auto modifiers = (mapped >> 8) & 7;
                matches = matches && bool(GetKeyState(VK_SHIFT) & 0x8000) == bool(modifiers & 1) &&
                    bool(GetKeyState(VK_CONTROL) & 0x8000) == bool(modifiers & 2) &&
                    bool(GetKeyState(VK_MENU) & 0x8000) == bool(modifiers & 4);
            }
            if (matches) { set_own_ui_open(!own_ui_open()); return true; }
            if (own_ui_open() && key == VK_ESCAPE) { set_own_ui_open(false); return true; }
        }
        return own_ui_open() && (message == WM_INPUT || (message >= WM_KEYFIRST && message <= WM_KEYLAST) ||
            (message >= WM_MOUSEFIRST && message <= WM_MOUSELAST));
    }
    bool focused_client() const {
        const auto target = window();
        POINT point{}; RECT bounds{};
        return target != nullptr && GetForegroundWindow() == target && !IsIconic(target) &&
            GetCursorPos(&point) && ScreenToClient(target, &point) &&
            GetClientRect(target, &bounds) && PtInRect(&bounds, point);
    }
    std::optional<std::array<float, 2>> output_dimensions() const {
        const auto target = window();
        if (target == nullptr || IsIconic(target)) return std::nullopt;
        std::scoped_lock lock{m_output_mutex};
        return m_output_dimensions;
    }
    void invalidate_renderer() {
        std::scoped_lock lock{m_output_mutex};
        m_output_dimensions.reset();
    }
    void refresh_renderer() {
        if (m_param == nullptr || m_param->renderer_data == nullptr || m_param->renderer_data->swapchain == nullptr) {
            invalidate_renderer(); return;
        }
        DXGI_SWAP_CHAIN_DESC desc{};
        const auto swapchain = static_cast<IDXGISwapChain*>(m_param->renderer_data->swapchain);
        if (FAILED(swapchain->GetDesc(&desc)) || desc.OutputWindow == nullptr ||
            desc.BufferDesc.Width == 0 || desc.BufferDesc.Height == 0) {
            invalidate_renderer(); return;
        }
        observe_window(desc.OutputWindow);
        std::scoped_lock lock{m_output_mutex};
        m_output_dimensions = std::array<float, 2>{static_cast<float>(desc.BufferDesc.Width), static_cast<float>(desc.BufferDesc.Height)};
    }

private:
    const REFrameworkPluginInitializeParam* m_param{};
    std::filesystem::path m_config_path;
    mutable std::mutex m_config_mutex;
    Config m_config;
    std::atomic<HWND> m_window{};
    mutable std::mutex m_output_mutex;
    std::optional<std::array<float, 2>> m_output_dimensions;
    std::atomic<bool> m_own_ui_open{}, m_capture_key{};

    void save_config(const Config& value) {
        std::error_code error;
        std::filesystem::create_directories(m_config_path.parent_path(), error);
        if (error) { api().log_error("[RE8Display] Cannot create own config directory: %s", error.message().c_str()); return; }
        bool saved = true;
        auto write = [&](const wchar_t* key, const wchar_t* text) {
            saved = WritePrivateProfileStringW(L"RE8Display", key, text, m_config_path.c_str()) != FALSE && saved;
        };
        auto boolean = [&](const wchar_t* key, bool flag) { write(key, flag ? L"1" : L"0"); };
        boolean(L"Enabled", value.enabled);
        boolean(L"NativeCursor", value.cursor_enabled);
        boolean(L"DisplayEnabled", value.display_enabled);
        boolean(L"OverrideFOV", value.fov_override);
        boolean(L"VerticalFOV", value.vertical_fov);
        boolean(L"UniformUI", value.uniform_ui);
        boolean(L"Diagnostics", value.diagnostics);
        wchar_t number[64]{};
        swprintf_s(number, L"%.6f", value.fov_degrees); write(L"FOVDegrees", number);
        swprintf_s(number, L"%d", value.map_drag_button); write(L"MapDragButton", number);
        swprintf_s(number, L"%d", value.menu_key); write(L"MenuKey", number);
        if (!saved) api().log_error("[RE8Display] Failed to save own INI settings (Win32=%lu)", GetLastError());
    }
};
} // namespace re8_plugin
