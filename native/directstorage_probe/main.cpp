#include <Windows.h>
#include <dstorage.h>
#include <array>
#include <cstdint>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

namespace fs = std::filesystem;

namespace {
constexpr size_t data_size = 1024 * 1024;
constexpr DWORD timeout_ms = 10000;

void check(HRESULT result, const char* action) {
    if (FAILED(result)) {
        std::cerr << action << " HRESULT=0x" << std::hex << static_cast<unsigned long>(result) << std::dec << '\n';
        throw std::runtime_error(action);
    }
}

std::vector<uint8_t> generate_data() {
    std::vector<uint8_t> data(data_size);
    uint32_t state = 0x52453825;
    for (auto& value : data) {
        state ^= state << 13; state ^= state >> 17; state ^= state << 5;
        value = static_cast<uint8_t>(state >> 24);
    }
    return data;
}

uint32_t crc32(const uint8_t* data, size_t size) {
    uint32_t crc = 0xffffffff;
    for (size_t i = 0; i < size; ++i) {
        crc ^= data[i];
        for (int bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
    }
    return ~crc;
}

struct Handle {
    HANDLE value{};
    ~Handle() { if (value && value != INVALID_HANDLE_VALUE) CloseHandle(value); }
};
template<class T> struct Com {
    T* value{};
    ~Com() { if (value) value->Release(); }
    T* operator->() const { return value; }
    void** out() { return reinterpret_cast<void**>(&value); }
};
struct Module {
    HMODULE value{};
    ~Module() { if (value) FreeLibrary(value); }
};
struct TemporaryFile {
    fs::path path;
    ~TemporaryFile() { if (!path.empty()) DeleteFileW(path.c_str()); }
};
struct QueueClose {
    IDStorageQueue* queue{};
    ~QueueClose() { if (queue) queue->Close(); }
};

// Bounds the whole isolated probe, including a runtime call which might fail
// to return. It can terminate only this newly created probe process.
class Deadline {
public:
    Deadline() : m_cancel{CreateEventW(nullptr, TRUE, FALSE, nullptr)} {
        if (!m_cancel.value) throw std::runtime_error("Cannot create deadline event");
        m_thread = std::thread([this] {
            if (WaitForSingleObject(m_cancel.value, timeout_ms + 7000) == WAIT_TIMEOUT) {
                std::cerr << "FAIL: compatibility probe deadline reached.\n" << std::flush;
                TerminateProcess(GetCurrentProcess(), 124);
            }
        });
    }
    ~Deadline() { SetEvent(m_cancel.value); if (m_thread.joinable()) m_thread.join(); }
private:
    Handle m_cancel;
    std::thread m_thread;
};

fs::path own_directory() {
    std::array<wchar_t, 32768> name{};
    const DWORD length = GetModuleFileNameW(nullptr, name.data(), static_cast<DWORD>(name.size()));
    if (length == 0 || length >= name.size()) throw std::runtime_error("Cannot resolve probe path");
    return fs::canonical(fs::path{name.data()}).parent_path();
}

void reject_game_directory(const fs::path& own) {
    for (auto current = own; !current.empty(); current = current.parent_path()) {
        if (fs::exists(current / L"re8.exe")) throw std::runtime_error("Extract this standalone kit outside the RE8 directory");
        if (current == current.root_path()) break;
    }
}

void load_local(Module& result, const fs::path& own, const wchar_t* filename) {
    const auto path = own / filename;
    if (!fs::is_regular_file(path)) throw std::runtime_error("Private runtime missing; run the kit setup first");
    const auto attributes = GetFileAttributesW(path.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & FILE_ATTRIBUTE_REPARSE_POINT))
        throw std::runtime_error("Private runtime must be an ordinary file in the probe folder");
    if (GetModuleHandleW(filename)) throw std::runtime_error("A DirectStorage module was loaded before the isolated probe");
    result.value = LoadLibraryExW(path.c_str(), nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!result.value) throw std::runtime_error("Cannot load the runtime from the probe's own folder");
}

int selftest() {
    const std::string known = "123456789";
    if (crc32(reinterpret_cast<const uint8_t*>(known.data()), known.size()) != 0xcbf43926)
        throw std::runtime_error("CRC32 known-vector failure");
    auto expected = generate_data();
    auto actual = generate_data();
    if (expected != actual || expected.size() != data_size) throw std::runtime_error("Data generator failure");
    const auto original = crc32(actual.data(), actual.size());
    actual[513] ^= 1;
    if (expected == actual || crc32(actual.data(), actual.size()) == original)
        throw std::runtime_error("Corruption detection failure");
    std::cout << "PASS: generator, CRC32 known vector and corruption detection; no DirectStorage DLL loaded.\n";
    return 0;
}

int probe() {
    const auto own = own_directory();
    reject_game_directory(own);
    std::cout << "Standalone compatibility check only; no RE8 integration, GPU decompression or benchmark.\n" << std::flush;
    Deadline deadline;
    Module core, runtime;
    load_local(core, own, L"dstoragecore.dll");
    load_local(runtime, own, L"dstorage.dll");
    using Configure = HRESULT (WINAPI*)(const DSTORAGE_CONFIGURATION2*);
    using GetFactory = HRESULT (WINAPI*)(REFIID, void**);
    const auto configure = reinterpret_cast<Configure>(GetProcAddress(runtime.value, "DStorageSetConfiguration2"));
    const auto get_factory = reinterpret_cast<GetFactory>(GetProcAddress(runtime.value, "DStorageGetFactory"));
    if (!configure || !get_factory) throw std::runtime_error("Required preview exports unavailable");
    DSTORAGE_CONFIGURATION2 configuration{};
    configuration.NumSubmitThreads = 1;
    configuration.NumBuiltInCpuDecompressionThreads = 1;
    configuration.DisableTelemetry = TRUE;
    configuration.DisableGpuDecompression = TRUE;
    check(configure(&configuration), "DStorageSetConfiguration2");
    Com<IDStorageFactory> factory;
    check(get_factory(__uuidof(IDStorageFactory), factory.out()), "DStorageGetFactory");

    const auto expected = generate_data();
    TemporaryFile temporary{own / (L"RE8DirectStorageProbe-data-" + std::to_wstring(GetCurrentProcessId())
        + L"-" + std::to_wstring(GetTickCount64()) + L".bin")};
    {
        Handle output{CreateFileW(temporary.path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW,
            FILE_ATTRIBUTE_TEMPORARY, nullptr)};
        if (output.value == INVALID_HANDLE_VALUE) { temporary.path.clear(); throw std::runtime_error("Cannot create probe-owned test file"); }
        DWORD written{};
        if (!WriteFile(output.value, expected.data(), static_cast<DWORD>(expected.size()), &written, nullptr)
            || written != expected.size()) throw std::runtime_error("Cannot write the complete test file");
    }
    Com<IDStorageFile> source;
    check(factory->OpenFile(temporary.path.c_str(), __uuidof(IDStorageFile), source.out()), "OpenFile");
    DSTORAGE_QUEUE_DESC description{};
    description.SourceType = DSTORAGE_REQUEST_SOURCE_FILE;
    description.Capacity = DSTORAGE_MIN_QUEUE_CAPACITY;
    description.Priority = DSTORAGE_PRIORITY_NORMAL;
    description.Name = "RE8 standalone compatibility check";
    description.Device = nullptr; // File to ordinary CPU memory; no GPU device.
    Com<IDStorageQueue1> queue;
    check(factory->CreateQueue(&description, __uuidof(IDStorageQueue1), queue.out()), "CreateQueue");
    QueueClose close_queue{queue.value};
    Com<IDStorageStatusArray> status;
    check(factory->CreateStatusArray(1, "Probe status", __uuidof(IDStorageStatusArray), status.out()), "CreateStatusArray");
    Handle complete{CreateEventW(nullptr, TRUE, FALSE, nullptr)};
    if (!complete.value) throw std::runtime_error("Cannot create completion event");
    std::vector<uint8_t> actual(data_size, 0);
    DSTORAGE_REQUEST request{};
    request.Options.CompressionFormat = DSTORAGE_COMPRESSION_FORMAT_NONE;
    request.Options.SourceType = DSTORAGE_REQUEST_SOURCE_FILE;
    request.Options.DestinationType = DSTORAGE_REQUEST_DESTINATION_MEMORY;
    request.Source.File.Source = source.value;
    request.Source.File.Offset = 0;
    request.Source.File.Size = static_cast<UINT32>(data_size);
    request.UncompressedSize = static_cast<UINT32>(data_size);
    request.Destination.Memory.Buffer = actual.data();
    request.Destination.Memory.Size = static_cast<UINT32>(actual.size());
    request.CancellationTag = 0x524538;
    request.Name = "Deterministic 1 MiB compatibility read";
    queue->EnqueueRequest(&request);
    queue->EnqueueStatus(status.value, 0);
    queue->EnqueueSetEvent(complete.value);
    queue->Submit();
    const auto wait = WaitForSingleObject(complete.value, timeout_ms);
    if (wait != WAIT_OBJECT_0) {
        queue->CancelRequestsWithTag(UINT64_MAX, request.CancellationTag);
        // Close before CPU buffers/events are destroyed; watchdog bounds a hung Close.
        queue->Close(); close_queue.queue = nullptr;
        throw std::runtime_error(wait == WAIT_TIMEOUT ? "DirectStorage request timed out" : "Completion wait failed");
    }
    check(status->GetHResult(0), "DirectStorage read completion");
    if (actual != expected) throw std::runtime_error("DirectStorage returned different bytes");
    const auto checksum = crc32(actual.data(), actual.size());
    source->Close();
    std::cout << "PASS: DirectStorage file-to-CPU-memory read, bytes=1048576 CRC32="
        << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << checksum << std::dec
        << "; all bytes match.\nRE8 streaming integration and performance remain untested.\n";
    return 0;
}
} // namespace

int wmain(int argc, wchar_t** argv) {
    try {
        if (argc == 1 || (argc == 2 && (std::wstring{argv[1]} == L"--help" || std::wstring{argv[1]} == L"-h"))) {
            std::cout << "RE8 DirectStorage 1.4 compatibility kit (standalone; no game integration)\n"
                "--help       Show help without loading DirectStorage.\n"
                "--selftest   Test data/checksum logic without loading DirectStorage.\n"
                "--probe      Read 1 MiB using privately installed preview DLLs beside this EXE.\n"
                "             No GPU decompression, timings or benchmark. Run outside RE8.\n";
            return 0;
        }
        if (argc == 2 && std::wstring{argv[1]} == L"--selftest") return selftest();
        if (argc == 2 && std::wstring{argv[1]} == L"--probe") return probe();
        std::cerr << "Unknown argument; use --help.\n";
        return 2;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
