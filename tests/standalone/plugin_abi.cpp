#include <Windows.h>
#include <reframework/API.h>
#include <cassert>
#include <cstring>
#include <iostream>
int main(int argc, char** argv) {
    assert(argc == 2);
    const auto library = LoadLibraryA(argv[1]);
    assert(library != nullptr);
    const auto required = reinterpret_cast<REFPluginRequiredVersionFn>(GetProcAddress(library, "reframework_plugin_required_version"));
    const auto initialize = reinterpret_cast<REFPluginInitializeFn>(GetProcAddress(library, "reframework_plugin_initialize"));
    assert(required != nullptr && initialize != nullptr);
    required(nullptr); // Robustness of the exported query, without SDK calls.
    REFrameworkPluginVersion version{};
    required(&version);
    assert(version.major == 1 && version.minor == 15 && version.patch == 0);
    assert(version.game_name != nullptr && std::strcmp(version.game_name, "RE8") == 0);
    assert(!initialize(nullptr));
    REFrameworkPluginInitializeParam parameter{};
    assert(!initialize(&parameter));
    parameter.version = &version;
    assert(!initialize(&parameter));
    // Non-null sentinel pointers are deliberately unreachable after the version
    // gate. This verifies that the 1.10 host's shorter function table is not read.
    parameter.functions = reinterpret_cast<const REFrameworkPluginFunctions*>(1);
    parameter.sdk = reinterpret_cast<const REFrameworkSDKData*>(1);
    version.minor = 10;
    assert(!initialize(&parameter));
    version.minor = 15;
    version.game_name = "RE4";
    assert(!initialize(&parameter));
    FreeLibrary(library);
    std::cout << "PASS: standalone DLL exports, API 1.15 requirement, old API and wrong game rejected before table access\n";
}
