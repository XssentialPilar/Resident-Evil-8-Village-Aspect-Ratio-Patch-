#include <Windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <wrl/client.h>
#include <filesystem>
#include <iostream>
#include <string_view>
#include "system_exports.hpp"

namespace {
using Microsoft::WRL::ComPtr;
using CreateDevice = HRESULT(WINAPI*)(IUnknown*, D3D_FEATURE_LEVEL, REFIID, void**);
HRESULT create_hardware(CreateDevice create, ComPtr<ID3D12Device>& device) {
    ComPtr<IDXGIFactory4> factory;
    auto result = CreateDXGIFactory1(IID_PPV_ARGS(&factory));
    if (FAILED(result)) return result;
    for (UINT index = 0;; ++index) {
        ComPtr<IDXGIAdapter1> adapter;
        const auto enumeration = factory->EnumAdapters1(index, &adapter);
        if (enumeration == DXGI_ERROR_NOT_FOUND) break;
        if (FAILED(enumeration)) return enumeration;
        DXGI_ADAPTER_DESC1 description{};
        if (FAILED(adapter->GetDesc1(&description)) || (description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)) continue;
        result = create(adapter.Get(), D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&device));
        if (SUCCEEDED(result)) { std::wcout << L"GPU: " << description.Description << L'\n'; break; }
    }
    return device ? S_OK : FAILED(result) ? result : DXGI_ERROR_NOT_FOUND;
}
UINT device_sdk(ID3D12Device* device) {
    ComPtr<ID3D12DeviceConfiguration> configuration;
    return device && SUCCEEDED(device->QueryInterface(IID_PPV_ARGS(&configuration)))
        ? configuration->GetDesc().SDKVersion : 0u;
}
}

int wmain(int argc, wchar_t** argv) {
    const bool selftest = argc == 2 && std::wstring_view{argv[1]} == L"--selftest";
    const bool exercise = argc == 2 && std::wstring_view{argv[1]} == L"--exercise";
    const bool preloaded = argc == 2 && std::wstring_view{argv[1]} == L"--exercise-preloaded";
    const bool native = argc == 2 && std::wstring_view{argv[1]} == L"--exercise-native";
    if (!selftest && !exercise && !preloaded && !native) {
        std::wcout << L"Isolated bridge test host, never the actual game.\n"
            L"--selftest verifies all proxy export names/ordinals without device creation.\n"
            L"--exercise creates this host's device; expected SDK 722 only when named re8.exe\n"
            L"and private runtime is staged at RE8Agility/D3D12/D3D12Core.dll.\n"
            L"--exercise-preloaded retains a native device before proxy loading; verifies no removal/change.\n"
            L"--exercise-native checks native fallback without requiring SDK 722.\n";
        return argc == 1 ? 0 : 2;
    }
    ComPtr<ID3D12Device> prior_device;
    UINT prior_sdk{};
    if (preloaded) {
        wchar_t system_path[32768]{}; GetSystemDirectoryW(system_path, static_cast<UINT>(std::size(system_path)));
        const auto loader = LoadLibraryExW((std::filesystem::path{system_path} / L"d3d12.dll").c_str(), nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!loader) return 10;
        const auto create = reinterpret_cast<CreateDevice>(GetProcAddress(loader, "D3D12CreateDevice"));
        if (!create || FAILED(create_hardware(create, prior_device))) return 11;
        prior_sdk = device_sdk(prior_device.Get());
        std::wcout << L"Retained native device SDK before proxy: " << prior_sdk << L'\n';
    }
    wchar_t location[32768]{}; GetModuleFileNameW(nullptr, location, static_cast<DWORD>(std::size(location)));
    const auto path = std::filesystem::path{location}.parent_path() / L"d3d12.dll";
    const auto proxy = LoadLibraryExW(path.c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!proxy) { std::wcerr << L"Cannot load staged proxy: " << GetLastError() << L'\n'; return 2; }
    for (const auto& entry : bridge_exports) {
        if (!GetProcAddress(proxy, MAKEINTRESOURCEA(entry.ordinal)) ||
            (entry.name && !GetProcAddress(proxy, entry.name))) {
            std::wcerr << L"Missing export ordinal " << entry.ordinal << L'\n'; return 3;
        }
    }
    std::wcout << L"PASS: all " << std::size(bridge_exports) << L" system exports/ordinals present.\n";
    using GetStatus = bool (*)(UINT*, UINT);
    const auto get_status = reinterpret_cast<GetStatus>(GetProcAddress(proxy, "RE8Agility_GetStatus"));
    UINT fields[5]{};
    if (!get_status || get_status(nullptr, 5) || get_status(fields, 4) || !get_status(fields, 5) || fields[0] != 1) return 14;
    std::wcout << L"PASS: read-only status ABI and invalid-size rejection.\n";
    if (selftest) return 0;
    using GetInterface = HRESULT(WINAPI*)(REFCLSID, REFIID, void**);
    const auto get_interface = reinterpret_cast<GetInterface>(GetProcAddress(proxy, "D3D12GetInterface"));
    ComPtr<ID3D12SDKConfiguration1> sdk_configuration;
    auto result = get_interface(CLSID_D3D12SDKConfiguration, IID_PPV_ARGS(&sdk_configuration));
    if (FAILED(result)) { std::wcerr << L"GetInterface forwarding failed.\n"; return 8; }
    using Serialize = HRESULT(WINAPI*)(const D3D12_ROOT_SIGNATURE_DESC*, D3D_ROOT_SIGNATURE_VERSION, ID3DBlob**, ID3DBlob**);
    const auto serialize = reinterpret_cast<Serialize>(GetProcAddress(proxy, "D3D12SerializeRootSignature"));
    D3D12_ROOT_SIGNATURE_DESC signature_description{};
    ComPtr<ID3DBlob> blob, error;
    result = serialize(&signature_description, D3D_ROOT_SIGNATURE_VERSION_1, &blob, &error);
    if (FAILED(result) || !blob) { std::wcerr << L"Root-signature ASM forwarding failed.\n"; return 9; }
    std::wcout << L"PASS: GetInterface and root-signature serialization forwarding.\n";
    const auto create = reinterpret_cast<CreateDevice>(GetProcAddress(proxy, "D3D12CreateDevice"));
    ComPtr<ID3D12Device> device;
    result = create_hardware(create, device);
    std::wcout << L"Device HRESULT: 0x" << std::hex << static_cast<unsigned long>(result) << std::dec << L'\n';
    if (!device) return 5;
    ComPtr<ID3D12DeviceConfiguration> configuration;
    if (FAILED(device.As(&configuration))) { std::wcerr << L"No device configuration interface.\n"; return 6; }
    const auto sdk = configuration->GetDesc().SDKVersion;
    std::wcout << L"Actual device SDK: " << sdk << L'\n';
    const auto removed = device->GetDeviceRemovedReason();
    std::wcout << L"Device removed reason: 0x" << std::hex << static_cast<unsigned long>(removed) << std::dec << L'\n';
    if (preloaded) {
        const auto prior_removed = prior_device->GetDeviceRemovedReason();
        std::wcout << L"Prior device removed reason: 0x" << std::hex << static_cast<unsigned long>(prior_removed) << std::dec << L'\n';
        return sdk == prior_sdk && SUCCEEDED(removed) && SUCCEEDED(prior_removed) ? 0 : 12;
    }
    if (native) return SUCCEEDED(removed) ? 0 : 13;
    return sdk == 722 && SUCCEEDED(removed) ? 0 : 7;
}
