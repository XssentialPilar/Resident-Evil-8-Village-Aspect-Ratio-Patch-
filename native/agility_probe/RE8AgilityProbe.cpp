#include <Windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <wrl/client.h>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <string_view>

// These exports belong to this diagnostic EXE. They do not opt RE8 into Agility.
extern "C" {
__declspec(dllexport) extern const UINT D3D12SDKVersion = 722;
__declspec(dllexport) extern const char* D3D12SDKPath = ".\\D3D12\\";
}

namespace {
using Microsoft::WRL::ComPtr;
using CreateDevice = HRESULT(WINAPI*)(IUnknown*, D3D_FEATURE_LEVEL, REFIID, void**);
void print_hr(const wchar_t* label, HRESULT value) {
    std::wcout << label << L"0x" << std::hex << std::uppercase << std::setw(8)
               << std::setfill(L'0') << static_cast<unsigned long>(value)
               << std::dec << std::nouppercase << L'\n';
}
std::filesystem::path module_path(HMODULE module) {
    std::wstring path(32768, L'\0');
    const auto count = GetModuleFileNameW(module, path.data(), static_cast<DWORD>(path.size()));
    if (count == 0 || count >= path.size()) return {};
    path.resize(count);
    return path;
}
void help() {
    std::wcout << L"RE8 Agility 722 compatibility probe (separate diagnostic process)\n"
        L"This does not launch, inject into, configure or update Resident Evil Village.\n"
        L"Run setup.ps1 with your original SDK package first, then run this EXE.\n"
        L"No arguments: create this process's own D3D12 device and report its runtime.\n"
        L"--help: show usage without creating a device.\n"
        L"--selftest: check this EXE's exports/path without loading D3D12 or creating a device.\n"
        L"Exit 0: device healthy and runtime SDK 722; 2: missing/setup/loader failure;\n"
        L"3: no compatible hardware device; 4: wrong runtime; 5: device removed.\n"
        L"Success establishes only this probe's compatibility, not RE8 integration.\n";
}
int self_test() {
    const auto exe = GetModuleHandleW(nullptr);
    const auto exported_version = reinterpret_cast<const UINT*>(GetProcAddress(exe, "D3D12SDKVersion"));
    const auto exported_path = reinterpret_cast<const char* const*>(GetProcAddress(exe, "D3D12SDKPath"));
    const bool okay = exported_version != nullptr && *exported_version == 722 &&
        exported_path != nullptr && *exported_path != nullptr &&
        std::string_view{*exported_path} == ".\\D3D12\\";
    std::wcout << (okay ? L"PASS" : L"FAIL")
        << L": own EXE exports SDK 722 and relative D3D12 path. No device created.\n";
    return okay ? 0 : 2;
}
int probe() {
    const auto root = module_path(nullptr).parent_path();
    const auto expected_core = root / L"D3D12" / L"D3D12Core.dll";
    if (!std::filesystem::is_regular_file(expected_core)) {
        std::wcerr << L"Missing " << expected_core << L". Run the kit's setup.ps1 first.\n";
        return 2;
    }
    std::wcout << L"Independent compatibility test; RE8 is not accessed.\nRequested SDK: 722\n";
    // Loading the OS loader only here keeps help/selftest free of D3D12 selection.
    const auto loader = LoadLibraryExW(L"d3d12.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (loader == nullptr) {
        std::wcerr << L"Cannot load the system D3D12 loader. Win32 error " << GetLastError() << L'\n';
        return 2;
    }
    const auto create_device = reinterpret_cast<CreateDevice>(GetProcAddress(loader, "D3D12CreateDevice"));
    if (create_device == nullptr) {
        std::wcerr << L"System loader has no D3D12CreateDevice export.\n";
        return 2;
    }
    ComPtr<IDXGIFactory4> factory;
    auto status = CreateDXGIFactory1(IID_PPV_ARGS(&factory));
    if (FAILED(status)) { print_hr(L"CreateDXGIFactory1: ", status); return 2; }
    ComPtr<ID3D12Device> device;
    for (UINT index = 0;; ++index) {
        ComPtr<IDXGIAdapter1> adapter;
        status = factory->EnumAdapters1(index, &adapter);
        if (status == DXGI_ERROR_NOT_FOUND) break;
        if (FAILED(status)) { print_hr(L"EnumAdapters1: ", status); return 3; }
        DXGI_ADAPTER_DESC1 description{};
        if (FAILED(adapter->GetDesc1(&description)) || (description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)) continue;
        std::wcout << L"Trying GPU: " << description.Description << L'\n';
        status = create_device(adapter.Get(), D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&device));
        print_hr(L"D3D12CreateDevice: ", status);
        if (SUCCEEDED(status)) {
            std::wcout << L"Selected GPU: " << description.Description << L" (vendor 0x"
                       << std::hex << description.VendorId << L", device 0x" << description.DeviceId
                       << std::dec << L")\n";
            break;
        }
    }
    const auto core = GetModuleHandleW(L"D3D12Core.dll");
    const auto actual_version = core == nullptr ? nullptr :
        reinterpret_cast<const UINT*>(GetProcAddress(core, "D3D12SDKVersion"));
    std::wcout << L"Loaded D3D12Core: " << (core ? module_path(core).wstring() : L"not loaded") << L'\n';
    if (actual_version) std::wcout << L"Loaded SDK version: " << *actual_version << L'\n';
    else std::wcout << L"Loaded SDK version: unavailable\n";
    if (!device) { std::wcerr << L"FAIL: no hardware D3D12 device was created.\n"; return 3; }
    const auto removed = device->GetDeviceRemovedReason();
    print_hr(L"Device removed reason: ", removed);
    if (FAILED(removed)) return 5;
    if (actual_version == nullptr || *actual_version != 722) {
        std::wcerr << L"FAIL: the requested runtime 722 was not selected.\n";
        return 4;
    }
    std::wcout << L"PASS: this probe created a healthy device with SDK 722.\n"
        L"This does not verify or enable the runtime in RE8.\n";
    return 0;
}
}

int wmain(int argc, wchar_t** argv) {
    if (argc == 2 && (std::wstring_view{argv[1]} == L"--help" || std::wstring_view{argv[1]} == L"-h")) {
        help(); return 0;
    }
    if (argc == 2 && (std::wstring_view{argv[1]} == L"--selftest" || std::wstring_view{argv[1]} == L"--self-test"))
        return self_test();
    if (argc != 1) { help(); return 2; }
    try { return probe(); }
    catch (const std::exception& error) { std::cerr << "Probe error: " << error.what() << '\n'; return 2; }
}
