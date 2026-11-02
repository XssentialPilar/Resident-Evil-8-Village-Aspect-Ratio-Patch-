#include <Windows.h>
#include <reframework/API.h>
#include <cstdint>
#include <cstdio>
#include <cstdarg>
#include <filesystem>
#include <string>

struct BridgeStats {
    uint32_t version{1}, enabled{}, installed_slots{};
    uint64_t reads{}, bytes{}, fallbacks{}, timeouts{};
    uint64_t pending_jobs{}, private_buffers{};
    uint64_t verified_reads{}, verification_errors{}, verification_mismatches{};
    uint64_t native_compat_reads{}, native_compat_errors{};
};

#ifndef RE8_DS_HARNESS
#include "RE8DirectStorageCore.hpp"

namespace {
const REFrameworkPluginFunctions* host{};
std::atomic<bool> initialized{};
uint64_t last_log{}, last_reads{}, last_fallbacks{};
bool first_logged{};
size_t samples_logged{};
void on_present() noexcept {
    try {
        if (re8_ds::runtime) re8_ds::runtime->collect();
        while (samples_logged < re8_ds::io_samples.size()) {
            const auto& entry = re8_ds::io_samples[samples_logged];
            if (!entry.ready.load(std::memory_order_acquire)) break;
            const auto& sample = entry.data;
            host->log_info("[RE8DirectStorage.IO] sample=%u bytes=%lu overlap_nonnull=%d count_null=%d buffer_null=%d pak_under_root=%d mode_ok=%d mode=0x%08lx access_ok=%d access=0x%08lx ov_readable=%d offset=%lu offset_high=%lu event_lowbit=%d event_nonnull=%d internal=0x%llx",
                static_cast<unsigned>(samples_logged + 1), sample.length, sample.overlap, sample.count_missing, sample.buffer_missing,
                sample.pak_under_root, sample.mode_valid, sample.mode, sample.access_valid, sample.access,
                sample.overlap_readable, sample.offset, sample.offset_high, sample.event_lowbit, sample.event_nonnull, static_cast<unsigned long long>(sample.internal));
            ++samples_logged;
        }
        const auto successful = re8_ds::reads.load(), fallback_count = re8_ds::fallbacks.load();
        const auto now = GetTickCount64();
        if (successful && !first_logged) {
            host->log_info("[RE8DirectStorage] FIRST REAL PAK READ: DirectStorage bulk bytes + 1-byte native kernel bookkeeping; game retains original decompression");
            first_logged = true;
        }
        if (now - last_log < 5000 || (successful == last_reads && fallback_count == last_fallbacks)) return;
        host->log_info("[RE8DirectStorage] active=%d pak_reads=%llu pak_bytes=%llu native_fallbacks=%llu timeout_disable=%llu fallback_size=%llu overlapped=%llu metadata=%llu path=%llu access=%llu mode=%llu identity=%llu position=%llu saturated=%llu runtime=%llu allocation=%llu copy=%llu overlap_nonnull=%llu count_null=%llu buffer_null=%llu verification_reads=%llu verification_errors=%llu verification_mismatch=%llu native_compat_reads=%llu native_compat_errors=%llu",
            re8_ds::runtime && re8_ds::runtime->enabled.load(), successful, re8_ds::bytes.load(), fallback_count,
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::timeout)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::size)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::overlapped)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::metadata)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::path)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::access)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::mode)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::identity)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::position)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::queue_full)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::runtime_error)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::allocation)].load(),
            re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::copy)].load(),
            re8_ds::overlap_nonnull.load(), re8_ds::count_null.load(), re8_ds::buffer_null.load(),
            re8_ds::verified_reads.load(), re8_ds::verification_errors.load(), re8_ds::verification_mismatches.load(),
            re8_ds::native_compat_reads.load(), re8_ds::native_compat_errors.load());
        last_log = now; last_reads = successful; last_fallbacks = fallback_count;
    } catch (...) { /* Telemetry must not affect the game frame. */ }
}
}

extern "C" __declspec(dllexport) void reframework_plugin_required_version(REFrameworkPluginVersion* version) {
    if (version) *version = {1, 15, 0, "RE8"};
}
extern "C" __declspec(dllexport) bool RE8DirectStorage_GetStats(BridgeStats* output, uint32_t size) {
    if (!output || size != sizeof(BridgeStats)) return false;
    *output = {1, re8_ds::runtime && re8_ds::runtime->enabled.load() && re8_ds::installed.load(),
        static_cast<uint32_t>(re8_ds::slots.size()), re8_ds::reads.load(), re8_ds::bytes.load(),
        re8_ds::fallbacks.load(), re8_ds::reasons[static_cast<size_t>(re8_ds::Fallback::timeout)].load(),
        re8_ds::runtime ? re8_ds::runtime->pending_count() : 0,
        re8_ds::runtime ? re8_ds::runtime->allocated_count() : 0,
        re8_ds::verified_reads.load(), re8_ds::verification_errors.load(), re8_ds::verification_mismatches.load(),
        re8_ds::native_compat_reads.load(), re8_ds::native_compat_errors.load()};
    return true;
}
#ifdef RE8_DS_TESTING
extern "C" __declspec(dllexport) void RE8DirectStorage_TestMode(int mode) { re8_ds::test_mode.store(mode); }
#endif
extern "C" __declspec(dllexport) bool reframework_plugin_initialize(const REFrameworkPluginInitializeParam* parameter) {
    if (!parameter || !parameter->version || !parameter->functions || parameter->version->major != 1 || parameter->version->minor < 15 ||
        !parameter->version->game_name || std::string{parameter->version->game_name} != "RE8" ||
        !parameter->functions->log_info || !parameter->functions->log_warn || !parameter->functions->on_present) return false;
    if (initialized.exchange(true)) return true;
    host = parameter->functions;
    // IAT callbacks/runtime workers must remain valid even if the host asks to
    // unload plugins. The singleton and quarantined buffers live until process exit.
    HMODULE pinned{};
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
        reinterpret_cast<LPCWSTR>(&on_present), &pinned)) return false;
    try {
        const auto executable = re8_ds::executable_path();
        if (_wcsicmp(executable.filename().c_str(), L"re8.exe") != 0) {
            host->log_warn("[RE8DirectStorage] Inactive: executable identity is not re8.exe"); return true;
        }
        const auto root = executable.parent_path();
        const auto directory = CreateFileW(root.c_str(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            nullptr, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, nullptr);
        if (directory == INVALID_HANDLE_VALUE) return true;
        re8_ds::root_prefix = re8_ds::lowercase(re8_ds::final_path(directory)) + L"\\";
        CloseHandle(directory);
        const auto kernel = GetModuleHandleW(L"kernel32.dll");
        re8_ds::native_read = reinterpret_cast<decltype(&ReadFile)>(GetProcAddress(kernel, "ReadFile"));
        re8_ds::native_seek = reinterpret_cast<decltype(&SetFilePointer)>(GetProcAddress(kernel, "SetFilePointer"));
        re8_ds::native_seek_ex = reinterpret_cast<decltype(&SetFilePointerEx)>(GetProcAddress(kernel, "SetFilePointerEx"));
        re8_ds::native_close = reinterpret_cast<decltype(&CloseHandle)>(GetProcAddress(kernel, "CloseHandle"));
        re8_ds::query_information = reinterpret_cast<re8_ds::NativeQuery>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtQueryInformationFile"));
        if (re8_ds::root_prefix.size() < 5 || !re8_ds::query_information || !re8_ds::native_read || !re8_ds::native_seek || !re8_ds::native_seek_ex || !re8_ds::native_close) return true;
        re8_ds::runtime = new re8_ds::Runtime;
        if (!re8_ds::runtime->initialize(root)) {
            host->log_warn("[RE8DirectStorage] Inactive: private preview runtime missing, incompatible, or another DirectStorage module is already loaded"); return true;
        }
        if (!re8_ds::install_iat()) {
            re8_ds::runtime->enabled.store(false);
            host->log_warn("[RE8DirectStorage] Inactive: required RE8 import slots missing/changed; no partial bridge accepted"); return true;
        }
        if (!host->on_present(&on_present)) {
            re8_ds::runtime->enabled.store(false);
            host->log_warn("[RE8DirectStorage] Disabled: host cleanup/telemetry callback unavailable; hooks use native fallback"); return true;
        }
        host->log_info("[RE8DirectStorage] Experimental CPU PAK bridge; IAT slots=%u; readonly nonalertable synchronous .pak; null-event explicit OVERLAPPED; 64KiB..8MiB; timeout=250ms; first64 native comparisons; bulk DS + 1-byte native bookkeeping; no GPU decompression",
            static_cast<unsigned>(re8_ds::slots.size()));
        return true;
    } catch (...) {
        if (re8_ds::runtime) re8_ds::runtime->enabled.store(false);
        host->log_warn("[RE8DirectStorage] Initialization failed; native file I/O retained");
        return true;
    }
}

#else
#include <algorithm>
#include <array>
#include <atomic>
#include <fstream>
#include <iostream>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <vector>
#include <winioctl.h>

namespace {
REFOnPresentCb present{};
void logger(const char* format, ...) {
    va_list arguments; va_start(arguments, format); std::vprintf(format, arguments); va_end(arguments); std::puts("");
}
void require(bool result, const char* message) { if (!result) throw std::runtime_error(message); }
std::vector<uint8_t> content(size_t size) {
    std::vector<uint8_t> result(size); uint32_t seed = 0x250d570;
    for (auto& value : result) { seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5; value = static_cast<uint8_t>(seed >> 24); }
    return result;
}
struct File {
    HANDLE handle{INVALID_HANDLE_VALUE};
    ~File() { if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle); }
};
void compare(HANDLE file, const std::vector<uint8_t>& expected, size_t offset, DWORD requested) {
    std::vector<uint8_t> actual(requested, 0xcc); DWORD count = 0xeeeeeeee;
    require(ReadFile(file, actual.data(), requested, &count, nullptr) != FALSE, "ReadFile failed");
    const auto amount = static_cast<DWORD>(std::min<size_t>(requested, expected.size() - offset));
    require(count == amount && std::equal(actual.begin(), actual.begin() + amount, expected.begin() + offset), "Read bytes/count differ");
    LARGE_INTEGER zero{}, position{};
    require(SetFilePointerEx(file, zero, &position, FILE_CURRENT) && position.QuadPart == static_cast<int64_t>(offset + amount), "File pointer differs");
}
void** import_slot(const char* wanted, char** name_out = nullptr) {
    auto image = reinterpret_cast<uint8_t*>(GetModuleHandleW(nullptr));
    auto dos = reinterpret_cast<IMAGE_DOS_HEADER*>(image);
    auto nt = reinterpret_cast<IMAGE_NT_HEADERS64*>(image + dos->e_lfanew);
    auto descriptor = reinterpret_cast<IMAGE_IMPORT_DESCRIPTOR*>(image + nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);
    for (; descriptor->Name; ++descriptor) {
        auto names = reinterpret_cast<IMAGE_THUNK_DATA64*>(image + descriptor->OriginalFirstThunk);
        auto addresses = reinterpret_cast<IMAGE_THUNK_DATA64*>(image + descriptor->FirstThunk);
        for (; names->u1.AddressOfData; ++names, ++addresses) if (!IMAGE_SNAP_BY_ORDINAL64(names->u1.Ordinal)) {
            const auto name = reinterpret_cast<IMAGE_IMPORT_BY_NAME*>(image + names->u1.AddressOfData)->Name;
            if (std::string{reinterpret_cast<const char*>(name)} == wanted) {
                if (name_out) *name_out = reinterpret_cast<char*>(name);
                return reinterpret_cast<void**>(&addresses->u1.Function);
            }
        }
    }
    return nullptr;
}
BOOL WINAPI foreign_read(HANDLE, LPVOID, DWORD, LPDWORD, LPOVERLAPPED) { SetLastError(ERROR_ACCESS_DENIED); return FALSE; }
}
int wmain(int argc, wchar_t** argv) {
    try {
        require(argc == 2 || argc == 3, "Supply plugin DLL; optional --timeout/--conflict/--rollback/--mixed/--no-ex; artifacts fixture only");
        const std::wstring mode = argc == 3 ? argv[2] : L"";
        const auto root = std::filesystem::absolute(argv[0]).parent_path();
        const auto pak = root / L"bridge-fixture.pak", ordinary = root / L"bridge-fixture.txt", writable_pak = root / L"bridge-writable.pak", reused_pak = root / L"bridge-reused.pak";
        const auto expected = content(2 * 1024 * 1024);
        { std::ofstream output{pak, std::ios::binary}; output.write(reinterpret_cast<const char*>(expected.data()), expected.size()); require(output.good(), "Fixture write failed"); }
        { std::ofstream output{ordinary, std::ios::binary}; output.write(reinterpret_cast<const char*>(expected.data()), expected.size()); }
        { std::ofstream output{writable_pak, std::ios::binary}; output.write(reinterpret_cast<const char*>(expected.data()), expected.size()); }
        auto other_content = expected; for (auto& byte : other_content) byte ^= 0x5a;
        { std::ofstream output{reused_pak, std::ios::binary}; output.write(reinterpret_cast<const char*>(other_content.data()), other_content.size()); }
        if (mode == L"--native-ov") {
            const auto read = reinterpret_cast<decltype(&ReadFile)>(GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "ReadFile"));
            File source{CreateFileW(pak.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
            require(source.handle != INVALID_HANDLE_VALUE, "Native OVERLAPPED fixture open failed");
            for (unsigned scenario : {3u, 5u, 3u, 0u, 1u, 2u, 3u, 4u}) {
                LARGE_INTEGER initial{}; initial.QuadPart = 32768;
                require(SetFilePointerEx(source.handle, initial, nullptr, FILE_BEGIN) != FALSE, "Native probe seek failed");
                OVERLAPPED operation{};
                operation.Offset = scenario == 5 ? 65535 : scenario == 0 ? 65536 : scenario == 1 ? 131072 : scenario == 2 ? static_cast<DWORD>(expected.size() - 32768) : scenario == 3 ? static_cast<DWORD>(expected.size()) : 0xffffffff;
                operation.OffsetHigh = scenario == 4 ? 0xffffffff : 0;
                operation.Internal = scenario % 2 ? 0x103 : 0xdeadbeef;
                operation.InternalHigh = 0xabcdef;
                std::vector<uint8_t> buffer(scenario == 5 ? 1 : 65536); DWORD count = 0xeeeeeeee;
                SetLastError(0x250123);
                const auto result = read(source.handle, buffer.data(), static_cast<DWORD>(buffer.size()), &count, &operation);
                const auto error = GetLastError(); LARGE_INTEGER zero{}, position{};
                SetFilePointerEx(source.handle, zero, &position, FILE_CURRENT);
                std::printf("NATIVE_SYNC_OV case=%u result=%d count=%lu error=0x%lx internal=0x%llx high=%llu pointer=%lld offset=%lu offset_hi=%lu\n", scenario, result, count, error, static_cast<unsigned long long>(operation.Internal), static_cast<unsigned long long>(operation.InternalHigh), position.QuadPart, operation.Offset, operation.OffsetHigh);
            }
            return 0;
        }
        const auto module = LoadLibraryExW(std::filesystem::absolute(argv[1]).c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
        require(module != nullptr, "Plugin load failed");
        const auto initialize = reinterpret_cast<REFPluginInitializeFn>(GetProcAddress(module, "reframework_plugin_initialize"));
        const auto get_stats = reinterpret_cast<bool(*)(BridgeStats*, uint32_t)>(GetProcAddress(module, "RE8DirectStorage_GetStats"));
        const auto test_mode = reinterpret_cast<void(*)(int)>(GetProcAddress(module, "RE8DirectStorage_TestMode"));
        require(initialize && get_stats, "Plugin exports missing");
        if (mode == L"--timeout" || mode == L"--rollback" || mode == L"--mixed" || mode == L"--mismatch") { require(test_mode != nullptr, "Fault tests require separate test-only DLL"); test_mode(mode == L"--timeout" ? 1 : mode == L"--rollback" ? 2 : mode == L"--mixed" ? 3 : 4); }
        void** foreign_slot{};
        if (mode == L"--conflict") {
            foreign_slot = import_slot("ReadFile"); require(foreign_slot != nullptr, "Harness ReadFile import missing");
            DWORD protection{}, ignored{};
            require(VirtualProtect(foreign_slot, sizeof(void*), PAGE_READWRITE, &protection) != FALSE, "Cannot prepare foreign-hook fixture");
            *foreign_slot = reinterpret_cast<void*>(&foreign_read);
            VirtualProtect(foreign_slot, sizeof(void*), protection, &ignored);
        }
        if (mode == L"--no-ex") {
            char* name{}; require(import_slot("SetFilePointerEx", &name) != nullptr && name, "SetFilePointerEx fixture import missing");
            DWORD protection{}, ignored{}; require(VirtualProtect(name, 1, PAGE_READWRITE, &protection) != FALSE, "Cannot prepare missing optional import");
            *name = '!'; VirtualProtect(name, 1, protection, &ignored);
        }
        REFrameworkPluginVersion version{1, 15, 0, "RE8"};
        REFrameworkPluginFunctions functions{};
        functions.log_info = logger; functions.log_warn = logger; functions.log_error = logger;
        functions.on_present = [](REFOnPresentCb callback) { present = callback; return true; };
        REFrameworkPluginInitializeParam parameter{};
        parameter.version = &version; parameter.functions = &functions;
        require(initialize(&parameter), "Plugin initialize failed");
        BridgeStats initial{}; require(get_stats(&initial, sizeof(initial)), "Cannot inspect bridge stats");
        if (mode == L"--conflict" || mode == L"--rollback") {
            require(!initial.enabled && initial.installed_slots == 0, "Conflicted transaction was accepted");
            if (foreign_slot) require(*foreign_slot == reinterpret_cast<void*>(&foreign_read), "Existing hook was overwritten");
            else {
                File native{CreateFileW(pak.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
                compare(native.handle, expected, 0, 64 * 1024);
            }
            std::puts("PASS: import conflict/partial-install failure rejected; native slots rolled back and foreign hook preserved.");
            return 0;
        }
        require(initial.enabled && initial.installed_slots >= (mode == L"--no-ex" ? 3u : 4u), "Bridge did not activate");
        if (mode == L"--sync-ov" || mode == L"--mismatch") {
            const auto raw_read = reinterpret_cast<decltype(&ReadFile)>(GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "ReadFile"));
            struct Outcome { BOOL result{}, completed{}; DWORD count{}, error{}, completed_count{}, completed_error{}; OVERLAPPED operation{}; LARGE_INTEGER cursor{}; std::vector<uint8_t> data; DWORD event_state{}; };
            const auto perform = [&](HANDLE file, bool native, uint64_t offset, DWORD requested, ULONG_PTR initial_status, bool event, bool lowbit) {
                Outcome result{}; result.data.resize(requested, 0xcc);
                result.operation.Offset = static_cast<DWORD>(offset); result.operation.OffsetHigh = static_cast<DWORD>(offset >> 32);
                result.operation.Internal = initial_status; result.operation.InternalHigh = 0xabcdef;
                File signal;
                if (event) { signal.handle = CreateEventW(nullptr, TRUE, TRUE, nullptr); result.operation.hEvent = reinterpret_cast<HANDLE>(reinterpret_cast<uintptr_t>(signal.handle) | (lowbit ? 1 : 0)); }
                LARGE_INTEGER initial_cursor{}; initial_cursor.QuadPart = 32768;
                require(SetFilePointerEx(file, initial_cursor, nullptr, FILE_BEGIN) != FALSE, "OV comparison initial seek failed");
                result.count = 0xeeeeeeee; SetLastError(0x250123);
                result.result = native ? raw_read(file, result.data.data(), requested, &result.count, &result.operation) : ReadFile(file, result.data.data(), requested, &result.count, &result.operation);
                result.error = GetLastError();
                LARGE_INTEGER zero{}; require(SetFilePointerEx(file, zero, &result.cursor, FILE_CURRENT) != FALSE, "OV comparison cursor query failed");
                SetLastError(0x250456);
                result.completed_count = 0x77777777;
                result.completed = GetOverlappedResult(file, &result.operation, &result.completed_count, FALSE);
                result.completed_error = GetLastError();
                if (event) result.event_state = WaitForSingleObject(signal.handle, 0);
                result.operation.hEvent = nullptr; // Only event signal state, not HANDLE addresses, is compared.
                return result;
            };
            const auto same = [](const Outcome& a, const Outcome& b) {
                return a.result == b.result && a.count == b.count && a.error == b.error && a.operation.Internal == b.operation.Internal &&
                    a.operation.InternalHigh == b.operation.InternalHigh && a.operation.Offset == b.operation.Offset && a.operation.OffsetHigh == b.operation.OffsetHigh &&
                    a.cursor.QuadPart == b.cursor.QuadPart && a.data == b.data && a.completed == b.completed && a.completed_count == b.completed_count &&
                    a.completed_error == b.completed_error && a.event_state == b.event_state;
            };
            File native_file{CreateFileW(pak.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
            File game_file{CreateFileW(pak.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
            require(native_file.handle != INVALID_HANDLE_VALUE && game_file.handle != INVALID_HANDLE_VALUE, "OV comparison files unavailable");
            if (mode == L"--mismatch") {
                const auto control = perform(native_file.handle, true, 65536, 65536, 0x103, false, false);
                const auto actual = perform(game_file.handle, false, 65536, 65536, 0x103, false, false);
                BridgeStats stats{};
                require(same(control, actual) && get_stats(&stats, sizeof(stats)) && !stats.enabled && stats.reads == 0 && stats.verified_reads == 0 && stats.verification_mismatches == 1, "Mismatched DS data reached the game or native fallback state differs");
                std::puts("PASS: injected private DS mismatch disables bridge; game buffer/cursor/OVERLAPPED match unmodified native fallback.");
                return 0;
            }
            struct Case { uint64_t offset; DWORD length; ULONG_PTR status; bool event{}, lowbit{}; };
            const std::array<Case, 10> cases{{
                {65536,65536,0},{131072,262144,0x103},{196608,65536,0xdeadbeef},
                {expected.size()-32768,65536,0x103},{expected.size(),65536,0},{expected.size()+65536,65536,0xdeadbeef},
                {UINT64_MAX,65536,0x103},{0,65536,0,true,false},{65536,65536,0,true,true},{0,16,0x103}
            }};
            for (const auto& item : cases) {
                const auto control = perform(native_file.handle, true, item.offset, item.length, item.status, item.event, item.lowbit);
                const auto actual = perform(game_file.handle, false, item.offset, item.length, item.status, item.event, item.lowbit);
                if (!same(control, actual)) {
                    std::printf("OV_DIFFERENCE offset=%llu event=%d lowbit=%d native[result=%d count=%lu err=%lx internal=%llx high=%llu cursor=%lld complete=%d cc=%lu ce=%lx es=%lu] bridge[result=%d count=%lu err=%lx internal=%llx high=%llu cursor=%lld complete=%d cc=%lu ce=%lx es=%lu] bytes_equal=%d\n",
                        item.offset, item.event, item.lowbit, control.result, control.count, control.error, static_cast<unsigned long long>(control.operation.Internal), static_cast<unsigned long long>(control.operation.InternalHigh), control.cursor.QuadPart, control.completed, control.completed_count, control.completed_error, control.event_state,
                        actual.result, actual.count, actual.error, static_cast<unsigned long long>(actual.operation.Internal), static_cast<unsigned long long>(actual.operation.InternalHigh), actual.cursor.QuadPart, actual.completed, actual.completed_count, actual.completed_error, actual.event_state, control.data == actual.data);
                }
                require(same(control, actual), "Synchronous OVERLAPPED differs from native result/count/LastError/status/cursor/data/event/GetOverlappedResult");
            }
            const auto high_pak = root / L"bridge-high-offset-fixture.pak";
            const uint64_t high_offset = (UINT64_C(1) << 32) + 65536;
            {
                File output{CreateFileW(high_pak.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr)};
                require(output.handle != INVALID_HANDLE_VALUE, "Sparse high-offset fixture creation failed");
                DWORD returned{}; require(DeviceIoControl(output.handle, FSCTL_SET_SPARSE, nullptr, 0, nullptr, 0, &returned, nullptr) != FALSE, "Sparse fixture not supported");
                LARGE_INTEGER position{}; position.QuadPart = high_offset;
                require(SetFilePointerEx(output.handle, position, nullptr, FILE_BEGIN) && WriteFile(output.handle, expected.data(), 65536, &returned, nullptr) && returned == 65536, "High-offset fixture write failed");
            }
            File high_native{CreateFileW(high_pak.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
            File high_game{CreateFileW(high_pak.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
            const auto high_control = perform(high_native.handle, true, high_offset, 65536, 0x103, false, false);
            const auto high_actual = perform(high_game.handle, false, high_offset, 65536, 0x103, false, false);
            require(same(high_control, high_actual), "OffsetHigh > 0 differs from native");
            // Reach the live first-64 oracle bound, then ensure extra successful
            // requests do not misrepresent later requests as re-verified.
            for (unsigned i = 0; i < 70; ++i) {
                const uint64_t offset = (i % 16) * UINT64_C(65536);
                const auto control = perform(native_file.handle, true, offset, 65536, i % 2 ? 0x103 : 0xdeadbeef, false, false);
                const auto actual = perform(game_file.handle, false, offset, 65536, i % 2 ? 0x103 : 0xdeadbeef, false, false);
                require(same(control, actual), "Repeated sync OV native comparison failed");
            }
            BridgeStats result{};
            require(get_stats(&result, sizeof(result)) && result.enabled && result.verified_reads == 64 && result.verification_errors == 0 && result.verification_mismatches == 0 && result.reads > 64, "Native first64 verification counters invalid");
            if (present) present();
            std::printf("PASS: synchronous null-event OVERLAPPED exact native contract (status/count/LastError/cursor/offset/GetOverlappedResult), EOF/error/event fallbacks, OffsetHigh>0; DSreads=%llu native_verified=64 mismatches=0.\n", result.reads);
            return 0;
        }
        File sequential{CreateFileW(pak.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
        require(sequential.handle != INVALID_HANDLE_VALUE, "Readonly fixture open failed");
        if (mode == L"--mixed") {
            std::vector<uint8_t> large(64 * 1024), small(32 * 1024); DWORD large_count{}, small_count{};
            std::atomic<bool> large_ok{};
            std::thread reader([&] { large_ok = ReadFile(sequential.handle, large.data(), static_cast<DWORD>(large.size()), &large_count, nullptr) != FALSE; });
            BridgeStats waiting{};
            for (unsigned attempt = 0; attempt < 100; ++attempt) { require(get_stats(&waiting, sizeof(waiting)), "Cannot inspect pending read"); if (waiting.pending_jobs) break; Sleep(1); }
            const auto small_ok = ReadFile(sequential.handle, small.data(), static_cast<DWORD>(small.size()), &small_count, nullptr);
            reader.join();
            require(large_ok && large_count == large.size() && std::equal(large.begin(), large.end(), expected.begin()), "Delayed DS read failed");
            require(small_ok && small_count == small.size() && std::equal(small.begin(), small.end(), expected.begin() + large.size()), "Small native fallback raced the DS file pointer");
            File alias; require(DuplicateHandle(GetCurrentProcess(), sequential.handle, GetCurrentProcess(), &alias.handle, 0, FALSE, DUPLICATE_SAME_ACCESS) != FALSE, "Duplicate-handle fixture failed");
            LARGE_INTEGER begin{}; require(SetFilePointerEx(sequential.handle, begin, nullptr, FILE_BEGIN) != FALSE, "Alias rewind failed");
            large_ok = false;
            std::thread alias_reader([&] { large_ok = ReadFile(sequential.handle, large.data(), static_cast<DWORD>(large.size()), &large_count, nullptr) != FALSE; });
            for (unsigned attempt = 0; attempt < 100; ++attempt) { require(get_stats(&waiting, sizeof(waiting)), "Cannot inspect alias read"); if (waiting.pending_jobs) break; Sleep(1); }
            const auto alias_small_ok = ReadFile(alias.handle, small.data(), static_cast<DWORD>(small.size()), &small_count, nullptr);
            alias_reader.join();
            require(large_ok && alias_small_ok && std::equal(large.begin(), large.end(), expected.begin()) && std::equal(small.begin(), small.end(), expected.begin() + large.size()), "Duplicated alias bypassed file-identity serialization");
            require(SetFilePointerEx(sequential.handle, begin, nullptr, FILE_BEGIN) != FALSE, "Alias seek rewind failed");
            std::thread seek_reader([&] { large_ok = ReadFile(sequential.handle, large.data(), static_cast<DWORD>(large.size()), &large_count, nullptr) != FALSE; });
            for (unsigned attempt = 0; attempt < 100; ++attempt) { require(get_stats(&waiting, sizeof(waiting)), "Cannot inspect seek read"); if (waiting.pending_jobs) break; Sleep(1); }
            const auto alias_seek = SetFilePointer(alias.handle, 128 * 1024, nullptr, FILE_BEGIN);
            seek_reader.join();
            require(large_ok && std::equal(large.begin(), large.end(), expected.begin()) && alias_seek == 128 * 1024, "Duplicated alias seek raced an active DS read");
            std::puts("PASS: delayed DS, small native fallback, duplicated-handle aliases and alias seeks serialize by file identity.");
            return 0;
        }
        if (mode == L"--timeout") {
            std::vector<uint8_t> actual(1024 * 1024); DWORD count{};
            require(ReadFile(sequential.handle, actual.data(), static_cast<DWORD>(actual.size()), &count, nullptr) && count == actual.size() && std::equal(actual.begin(), actual.end(), expected.begin()), "Timeout native fallback corrupted output");
            BridgeStats pending{}; require(get_stats(&pending, sizeof(pending)) && !pending.enabled && pending.timeouts == 1 && pending.reads == 0 && pending.pending_jobs == 1 && pending.private_buffers == 1, "Timed-out job/buffer not safely quarantined");
            if (present) present();
            require(get_stats(&pending, sizeof(pending)) && pending.private_buffers == 1, "Buffer freed before final queued event");
            Sleep(700);
            if (present) present();
            require(get_stats(&pending, sizeof(pending)) && pending.pending_jobs == 0 && pending.private_buffers == 0, "Completed quarantined job not cleaned up");
            require(std::equal(actual.begin(), actual.end(), expected.begin()), "Late DirectStorage work wrote into native game buffer");
            std::puts("PASS: forced timeout disables bridge, native fallback preserves bytes, private job survives cancellation until last event, deferred cleanup releases buffer safely.");
            return 0;
        }
        compare(sequential.handle, expected, 0, 1024 * 1024);
        compare(sequential.handle, expected, 1024 * 1024, 64 * 1024);
        require(SetFilePointer(sequential.handle, 128 * 1024, nullptr, FILE_BEGIN) == 128 * 1024, "SetFilePointer failed");
        compare(sequential.handle, expected, 128 * 1024, 256 * 1024);
        LARGE_INTEGER near_end{}; near_end.QuadPart = expected.size() - 32 * 1024;
        require(SetFilePointerEx(sequential.handle, near_end, nullptr, FILE_BEGIN) != FALSE, "Near-EOF seek failed");
        compare(sequential.handle, expected, expected.size() - 32 * 1024, 64 * 1024);
        compare(sequential.handle, expected, expected.size(), 64 * 1024);

        // Shared-handle sequential reads: each block must appear once, and the
        // final native file position must match the total bytes consumed.
        File concurrent{CreateFileW(pak.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
        std::array<std::atomic<unsigned>, 16> seen{};
        std::atomic<bool> thread_ok{true};
        std::vector<std::thread> threads;
        for (unsigned thread = 0; thread < 4; ++thread) threads.emplace_back([&] {
            for (unsigned item = 0; item < 4; ++item) {
                std::vector<uint8_t> actual(64 * 1024); DWORD count{};
                if (!ReadFile(concurrent.handle, actual.data(), static_cast<DWORD>(actual.size()), &count, nullptr) || count != actual.size()) { thread_ok = false; return; }
                bool found = false;
                for (size_t block = 0; block < seen.size(); ++block) if (std::equal(actual.begin(), actual.end(), expected.begin() + block * actual.size())) { ++seen[block]; found = true; break; }
                if (!found) thread_ok = false;
            }
        });
        for (auto& thread : threads) thread.join();
        require(thread_ok && std::all_of(seen.begin(), seen.end(), [](const auto& count) { return count.load() == 1; }), "Concurrent read mismatch/duplicate block");
        LARGE_INTEGER zero{}, final_position{};
        require(SetFilePointerEx(concurrent.handle, zero, &final_position, FILE_CURRENT) && final_position.QuadPart == 1024 * 1024, "Concurrent final pointer mismatch");

        File ordinary_file{CreateFileW(ordinary.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
        compare(ordinary_file.handle, expected, 0, 64 * 1024); // Non-PAK native fallback.
        // Compare native fallback's LastError and byte-count behavior against
        // the actual unmodified Windows function, bypassing this EXE's IAT.
        const auto original_read = reinterpret_cast<decltype(&ReadFile)>(GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "ReadFile"));
        std::array<uint8_t, 64 * 1024> native_data{}, hooked_data{}; DWORD native_count{}, hooked_count{};
        SetLastError(0x250123);
        const auto native_result = original_read(ordinary_file.handle, native_data.data(), static_cast<DWORD>(native_data.size()), &native_count, nullptr);
        const auto native_error = GetLastError();
        LARGE_INTEGER rewind{}; rewind.QuadPart = 64 * 1024;
        require(SetFilePointerEx(ordinary_file.handle, rewind, nullptr, FILE_BEGIN) != FALSE, "Fallback seek failed");
        SetLastError(0x250123);
        const auto hooked_result = ReadFile(ordinary_file.handle, hooked_data.data(), static_cast<DWORD>(hooked_data.size()), &hooked_count, nullptr);
        const auto hooked_error = GetLastError();
        require(native_result == hooked_result && native_error == hooked_error && native_count == hooked_count && native_data == hooked_data, "Native fallback LastError/count/data mismatch");
        File writable{CreateFileW(writable_pak.c_str(), GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
        // Close readonly handles first so write access is not denied by sharing.
        CloseHandle(sequential.handle); sequential.handle = INVALID_HANDLE_VALUE;
        CloseHandle(concurrent.handle); concurrent.handle = INVALID_HANDLE_VALUE;
        if (present) present(); // Release idle private DS file handles off the I/O hook.
        File later_write{CreateFileW(pak.c_str(), GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
        require(later_write.handle != INVALID_HANDLE_VALUE, "Idle private DS handle retained a sharing restriction after game close");
        CloseHandle(later_write.handle); later_write.handle = INVALID_HANDLE_VALUE;
        File stale{CreateFileW(pak.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
        compare(stale.handle, expected, 0, 64 * 1024);
        const auto old_number = stale.handle;
        const auto original_close = reinterpret_cast<decltype(&CloseHandle)>(GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "CloseHandle"));
        require(original_close(stale.handle) != FALSE, "Foreign CloseHandle fixture failed"); stale.handle = INVALID_HANDLE_VALUE;
        File reused;
        for (unsigned attempt = 0; attempt < 128; ++attempt) {
            reused.handle = CreateFileW(reused_pak.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
            require(reused.handle != INVALID_HANDLE_VALUE, "Reused-handle fixture open failed");
            if (reused.handle == old_number) break;
            original_close(reused.handle); reused.handle = INVALID_HANDLE_VALUE;
        }
        require(reused.handle == old_number, "Windows did not recycle the fixture HANDLE; stale-cache regression could not run");
        compare(reused.handle, other_content, 0, 64 * 1024);
        require(writable.handle != INVALID_HANDLE_VALUE, "Writable fallback fixture open failed");
        compare(writable.handle, expected, 0, 64 * 1024);

        File asynchronous{CreateFileW(pak.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr)};
        require(asynchronous.handle != INVALID_HANDLE_VALUE, "Async fallback fixture open failed");
        OVERLAPPED operation{}; operation.Offset = 64 * 1024; operation.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        std::vector<uint8_t> actual(64 * 1024); DWORD transferred{};
        const bool read_now = ReadFile(asynchronous.handle, actual.data(), static_cast<DWORD>(actual.size()), &transferred, &operation) != FALSE;
        require(read_now || GetLastError() == ERROR_IO_PENDING, "Async native fallback failed");
        require(WaitForSingleObject(operation.hEvent, 5000) == WAIT_OBJECT_0 && GetOverlappedResult(asynchronous.handle, &operation, &transferred, FALSE), "Async fallback wait failed");
        require(transferred == actual.size() && std::equal(actual.begin(), actual.end(), expected.begin() + 64 * 1024), "Async fallback bytes differ");
        CloseHandle(operation.hEvent);
        if (present) present();
        BridgeStats result{};
        require(get_stats(&result, sizeof(result)) && result.enabled && result.reads >= 20 && result.bytes > 1024 * 1024 && result.fallbacks >= 4 && result.timeouts == 0, "Bridge counters do not prove actual reads/fallbacks");
        std::printf("PASS: REAL DirectStorage PAK reads=%llu bytes=%llu native_fallbacks=%llu; sequential/random/EOF/shared-handle concurrency/readonly/access/async semantics verified in isolated mock RE8 host.\n", result.reads, result.bytes, result.fallbacks);
        std::puts("Actual RE8 gameplay streaming activation, GPU decompression and performance remain unverified.");
        return 0;
    } catch (const std::exception& error) { std::fprintf(stderr, "FAIL: %s (Win32=%lu)\n", error.what(), GetLastError()); return 1; }
}
#endif
