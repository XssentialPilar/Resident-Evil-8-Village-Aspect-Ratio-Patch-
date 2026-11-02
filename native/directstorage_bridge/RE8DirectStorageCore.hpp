#pragma once
#include <Windows.h>
#include <winternl.h>
#include <dstorage.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <cstdint>
#include <cctype>
#include <cstring>
#include <cwctype>
#include <filesystem>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

namespace re8_ds {
inline constexpr DWORD minimum_read = 64 * 1024, maximum_read = 8 * 1024 * 1024;
inline constexpr DWORD read_timeout_ms = 250;
enum class Fallback : size_t { disabled, size, overlapped, metadata, path, access, mode, identity,
    position, queue_full, runtime_error, timeout, allocation, copy, compatibility, verification, count };
inline std::atomic<uint64_t> reads{}, bytes{}, fallbacks{};
inline std::atomic<uint64_t> overlap_nonnull{}, count_null{}, buffer_null{};
inline std::atomic<uint64_t> verified_reads{}, verification_errors{}, verification_mismatches{};
inline std::atomic<uint64_t> native_compat_reads{}, native_compat_errors{};
struct IoSampleData {
    DWORD length{}, mode{}, access{}, offset{}, offset_high{};
    ULONG_PTR internal{};
    bool overlap{}, count_missing{}, buffer_missing{}, mode_valid{}, access_valid{}, pak_under_root{}, overlap_readable{}, event_lowbit{}, event_nonnull{};
};
struct IoSample { IoSampleData data{}; std::atomic<bool> ready{}; };
inline std::array<IoSample, 8> io_samples;
inline std::atomic<uint32_t> io_sample_claimed{};
#ifdef RE8_DS_TESTING
inline std::atomic<int> test_mode{};
#endif
inline std::array<std::atomic<uint64_t>, static_cast<size_t>(Fallback::count)> reasons{};
inline void fallback(Fallback reason) { ++fallbacks; ++reasons[static_cast<size_t>(reason)]; }

inline std::wstring lowercase(std::wstring value) {
    std::transform(value.begin(), value.end(), value.begin(), [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
    return value;
}
inline std::wstring final_path(HANDLE handle) {
    std::vector<wchar_t> data(32768);
    const auto length = GetFinalPathNameByHandleW(handle, data.data(), static_cast<DWORD>(data.size()), FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    return length && length < data.size() ? std::wstring{data.data(), length} : std::wstring{};
}
inline std::filesystem::path executable_path() {
    std::array<wchar_t, 32768> value{};
    const auto length = GetModuleFileNameW(nullptr, value.data(), static_cast<DWORD>(value.size()));
    return length && length < value.size() ? std::filesystem::path{value.data()} : std::filesystem::path{};
}
inline bool same_file(const BY_HANDLE_FILE_INFORMATION& a, const BY_HANDLE_FILE_INFORMATION& b) {
    return a.dwVolumeSerialNumber == b.dwVolumeSerialNumber && a.nFileIndexHigh == b.nFileIndexHigh &&
        a.nFileIndexLow == b.nFileIndexLow;
}
inline bool safe_copy(void* destination, const void* source, size_t size, DWORD* count) noexcept {
    __try { std::memcpy(destination, source, size); *count = static_cast<DWORD>(size); return true; }
    __except(EXCEPTION_EXECUTE_HANDLER) { return false; }
}
template<class T> struct Com {
    T* value{};
    ~Com() { if (value) value->Release(); }
    T* operator->() const { return value; }
    void** out() { return reinterpret_cast<void**>(&value); }
};
struct StorageFile {
    Com<IDStorageFile> file;
    BY_HANDLE_FILE_INFORMATION identity{};
    std::wstring path;
};
struct Job {
    Job(size_t size, std::atomic<uint32_t>* owner) : data(size), allocation_owner(owner) { complete = CreateEventW(nullptr, TRUE, FALSE, nullptr); }
    ~Job() { if (complete) CloseHandle(complete); --*allocation_owner; }
    std::vector<uint8_t> data;
    std::shared_ptr<StorageFile> source;
    Com<IDStorageStatusArray> status;
    HANDLE complete{};
    std::atomic<bool> submitted{};
    uint64_t tag{};
    std::atomic<uint32_t>* allocation_owner{};
};

class Runtime {
public:
    bool initialize(const std::filesystem::path& root) {
        if (GetModuleHandleW(L"dstorage.dll") || GetModuleHandleW(L"dstoragecore.dll")) return false;
        for (const auto name : {L"dstoragecore.dll", L"dstorage.dll"}) {
            const auto path = root / L"RE8DirectStorage" / name;
            const auto attributes = GetFileAttributesW(path.c_str());
            if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT))) return false;
            const auto module = LoadLibraryExW(path.c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
            if (!module) return false;
            // Keep the runtime resident for the lifetime of this plugin/process.
            // No unloading a module which may own worker threads or timed-out jobs.
            if (std::wstring{name} == L"dstorage.dll") m_module = module;
        }
        using Configure = HRESULT (WINAPI*)(const DSTORAGE_CONFIGURATION2*);
        using GetFactory = HRESULT (WINAPI*)(REFIID, void**);
        const auto configure = reinterpret_cast<Configure>(GetProcAddress(m_module, "DStorageSetConfiguration2"));
        const auto factory = reinterpret_cast<GetFactory>(GetProcAddress(m_module, "DStorageGetFactory"));
        if (!configure || !factory) return false;
        DSTORAGE_CONFIGURATION2 configuration{};
        configuration.NumSubmitThreads = 1;
        configuration.NumBuiltInCpuDecompressionThreads = 1;
        configuration.DisableTelemetry = TRUE;
        configuration.DisableGpuDecompression = TRUE;
        if (FAILED(configure(&configuration)) || FAILED(factory(__uuidof(IDStorageFactory), m_factory.out()))) return false;
        DSTORAGE_QUEUE_DESC description{};
        description.SourceType = DSTORAGE_REQUEST_SOURCE_FILE;
        description.Capacity = DSTORAGE_MIN_QUEUE_CAPACITY;
        description.Priority = DSTORAGE_PRIORITY_NORMAL;
        description.Name = "RE8 bounded PAK CPU reads";
        description.Device = nullptr;
        if (FAILED(m_factory->CreateQueue(&description, __uuidof(IDStorageQueue1), m_queue.out()))) return false;
        enabled.store(true);
        return true;
    }
    std::shared_ptr<StorageFile> open(const std::wstring& path, const BY_HANDLE_FILE_INFORMATION& identity) {
        std::scoped_lock lock{m_mutex};
        const auto key = lowercase(path);
        if (const auto found = m_files.find(key); found != m_files.end())
            return same_file(identity, found->second->identity) ? found->second : nullptr;
        if (m_files.size() >= 64) return nullptr;
        auto file = std::make_shared<StorageFile>();
        file->path = path;
        if (FAILED(m_factory->OpenFile(path.c_str(), __uuidof(IDStorageFile), file->file.out())) ||
            FAILED(file->file->GetFileInformation(&file->identity)) || !same_file(identity, file->identity)) return nullptr;
        // Reuse per-path handles while game handles/jobs need them. Close only
        // from deferred collection, never from a game CloseHandle hook.
        m_files.emplace(key, file);
        return file;
    }
    std::shared_ptr<std::mutex> file_group(const BY_HANDLE_FILE_INFORMATION& identity) {
        std::scoped_lock lock{m_mutex};
        const auto key = std::to_wstring(identity.dwVolumeSerialNumber) + L":" +
            std::to_wstring(identity.nFileIndexHigh) + L":" + std::to_wstring(identity.nFileIndexLow);
        if (const auto found = m_groups.find(key); found != m_groups.end())
            if (auto group = found->second.lock()) return group;
        if (m_groups.size() >= 4096) std::erase_if(m_groups, [](const auto& entry) { return entry.second.expired(); });
        if (m_groups.size() >= 4096) return {};
        auto group = std::make_shared<std::mutex>();
        m_groups[key] = group;
        return group;
    }
    std::shared_ptr<Job> read(const std::shared_ptr<StorageFile>& source, uint64_t offset, DWORD length) {
        if (!enabled.load()) { fallback(Fallback::disabled); return {}; }
        if (m_allocated.fetch_add(1) >= 8) { --m_allocated; fallback(Fallback::queue_full); return {}; }
        std::shared_ptr<Job> job;
        try { job = std::make_shared<Job>(length, &m_allocated); }
        catch (...) { --m_allocated; throw; }
        job->source = source;
        if (!job->complete || FAILED(m_factory->CreateStatusArray(1, "RE8 PAK read", __uuidof(IDStorageStatusArray), job->status.out()))) {
            fallback(Fallback::runtime_error); return {};
        }
        {
            std::scoped_lock lock{m_mutex};
            if (m_jobs.size() >= 8 || !enabled.load()) { fallback(Fallback::queue_full); return {}; }
            job->tag = ++m_next_tag;
            m_jobs.push_back(job);
            DSTORAGE_REQUEST request{};
            request.Options.CompressionFormat = DSTORAGE_COMPRESSION_FORMAT_NONE;
            request.Options.SourceType = DSTORAGE_REQUEST_SOURCE_FILE;
            request.Options.DestinationType = DSTORAGE_REQUEST_DESTINATION_MEMORY;
            request.Source.File.Source = source->file.value;
            request.Source.File.Offset = offset;
            request.Source.File.Size = length;
            request.UncompressedSize = length;
            request.Destination.Memory.Buffer = job->data.data();
            request.Destination.Memory.Size = length;
            request.CancellationTag = job->tag;
            request.Name = "Raw PAK bytes; game keeps original decompression";
            m_queue->EnqueueRequest(&request);
            m_queue->EnqueueStatus(job->status.value, 0);
            m_queue->EnqueueSetEvent(job->complete);
            #ifdef RE8_DS_TESTING
            if (test_mode.load() == 1 || test_mode.load() == 3) {
                // Test-only binary: retain the actual queued request/event
                // past native fallback, then submit after cancellation.
                const DWORD delay = test_mode.load() == 1 ? 500 : 100;
                std::thread([this, delay] { Sleep(delay); std::scoped_lock lock{m_mutex}; m_queue->Submit(); }).detach();
            } else
            #endif
            m_queue->Submit();
            job->submitted.store(true, std::memory_order_release);
        }
        const auto wait =
            #ifdef RE8_DS_TESTING
            test_mode.load() == 1 ? WAIT_TIMEOUT :
            #endif
            WaitForSingleObject(job->complete, read_timeout_ms);
        if (wait != WAIT_OBJECT_0) {
            enabled.store(false);
            m_queue->CancelRequestsWithTag(UINT64_MAX, job->tag);
            // Native ReadFile receives the untouched game buffer. This private
            // job remains quarantined until its status actually completes.
            fallback(Fallback::timeout);
            return {};
        }
        const auto result = job->status->GetHResult(0);
        {
            std::scoped_lock lock{m_mutex};
            std::erase(m_jobs, job);
        }
        if (FAILED(result)) { fallback(Fallback::runtime_error); return {}; }
        return job;
    }
    bool verify(const std::shared_ptr<Job>& job, const BY_HANDLE_FILE_INFORMATION& game_identity, uint64_t offset) noexcept {
        try {
            std::scoped_lock lock{m_verify_mutex};
            if (!enabled.load()) return false;
            if (verified_reads.load() >= 64) return true;
            // Verify before touching the caller's buffer, cursor or OVERLAPPED.
            // This handle is independent of the game's native file cursor.
            struct Reference {
                HANDLE handle{INVALID_HANDLE_VALUE};
                ~Reference() { if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle); }
            } reference{CreateFileW(job->source->path.c_str(), GENERIC_READ,
                FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
            BY_HANDLE_FILE_INFORMATION identity{};
            if (reference.handle == INVALID_HANDLE_VALUE || !GetFileInformationByHandle(reference.handle, &identity) ||
                !same_file(identity, game_identity) || !same_file(identity, job->source->identity)) {
                enabled.store(false); ++verification_errors; fallback(Fallback::verification); return false;
            }
            std::vector<uint8_t> native_data(job->data.size());
            OVERLAPPED operation{}; operation.Offset = static_cast<DWORD>(offset); operation.OffsetHigh = static_cast<DWORD>(offset >> 32);
            DWORD transferred{};
            // This DLL's own Windows import is not the game's patched IAT.
            if (!::ReadFile(reference.handle, native_data.data(), static_cast<DWORD>(native_data.size()), &transferred, &operation) || transferred != native_data.size()) {
                enabled.store(false); ++verification_errors; fallback(Fallback::verification); return false;
            }
            #ifdef RE8_DS_TESTING
            if (test_mode.load() == 4 && !job->data.empty()) job->data[0] ^= 0x5a;
            #endif
            if (native_data != job->data) {
                enabled.store(false); ++verification_mismatches; fallback(Fallback::verification); return false;
            }
            ++verified_reads;
            return true;
        } catch (...) { enabled.store(false); ++verification_errors; fallback(Fallback::verification); return false; }
    }
    size_t pending_count() { std::scoped_lock lock{m_mutex}; return m_jobs.size(); }
    uint32_t allocated_count() const { return m_allocated.load(); }
    void collect() {
        std::scoped_lock lock{m_mutex};
        std::erase_if(m_jobs, [](const auto& job) {
            // The event is the LAST queued operation. A status entry can
            // complete before that event is signaled; never close its HANDLE
            // while the queue may still signal it.
            return job->submitted.load(std::memory_order_acquire) && WaitForSingleObject(job->complete, 0) == WAIT_OBJECT_0;
        });
        std::erase_if(m_files, [](const auto& entry) {
            if (entry.second.use_count() != 1) return false;
            entry.second->file->Close();
            return true;
        });
    }
    std::atomic<bool> enabled{};
private:
    HMODULE m_module{};
    Com<IDStorageFactory> m_factory;
    Com<IDStorageQueue1> m_queue;
    std::mutex m_mutex;
    std::mutex m_verify_mutex;
    uint64_t m_next_tag{};
    std::atomic<uint32_t> m_allocated{};
    std::vector<std::shared_ptr<Job>> m_jobs;
    std::unordered_map<std::wstring, std::shared_ptr<StorageFile>> m_files;
    std::unordered_map<std::wstring, std::weak_ptr<std::mutex>> m_groups;
};

struct HandleState {
    std::mutex mutex;
    bool examined{}, eligible{};
    Fallback rejected{Fallback::metadata};
    std::shared_ptr<StorageFile> source;
    std::shared_ptr<std::mutex> file_mutex;
    BY_HANDLE_FILE_INFORMATION identity{};
};
using NativeQuery = NTSTATUS (NTAPI*)(HANDLE, PIO_STATUS_BLOCK, PVOID, ULONG, FILE_INFORMATION_CLASS);
inline NativeQuery query_information{};
inline std::wstring root_prefix;
inline Runtime* runtime{};
inline std::mutex handles_mutex;
inline std::unordered_map<HANDLE, std::shared_ptr<HandleState>> handles;
inline std::atomic<bool> installed{};
inline decltype(&ReadFile) native_read{};
inline decltype(&SetFilePointer) native_seek{};
inline decltype(&SetFilePointerEx) native_seek_ex{};
inline decltype(&CloseHandle) native_close{};

inline bool update_native_read_bookkeeping(HANDLE lease, uint64_t last_offset, uint8_t expected) noexcept {
    // Windows EOF cursor behavior depends on whether this FILE_OBJECT has
    // actually performed a native read before. A private native read of the
    // LAST byte establishes real kernel read state and cursor=end, while the
    // caller's complete bulk payload still comes from DirectStorage.
    OVERLAPPED operation{};
    operation.Offset = static_cast<DWORD>(last_offset);
    operation.OffsetHigh = static_cast<DWORD>(last_offset >> 32);
    uint8_t value{}; DWORD transferred{};
    if (native_read(lease, &value, 1, &transferred, &operation) && transferred == 1 && value == expected &&
        operation.Internal == 0 && operation.InternalHigh == 1) {
        ++native_compat_reads;
        return true;
    }
    ++native_compat_errors;
    runtime->enabled.store(false);
    fallback(Fallback::compatibility);
    return false;
}

inline bool inspect_overlapped(LPOVERLAPPED operation, IoSampleData& sample) noexcept {
    __try {
        sample.offset = operation->Offset; sample.offset_high = operation->OffsetHigh;
        sample.internal = operation->Internal;
        sample.event_nonnull = operation->hEvent != nullptr;
        sample.event_lowbit = (reinterpret_cast<ULONG_PTR>(operation->hEvent) & 1u) != 0;
        return true;
    } __except(EXCEPTION_EXECUTE_HANDLER) { return false; }
}
inline bool writable_overlapped(LPOVERLAPPED operation) noexcept {
    if ((reinterpret_cast<uintptr_t>(operation) % alignof(OVERLAPPED)) != 0) return false;
    MEMORY_BASIC_INFORMATION information{};
    if (VirtualQuery(operation, &information, sizeof(information)) != sizeof(information) || information.State != MEM_COMMIT ||
        (information.Protect & (PAGE_GUARD | PAGE_NOACCESS))) return false;
    const DWORD protection = information.Protect & 0xff;
    if (protection != PAGE_READWRITE && protection != PAGE_WRITECOPY && protection != PAGE_EXECUTE_READWRITE && protection != PAGE_EXECUTE_WRITECOPY) return false;
    const auto begin = reinterpret_cast<uintptr_t>(operation), region = reinterpret_cast<uintptr_t>(information.BaseAddress);
    return begin >= region && sizeof(OVERLAPPED) <= information.RegionSize && begin - region <= information.RegionSize - sizeof(OVERLAPPED);
}
inline bool complete_overlapped(LPOVERLAPPED operation, DWORD amount) noexcept {
    if (!operation) return true;
    __try {
        operation->InternalHigh = amount;
        MemoryBarrier();
        operation->Internal = 0; // STATUS_SUCCESS, after bytes and byte-count.
        return true;
    } __except(EXCEPTION_EXECUTE_HANDLER) { return false; }
}
inline void capture_io_sample(HANDLE handle, LPVOID buffer, DWORD length, LPDWORD count, LPOVERLAPPED operation) noexcept {
    if (io_sample_claimed.load(std::memory_order_relaxed) >= io_samples.size()) return;
    const auto index = io_sample_claimed.fetch_add(1, std::memory_order_relaxed);
    if (index >= io_samples.size()) return;
    IoSampleData sample{};
    sample.length = length; sample.overlap = operation != nullptr;
    sample.count_missing = count == nullptr; sample.buffer_missing = buffer == nullptr;
    if (operation) sample.overlap_readable = inspect_overlapped(operation, sample);
    try {
        if (query_information && GetFileType(handle) == FILE_TYPE_DISK) {
            IO_STATUS_BLOCK status{};
            sample.mode_valid = query_information(handle, &status, &sample.mode, sizeof(sample.mode), static_cast<FILE_INFORMATION_CLASS>(16)) >= 0;
            sample.access_valid = query_information(handle, &status, &sample.access, sizeof(sample.access), static_cast<FILE_INFORMATION_CLASS>(8)) >= 0;
            const auto path = lowercase(final_path(handle));
            sample.pak_under_root = path.size() > root_prefix.size() && path.compare(0, root_prefix.size(), root_prefix) == 0 &&
                path.size() >= 4 && path.substr(path.size() - 4) == L".pak";
        }
    } catch (...) { /* Diagnostics never change the native fallback decision. */ }
    io_samples[index].data = sample;
    io_samples[index].ready.store(true, std::memory_order_release);
}

// A duplicate is a stable reference to the SAME native file object and cursor.
// A foreign DLL may close/reuse the caller's numeric HANDLE while DS waits;
// position updates must never be applied to a newly reused, different handle.
struct HandleLease {
    HANDLE value{};
    explicit HandleLease(HANDLE original, bool acquire) {
        if (acquire) DuplicateHandle(GetCurrentProcess(), original, GetCurrentProcess(), &value, 0, FALSE, DUPLICATE_SAME_ACCESS);
    }
    ~HandleLease() { if (value) { const auto error = GetLastError(); native_close(value); SetLastError(error); } }
};

inline std::shared_ptr<HandleState> state_for(HANDLE handle, bool create) {
    std::scoped_lock lock{handles_mutex};
    const auto found = handles.find(handle);
    if (found != handles.end()) return found->second;
    if (!create || handles.size() >= 4096) return {};
    auto state = std::make_shared<HandleState>();
    handles.emplace(handle, state);
    return state;
}
inline bool refresh_group(HANDLE handle, HandleState& state) {
    BY_HANDLE_FILE_INFORMATION identity{};
    if (GetFileType(handle) != FILE_TYPE_DISK || !GetFileInformationByHandle(handle, &identity)) {
        state.eligible = false; state.source.reset(); state.file_mutex.reset(); return false;
    }
    if (!same_file(identity, state.identity)) { state.eligible = false; state.source.reset(); }
    state.identity = identity;
    state.file_mutex = runtime->file_group(identity);
    return state.file_mutex != nullptr;
}
inline void examine(HANDLE handle, HandleState& state) {
    // Revalidate every read: cached HANDLE numbers can be reused after a close
    // performed by another module, outside the game's patched import table.
    state.examined = true; state.eligible = false; state.source.reset(); state.rejected = Fallback::metadata;
    // Caller has refreshed the identity and locked its shared file group using
    // a stable native-handle lease before inspecting this access/mode/path.
    if (!state.file_mutex || !query_information) return;
    IO_STATUS_BLOCK io{};
    ULONG mode{}, access{};
    if (query_information(handle, &io, &mode, sizeof(mode), static_cast<FILE_INFORMATION_CLASS>(16)) < 0 ||
        query_information(handle, &io, &access, sizeof(access), static_cast<FILE_INFORMATION_CLASS>(8)) < 0) return;
    // Unbuffered handles have additional sector/buffer alignment contracts;
    // leave them native instead of silently accepting an invalid native read.
    // Alertable synchronous I/O has APC/cancellation behavior which this wait
    // does not reproduce. Support only proven non-alertable synchronous reads.
    if (!(mode & 0x20u) || (mode & (0x10u | 0x1000u | 0x8u))) { state.rejected = Fallback::mode; return; }
    constexpr ACCESS_MASK forbidden = FILE_WRITE_DATA | FILE_APPEND_DATA | FILE_WRITE_EA | FILE_WRITE_ATTRIBUTES |
        DELETE | WRITE_DAC | WRITE_OWNER | GENERIC_WRITE | GENERIC_ALL;
    if (!(access & FILE_READ_DATA) || (access & forbidden)) { state.rejected = Fallback::access; return; }
    const auto path = final_path(handle);
    const auto normalized = lowercase(path);
    if (normalized.size() <= root_prefix.size() || normalized.compare(0, root_prefix.size(), root_prefix) != 0 ||
        normalized.size() < 4 || normalized.substr(normalized.size() - 4) != L".pak" ||
        (normalized.size() > 6 && normalized.find(L':', 6) != std::wstring::npos)) {
        state.rejected = Fallback::path; return;
    }
    state.source = runtime->open(path, state.identity);
    if (!state.source) { state.rejected = Fallback::identity; return; }
    state.eligible = true;
}

inline BOOL WINAPI hook_read(HANDLE handle, LPVOID buffer, DWORD length, LPDWORD count, LPOVERLAPPED overlapped) noexcept {
    const DWORD incoming_error = GetLastError();
    // Unsupported explicit EOF/special offsets are delegated before leases,
    // metadata, position queries or caller-output writes of any kind.
    if (overlapped) {
        IoSampleData explicit_operation{};
        LARGE_INTEGER file_size{};
        if (inspect_overlapped(overlapped, explicit_operation)) {
            const auto offset = (static_cast<uint64_t>(explicit_operation.offset_high) << 32) | explicit_operation.offset;
            if ((offset & (UINT64_C(1) << 63)) || (GetFileSizeEx(handle, &file_size) && file_size.QuadPart >= 0 && offset >= static_cast<uint64_t>(file_size.QuadPart))) {
                ++overlap_nonnull; fallback(Fallback::position);
                SetLastError(incoming_error);
                return native_read(handle, buffer, length, count, overlapped);
            }
        }
    }
    std::shared_ptr<HandleState> state;
    std::unique_lock<std::mutex> lock;
    std::unique_lock<std::mutex> file_lock;
    HandleLease lease{handle, installed.load() && runtime && runtime->enabled.load() && buffer && count};
    HANDLE native_handle = handle;
    try {
        capture_io_sample(handle, buffer, length, count, overlapped);
        if (overlapped) ++overlap_nonnull;
        if (!count) ++count_null;
        if (!buffer) ++buffer_null;
        // Every read on a tracked handle participates, including a small read
        // that falls back to Windows. Otherwise it could advance the native
        // pointer while another thread is reading the same offset through DS.
        state = state_for(handle, installed.load() && runtime && runtime->enabled.load());
        if (state) lock = std::unique_lock<std::mutex>{state->mutex};
        const HANDLE inspected_handle = lease.value ? lease.value : handle;
        if (state && runtime && refresh_group(inspected_handle, *state) && state->file_mutex)
            file_lock = std::unique_lock<std::mutex>{*state->file_mutex};
        if (!installed.load() || !runtime->enabled.load()) fallback(Fallback::disabled);
        else if (!buffer || !count) fallback(Fallback::overlapped);
        else if (length < minimum_read || length > maximum_read) fallback(Fallback::size);
        else if (state) {
            IoSampleData operation{};
            const bool valid_operation = !overlapped || (inspect_overlapped(overlapped, operation) && !operation.event_nonnull && writable_overlapped(overlapped));
            if (!valid_operation) { fallback(Fallback::overlapped); }
            else {
            examine(inspected_handle, *state);
            // A stable lease is mandatory for DS; if duplication failed, let
            // Windows validate the original handle through its normal path.
            if (!lease.value) state->eligible = false;
            if (!state->eligible) fallback(state->rejected);
            else {
                native_handle = lease.value;
                LARGE_INTEGER zero{}, position{}, original_position{}, size{};
                bool have_position = true;
                // An explicit OVERLAPPED offset does not need the game cursor.
                // Leave unsupported EOF/special-offset cases completely native
                // before even issuing a position query on the file object.
                if (!overlapped) have_position = native_seek_ex(native_handle, zero, &original_position, FILE_CURRENT) != FALSE;
                position = original_position;
                if (overlapped) position.QuadPart = static_cast<int64_t>((static_cast<uint64_t>(operation.offset_high) << 32) | operation.offset);
                if (!have_position || !GetFileSizeEx(native_handle, &size) ||
                    position.QuadPart < 0 || position.QuadPart >= size.QuadPart) { native_handle = handle; fallback(Fallback::position); }
                else {
                    if (overlapped && !native_seek_ex(native_handle, zero, &original_position, FILE_CURRENT)) {
                        fallback(Fallback::position);
                    } else {
                    const auto available = static_cast<uint64_t>(size.QuadPart - position.QuadPart);
                    const auto amount = static_cast<DWORD>(std::min<uint64_t>(length, available));
                    if (const auto job = runtime->read(state->source, static_cast<uint64_t>(position.QuadPart), amount)) {
                        LARGE_INTEGER next{}; next.QuadPart = position.QuadPart + amount;
                        if (runtime->verify(job, state->identity, static_cast<uint64_t>(position.QuadPart)) &&
                            update_native_read_bookkeeping(native_handle, static_cast<uint64_t>(next.QuadPart - 1), job->data.back()) &&
                            safe_copy(buffer, job->data.data(), amount, count) &&
                            complete_overlapped(overlapped, amount)) {
                            ++reads; bytes += amount;
                            if (file_lock.owns_lock()) file_lock.unlock();
                            lock.unlock();
                            SetLastError(incoming_error);
                            return TRUE;
                        }
                        // If a caller concurrently invalidated output storage,
                        // restore the original native cursor before fallback.
                        native_seek_ex(native_handle, original_position, nullptr, FILE_BEGIN);
                        if (runtime->enabled.load()) fallback(Fallback::copy);
                    }
                    }
                }
            }
            }
        } else fallback(Fallback::allocation);
    } catch (...) { fallback(Fallback::allocation); }
    // Keep this handle locked through native fallback, so pointer/close hooks
    // cannot interleave with an already-started eligible synchronous read.
    SetLastError(incoming_error);
    const BOOL result = native_read(native_handle, buffer, length, count, overlapped);
    const DWORD native_error = GetLastError();
    if (file_lock.owns_lock()) file_lock.unlock();
    if (lock.owns_lock()) lock.unlock();
    SetLastError(native_error);
    return result;
}
inline DWORD WINAPI hook_seek(HANDLE handle, LONG distance, PLONG high, DWORD method) noexcept {
    const auto incoming = GetLastError();
    DWORD result{}, error{};
    try {
        auto state = state_for(handle, installed.load() && runtime && runtime->enabled.load());
        std::unique_lock<std::mutex> lock;
        if (state) lock = std::unique_lock<std::mutex>{state->mutex};
        HandleLease lease{handle, state != nullptr};
        const auto target = lease.value ? lease.value : handle;
        std::unique_lock<std::mutex> file_lock;
        if (state && runtime && refresh_group(target, *state) && state->file_mutex) file_lock = std::unique_lock<std::mutex>{*state->file_mutex};
        SetLastError(incoming); result = native_seek(target, distance, high, method); error = GetLastError();
    } catch (...) { SetLastError(incoming); result = native_seek(handle, distance, high, method); error = GetLastError(); }
    SetLastError(error); return result;
}
inline BOOL WINAPI hook_seek_ex(HANDLE handle, LARGE_INTEGER distance, PLARGE_INTEGER next, DWORD method) noexcept {
    const auto incoming = GetLastError();
    BOOL result{}; DWORD error{};
    try {
        auto state = state_for(handle, installed.load() && runtime && runtime->enabled.load());
        std::unique_lock<std::mutex> lock;
        if (state) lock = std::unique_lock<std::mutex>{state->mutex};
        HandleLease lease{handle, state != nullptr};
        const auto target = lease.value ? lease.value : handle;
        std::unique_lock<std::mutex> file_lock;
        if (state && runtime && refresh_group(target, *state) && state->file_mutex) file_lock = std::unique_lock<std::mutex>{*state->file_mutex};
        SetLastError(incoming); result = native_seek_ex(target, distance, next, method); error = GetLastError();
    } catch (...) { SetLastError(incoming); result = native_seek_ex(handle, distance, next, method); error = GetLastError(); }
    SetLastError(error); return result;
}
inline BOOL WINAPI hook_close(HANDLE handle) noexcept {
    const auto incoming = GetLastError();
    BOOL result{}; DWORD error{};
    try {
        auto state = state_for(handle, false);
        std::unique_lock<std::mutex> lock;
        if (state) lock = std::unique_lock<std::mutex>{state->mutex};
        std::unique_lock<std::mutex> file_lock;
        if (state && runtime && refresh_group(handle, *state) && state->file_mutex) file_lock = std::unique_lock<std::mutex>{*state->file_mutex};
        SetLastError(incoming); result = native_close(handle); error = GetLastError();
        if (result && state) {
            std::scoped_lock map_lock{handles_mutex};
            const auto found = handles.find(handle);
            if (found != handles.end() && found->second == state) handles.erase(found);
        }
    } catch (...) { SetLastError(incoming); result = native_close(handle); error = GetLastError(); }
    SetLastError(error); return result;
}

struct Slot { void** address{}; void* original{}; void* hook{}; };
inline std::vector<Slot> slots;
inline bool replace(const Slot& slot, void* expected, void* desired) {
    DWORD protection{};
    if (!VirtualProtect(slot.address, sizeof(void*), PAGE_READWRITE, &protection)) return false;
    const bool success = InterlockedCompareExchangePointer(slot.address, desired, expected) == expected;
    DWORD ignored{};
    const bool restored = VirtualProtect(slot.address, sizeof(void*), protection, &ignored) != FALSE;
    return success && restored;
}
inline bool install_iat() {
    const auto kernel = GetModuleHandleW(L"kernel32.dll"), base_kernel = GetModuleHandleW(L"kernelbase.dll");
    struct Target { const char* name; void* original; void* alternative; void* hook; size_t count{}; };
    std::array<Target, 4> targets{{
        {"ReadFile", reinterpret_cast<void*>(native_read), reinterpret_cast<void*>(GetProcAddress(base_kernel, "ReadFile")), reinterpret_cast<void*>(&hook_read)},
        {"SetFilePointer", reinterpret_cast<void*>(native_seek), reinterpret_cast<void*>(GetProcAddress(base_kernel, "SetFilePointer")), reinterpret_cast<void*>(&hook_seek)},
        {"SetFilePointerEx", reinterpret_cast<void*>(native_seek_ex), reinterpret_cast<void*>(GetProcAddress(base_kernel, "SetFilePointerEx")), reinterpret_cast<void*>(&hook_seek_ex)},
        {"CloseHandle", reinterpret_cast<void*>(native_close), reinterpret_cast<void*>(GetProcAddress(base_kernel, "CloseHandle")), reinterpret_cast<void*>(&hook_close)}
    }};
    if (!kernel || !base_kernel) return false;
    auto image = reinterpret_cast<uint8_t*>(GetModuleHandleW(nullptr));
    const auto dos = reinterpret_cast<IMAGE_DOS_HEADER*>(image);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return false;
    const auto nt = reinterpret_cast<IMAGE_NT_HEADERS64*>(image + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE || nt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC) return false;
    const auto imports = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
    if (!imports.VirtualAddress || !imports.Size) return false;
    const auto descriptors = reinterpret_cast<IMAGE_IMPORT_DESCRIPTOR*>(image + imports.VirtualAddress);
    std::vector<Slot> proposed;
    for (auto descriptor = descriptors; descriptor->Name; ++descriptor) {
        std::string module = reinterpret_cast<char*>(image + descriptor->Name);
        std::transform(module.begin(), module.end(), module.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        const bool approved = module == "kernel32.dll" || module == "kernelbase.dll" || module.starts_with("api-ms-win-core-file-") || module.starts_with("api-ms-win-core-handle-");
        if (!approved) continue;
        if (!descriptor->OriginalFirstThunk) return false;
        auto names = reinterpret_cast<IMAGE_THUNK_DATA64*>(image + descriptor->OriginalFirstThunk);
        auto addresses = reinterpret_cast<IMAGE_THUNK_DATA64*>(image + descriptor->FirstThunk);
        for (; names->u1.AddressOfData; ++names, ++addresses) {
            if (IMAGE_SNAP_BY_ORDINAL64(names->u1.Ordinal)) continue;
            const auto name = reinterpret_cast<IMAGE_IMPORT_BY_NAME*>(image + names->u1.AddressOfData)->Name;
            for (auto& target : targets) if (std::strcmp(reinterpret_cast<const char*>(name), target.name) == 0) {
                const auto current = reinterpret_cast<void*>(addresses->u1.Function);
                if (current != target.original && current != target.alternative) return false;
                proposed.push_back({reinterpret_cast<void**>(&addresses->u1.Function), current, target.hook});
                ++target.count;
            }
        }
    }
    if (!targets[0].count || !targets[3].count || (!targets[1].count && !targets[2].count) ||
        std::any_of(targets.begin(), targets.end(), [](const auto& target) { return !target.original; })) return false;
    size_t completed = 0;
    for (const auto& slot : proposed) {
        const bool forced_failure =
            #ifdef RE8_DS_TESTING
            test_mode.load() == 2 && completed == 2;
            #else
            false;
            #endif
        if (forced_failure || !replace(slot, slot.original, slot.hook)) {
            // Include the failed slot: its CAS may have succeeded before a
            // protection-restore failure. Never overwrite another writer.
            for (size_t index = 0; index <= completed; ++index) replace(proposed[index], proposed[index].hook, proposed[index].original);
            return false;
        }
        ++completed;
    }
    slots = std::move(proposed);
    installed.store(true);
    return true;
}
} // namespace re8_ds
