#include <Windows.h>
#include <d3d12.h>
#include <wrl/client.h>
#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <filesystem>
#include <mutex>
#include <string>
#include "system_exports.hpp"

namespace {
using Microsoft::WRL::ComPtr;
HMODULE own_module{};
HMODULE real_loader{};
ID3D12DeviceFactory* retained_factory{}; // Intentionally retained until process exit.
std::once_flag initialization;
thread_local bool initializing{};
std::atomic<bool> native_device_call_seen{};
std::atomic<bool> first_device_logged{};
std::atomic<bool> first_successful_device_logged{};
bool active{};

std::filesystem::path module_path(HMODULE module) {
    std::wstring value(32768, L'\0');
    const auto length = GetModuleFileNameW(module, value.data(), static_cast<DWORD>(value.size()));
    if (!length || length >= value.size()) return {};
    value.resize(length); return value;
}
void log(const wchar_t* format, ...) noexcept {
    const auto saved_error = GetLastError();
    try {
        wchar_t body[2048]{};
        va_list args; va_start(args, format);
        _vsnwprintf_s(body, _TRUNCATE, format, args); va_end(args);
        const auto directory = module_path(own_module).parent_path() / L"RE8Agility";
        CreateDirectoryW(directory.c_str(), nullptr);
        const auto file = CreateFileW((directory / L"bridge.log").c_str(), FILE_APPEND_DATA,
            FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file != INVALID_HANDLE_VALUE) {
            SYSTEMTIME now{}; GetLocalTime(&now);
            wchar_t line[2304]{};
            _snwprintf_s(line, _TRUNCATE, L"[%04u-%02u-%02u %02u:%02u:%02u.%03u pid=%lu] %s\r\n",
                now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond,
                now.wMilliseconds, GetCurrentProcessId(), body);
            const int bytes = WideCharToMultiByte(CP_UTF8, 0, line, -1, nullptr, 0, nullptr, nullptr);
            if (bytes > 1) {
                std::string utf8(static_cast<size_t>(bytes), '\0');
                WideCharToMultiByte(CP_UTF8, 0, line, -1, utf8.data(), bytes, nullptr, nullptr);
                DWORD written{}; WriteFile(file, utf8.data(), static_cast<DWORD>(bytes - 1), &written, nullptr);
            }
            CloseHandle(file);
        }
    } catch (...) {}
    SetLastError(saved_error);
}
bool is_target() noexcept {
    try { return _wcsicmp(module_path(nullptr).filename().c_str(), L"re8.exe") == 0; }
    catch (...) { return false; }
}
std::string utf8_path(std::wstring path) {
    if (path.empty() || path.back() != L'\\') path += L'\\';
    const auto size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, path.c_str(), -1,
        nullptr, 0, nullptr, nullptr);
    if (size <= 1) return {};
    std::string result(static_cast<size_t>(size), '\0');
    if (!WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, path.c_str(), -1,
        result.data(), size, nullptr, nullptr)) return {};
    result.pop_back(); return result;
}
void initialize_bridge() {
    initializing = true;
    struct Finish { ~Finish() { initializing = false; } } finish;
    const bool target = is_target();
    // Capture BEFORE loading the system loader. An already mapped Core might
    // own a device; changing global configuration could remove that device.
    const auto preexisting_core = GetModuleHandleW(L"D3D12Core.dll");
    wchar_t system_path[32768]{};
    const auto length = GetSystemDirectoryW(system_path, static_cast<UINT>(std::size(system_path)));
    if (!length || length >= std::size(system_path)) return;
    const auto loader_path = std::filesystem::path{system_path} / L"d3d12.dll";
    real_loader = LoadLibraryExW(loader_path.c_str(), nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!real_loader || real_loader == own_module) {
        real_loader = nullptr;
        if (target) log(L"ERROR system loader unavailable; Win32=%lu", GetLastError());
        return;
    }
    if (!target) return; // Every other process is a pure native forwarder.
    log(L"Bridge startup: system_loader=%s preexisting_core=%s",
        loader_path.c_str(), preexisting_core ? module_path(preexisting_core).c_str() : L"none");
    if (preexisting_core) {
        log(L"DECLINED existing Core/device ownership; no global SDK change. Native forwarding.");
        return;
    }
    const auto runtime_directory = module_path(nullptr).parent_path() / L"RE8Agility" / L"D3D12";
    const auto runtime_file = runtime_directory / L"D3D12Core.dll";
    if (!std::filesystem::is_regular_file(runtime_file)) {
        log(L"DECLINED missing private runtime %s. Native forwarding.", runtime_file.c_str()); return;
    }
    using GetInterface = HRESULT(WINAPI*)(REFCLSID, REFIID, void**);
    const auto get_interface = reinterpret_cast<GetInterface>(GetProcAddress(real_loader, "D3D12GetInterface"));
    if (!get_interface) { log(L"DECLINED missing SDK configuration API. Native forwarding."); return; }
    ComPtr<ID3D12SDKConfiguration1> configuration;
    auto status = get_interface(CLSID_D3D12SDKConfiguration, IID_PPV_ARGS(&configuration));
    if (FAILED(status)) { log(L"DECLINED SDKConfiguration1 HRESULT=0x%08lX", status); return; }
    const auto runtime_utf8 = utf8_path(runtime_directory.wstring());
    if (runtime_utf8.empty()) { log(L"DECLINED invalid runtime path encoding."); return; }
    ComPtr<ID3D12DeviceFactory> factory;
    status = configuration->CreateDeviceFactory(722, runtime_utf8.c_str(), IID_PPV_ARGS(&factory));
    if (FAILED(status)) { log(L"DECLINED CreateDeviceFactory(722) HRESULT=0x%08lX", status); return; }
    // This is the first forwarded D3D12 call and no Core existed before the
    // loader was loaded. Subsequent debug/experimental calls are forwarded after
    // activation. Do not import a different global runtime's factory state.
    if (native_device_call_seen.load(std::memory_order_acquire)) {
        log(L"DECLINED reentrant device creation; no global SDK change."); return;
    }
    status = factory->ApplyToGlobalState();
    if (FAILED(status)) { log(L"DECLINED ApplyToGlobalState HRESULT=0x%08lX", status); return; }
    retained_factory = factory.Detach();
    active = true;
    log(L"ACTIVATED SDK 722 before forwarded device creation; private_core=%s", runtime_file.c_str());
}
void ensure_initialized() noexcept {
    const auto saved_error = GetLastError();
    if (!initializing) {
        try { std::call_once(initialization, initialize_bridge); }
        catch (...) { log(L"DECLINED initialization exception. Native forwarding where available."); }
    }
    SetLastError(saved_error);
}
FARPROC resolve_name(const char* name) noexcept {
    const auto saved_error = GetLastError();
    ensure_initialized();
    const auto result = real_loader ? GetProcAddress(real_loader, name) : nullptr;
    SetLastError(saved_error); return result;
}
void log_created_device(HRESULT status, void* returned) noexcept {
    if (!is_target()) return;
    const bool first_attempt = !first_device_logged.exchange(true);
    const bool first_success = SUCCEEDED(status) && returned && !first_successful_device_logged.exchange(true);
    if (!first_attempt && !first_success) return;
    try {
        const auto core = GetModuleHandleW(L"D3D12Core.dll");
        const auto version = core ? reinterpret_cast<const UINT*>(GetProcAddress(core, "D3D12SDKVersion")) : nullptr;
        UINT device_sdk{};
        if (SUCCEEDED(status) && returned) {
            ComPtr<ID3D12DeviceConfiguration> device_configuration;
            if (SUCCEEDED(static_cast<IUnknown*>(returned)->QueryInterface(IID_PPV_ARGS(&device_configuration))))
                device_sdk = device_configuration->GetDesc().SDKVersion;
        }
        log(L"FIRST_DEVICE HRESULT=0x%08lX active=%u device_sdk=%u observed_core=%s observed_core_sdk=%u",
            status, active ? 1u : 0u, device_sdk, core ? module_path(core).c_str() : L"none", version ? *version : 0u);
        if (active && (FAILED(status) || (returned && device_sdk != 722)))
            log(L"ACTIVATION_NOT_VERIFIED: first device did not confirm SDK 722; no late reconfiguration attempted.");
    } catch (...) { log(L"FIRST_DEVICE diagnostic failure; no late SDK change attempted."); }
}
}

extern "C" void* AgilityResolveExport(unsigned ordinal) noexcept {
    const auto saved_error = GetLastError();
    ensure_initialized();
    const char* name = nullptr;
    for (const auto& entry : bridge_exports) if (entry.ordinal == ordinal) { name = entry.name; break; }
    // Named exports resolve by name on the user's OS; only true NONAME exports
    // resolve by ordinal. Do not assume undocumented ordinals never move.
    const auto function = real_loader ? GetProcAddress(real_loader, name ? name : MAKEINTRESOURCEA(ordinal)) : nullptr;
    SetLastError(saved_error);
    if (function) return reinterpret_cast<void*>(function);
    // Unknown signatures cannot safely fabricate a return value. A missing
    // system export is an explicit loader failure, never a false ABI shim.
    RaiseException(0xC0000139u, EXCEPTION_NONCONTINUABLE, 0, nullptr);
    TerminateProcess(GetCurrentProcess(), 0xC0000139u); return nullptr;
}
extern "C" HRESULT WINAPI BridgeD3D12CreateDevice(IUnknown* adapter, D3D_FEATURE_LEVEL level, REFIID iid, void** device) {
    using Function = HRESULT(WINAPI*)(IUnknown*, D3D_FEATURE_LEVEL, REFIID, void**);
    const auto function = reinterpret_cast<Function>(resolve_name("D3D12CreateDevice"));
    if (!function) return E_FAIL;
    native_device_call_seen.store(true, std::memory_order_release);
    const auto status = function(adapter, level, iid, device);
    const auto saved_error = GetLastError();
    log_created_device(status, SUCCEEDED(status) && device ? *device : nullptr);
    SetLastError(saved_error); return status;
}
extern "C" HRESULT WINAPI BridgeD3D12GetDebugInterface(REFIID iid, void** output) {
    using Function = HRESULT(WINAPI*)(REFIID, void**);
    const auto function = reinterpret_cast<Function>(resolve_name("D3D12GetDebugInterface"));
    return function ? function(iid, output) : E_FAIL;
}
extern "C" HRESULT WINAPI BridgeD3D12GetInterface(REFCLSID clsid, REFIID iid, void** output) {
    using Function = HRESULT(WINAPI*)(REFCLSID, REFIID, void**);
    const auto function = reinterpret_cast<Function>(resolve_name("D3D12GetInterface"));
    return function ? function(clsid, iid, output) : E_FAIL;
}
extern "C" HRESULT WINAPI BridgeD3D12EnableExperimentalFeatures(UINT count, const IID* features, void* config, UINT* sizes) {
    using Function = HRESULT(WINAPI*)(UINT, const IID*, void*, UINT*);
    const auto function = reinterpret_cast<Function>(resolve_name("D3D12EnableExperimentalFeatures"));
    return function ? function(count, features, config, sizes) : E_FAIL;
}
BOOL WINAPI DllMain(HMODULE module, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) own_module = module;
    // No loader calls, device/configuration work, thread spawning or static CRT
    // notification suppression occurs under the loader lock.
    return TRUE;
}
