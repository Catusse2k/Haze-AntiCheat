#include "haze_security.h"

#include <tlhelp32.h>
#include <psapi.h>
#include <softpub.h>
#include <wintrust.h>
#include <ntstatus.h>
#include <winternl.h>

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <memory>
#include <string>
#include <unordered_set>
#include <vector>

#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "wintrust.lib")

typedef NTSTATUS(NTAPI* pNtQuerySystemInformation)(
    ULONG SystemInformationClass,
    PVOID SystemInformation,
    ULONG SystemInformationLength,
    PULONG ReturnLength
);

typedef struct _SYSTEM_HANDLE_TABLE_ENTRY_INFO {
    USHORT ProcessId;
    USHORT CreatorBackTraceIndex;
    UCHAR ObjectTypeNumber;
    UCHAR HandleAttributes;
    USHORT HandleValue;
    PVOID Object;
    ULONG GrantedAccess;
} SYSTEM_HANDLE_TABLE_ENTRY_INFO, *PSYSTEM_HANDLE_TABLE_ENTRY_INFO;

typedef struct _SYSTEM_HANDLE_INFORMATION {
    ULONG NumberOfHandles;
    SYSTEM_HANDLE_TABLE_ENTRY_INFO Handles[1];
} SYSTEM_HANDLE_INFORMATION, *PSYSTEM_HANDLE_INFORMATION;

namespace HazeSecurity {

    static void moduleAnchor() {}

    static std::wstring toLower(std::wstring s) {
        std::transform(s.begin(), s.end(), s.begin(),
                       [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
        return s;
    }

    static std::string narrow(const std::wstring& w) {
        if (w.empty()) return {};
        int n = WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()), nullptr, 0, nullptr, nullptr);
        if (n <= 0) return {};
        std::string out(static_cast<size_t>(n), '\0');
        WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()), &out[0], n, nullptr, nullptr);
        return out;
    }

    static std::wstring fileNameOf(const std::wstring& path) {
        size_t p = path.find_last_of(L"\\/");
        return p == std::wstring::npos ? path : path.substr(p + 1);
    }

    static std::wstring dirOf(const std::wstring& path) {
        size_t p = path.find_last_of(L"\\/");
        return p == std::wstring::npos ? std::wstring() : path.substr(0, p);
    }

    static bool startsWith(const std::wstring& s, const std::wstring& prefix) {
        return !prefix.empty() && s.size() >= prefix.size() && s.compare(0, prefix.size(), prefix) == 0;
    }



    struct HookTarget {
        const wchar_t* dll;
        bool strict;
        std::vector<const char*> funcs;
    };

    static const std::vector<HookTarget> HOOK_TARGETS = {
        { L"ntdll.dll", true, {
            "NtReadVirtualMemory", "NtWriteVirtualMemory", "NtProtectVirtualMemory",
            "NtAllocateVirtualMemory", "NtCreateThreadEx", "NtQueryVirtualMemory",
            "NtOpenProcess", "NtSetInformationThread", "NtQuerySystemInformation",
            "LdrLoadDll" } },
        { L"kernel32.dll", false, {
            "LoadLibraryW", "LoadLibraryA", "LoadLibraryExW", "CreateRemoteThread",
            "WriteProcessMemory", "VirtualProtect" } },
        { L"kernelbase.dll", false, {
            "LoadLibraryExW", "VirtualProtect", "GetProcAddress" } }
    };

    static const size_t HOOK_CMP_BYTES = 12;

    struct ViewGuard {
        const void* ptr;
        explicit ViewGuard(const void* p) : ptr(p) {}
        ~ViewGuard() { if (ptr) UnmapViewOfFile(ptr); }
        ViewGuard(const ViewGuard&) = delete;
        ViewGuard& operator=(const ViewGuard&) = delete;
    };

    static bool bytesDiffer(const BYTE* a, const BYTE* b, size_t n, bool& differ) {
        __try {
            differ = std::memcmp(a, b, n) != 0;
            return true;
        } __except (EXCEPTION_EXECUTE_HANDLER) {
            return false;
        }
    }

    static const BYTE* resolveJumpTarget(const BYTE* fn) {
        __try {
            if (fn[0] == 0xE9) {
                int32_t rel = *reinterpret_cast<const int32_t*>(fn + 1);
                return fn + 5 + rel;
            }
            if (fn[0] == 0xFF && fn[1] == 0x25) {
                int32_t rel = *reinterpret_cast<const int32_t*>(fn + 2);
                return *reinterpret_cast<const BYTE* const*>(fn + 6 + rel);
            }
            if (fn[0] == 0x48 && fn[1] == 0xB8 && fn[10] == 0xFF && fn[11] == 0xE0) {
                return *reinterpret_cast<const BYTE* const*>(fn + 2);
            }
        } __except (EXCEPTION_EXECUTE_HANDLER) {
        }
        return nullptr;
    }

    SecurityScanner::SecurityScanner() {
        wchar_t buf[MAX_PATH];

        if (GetSystemDirectoryW(buf, MAX_PATH)) systemDir = toLower(buf);
        if (GetWindowsDirectoryW(buf, MAX_PATH)) windowsDir = toLower(buf);
        if (GetModuleFileNameW(nullptr, buf, MAX_PATH)) hostDir = toLower(dirOf(buf));

        HMODULE self = nullptr;
        if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                               GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                               reinterpret_cast<LPCWSTR>(&moduleAnchor), &self) && self) {
            if (GetModuleFileNameW(self, buf, MAX_PATH)) ownPath = toLower(buf);
        }
    }

    bool SecurityScanner::isTrustedPath(const std::wstring& lowerPath) const {
        auto under = [&](const std::wstring& dir) {
            return !dir.empty() && startsWith(lowerPath, dir + L"\\");
        };
        return (!ownPath.empty() && lowerPath == ownPath) ||
               under(systemDir) || under(windowsDir) || under(hostDir);
    }

    bool SecurityScanner::isFileSigned(const std::wstring& path) {
        auto it = signCache.find(path);
        if (it != signCache.end()) return it->second;

        WINTRUST_FILE_INFO fileInfo = {};
        fileInfo.cbStruct = sizeof(fileInfo);
        fileInfo.pcwszFilePath = path.c_str();

        GUID policy = WINTRUST_ACTION_GENERIC_VERIFY_V2;
        WINTRUST_DATA data = {};
        data.cbStruct = sizeof(data);
        data.dwUIChoice = WTD_UI_NONE;
        data.fdwRevocationChecks = WTD_REVOKE_NONE;
        data.dwUnionChoice = WTD_CHOICE_FILE;
        data.pFile = &fileInfo;
        data.dwStateAction = WTD_STATEACTION_VERIFY;
        data.dwProvFlags = WTD_CACHE_ONLY_URL_RETRIEVAL;

        HWND noWindow = static_cast<HWND>(INVALID_HANDLE_VALUE);
        LONG status = WinVerifyTrust(noWindow, &policy, &data);
        bool ok = (status == ERROR_SUCCESS);

        data.dwStateAction = WTD_STATEACTION_CLOSE;
        WinVerifyTrust(noWindow, &policy, &data);

        signCache[path] = ok;
        return ok;
    }

    bool SecurityScanner::scanModules(SecurityState& out) {
        HANDLE proc = GetCurrentProcess();
        std::vector<HMODULE> mods(1024);
        DWORD needed = 0;

        if (!EnumProcessModules(proc, mods.data(), static_cast<DWORD>(mods.size() * sizeof(HMODULE)), &needed))
            return true;

        if (needed > mods.size() * sizeof(HMODULE)) {
            mods.resize(needed / sizeof(HMODULE));
            if (!EnumProcessModules(proc, mods.data(), static_cast<DWORD>(mods.size() * sizeof(HMODULE)), &needed))
                return true;
        }

        size_t count = std::min<size_t>(needed / sizeof(HMODULE), mods.size());

        for (size_t i = 0; i < count; i++) {
            wchar_t path[MAX_PATH] = {};
            if (!GetModuleFileNameExW(proc, mods[i], path, MAX_PATH)) continue;

            std::wstring lowerPath = toLower(path);
            std::wstring name = fileNameOf(lowerPath);

            if (!isTrustedPath(lowerPath) && !isFileSigned(path)) {
                out.lastDetection = DetectionType::UnsignedModule;
                out.detectedDLL = narrow(name);
                out.detail = "Modulo non firmato fuori da cartelle fidate: " + narrow(lowerPath);
                return false;
            }
        }
        return true;
    }

    bool SecurityScanner::checkDebugger(SecurityState& out) {
        BOOL remote = FALSE;
        CheckRemoteDebuggerPresent(GetCurrentProcess(), &remote);
        if (remote || IsDebuggerPresent()) {
            out.lastDetection = DetectionType::RemoteDebugger;
            out.detail = "Debugger collegato al processo";
            return false;
        }
        return true;
    }

    bool SecurityScanner::checkInlineHooks(SecurityState& out) {
        wchar_t sysDir[MAX_PATH] = {};
        if (!GetSystemDirectoryW(sysDir, MAX_PATH)) return true;

        for (const auto& target : HOOK_TARGETS) {
            HMODULE live = GetModuleHandleW(target.dll);
            if (!live) continue;

            MODULEINFO mi = {};
            if (!GetModuleInformation(GetCurrentProcess(), live, &mi, sizeof(mi))) continue;

            std::wstring diskPath = std::wstring(sysDir) + L"\\" + target.dll;
            HANDLE file = CreateFileW(diskPath.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE,
                                      nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
            if (file == INVALID_HANDLE_VALUE) continue;

            HANDLE mapping = CreateFileMappingW(file, nullptr, PAGE_READONLY | SEC_IMAGE, 0, 0, nullptr);
            CloseHandle(file);
            if (!mapping) continue;

            const BYTE* cleanBase = static_cast<const BYTE*>(MapViewOfFile(mapping, FILE_MAP_READ, 0, 0, 0));
            CloseHandle(mapping);
            if (!cleanBase) continue;
            ViewGuard guard(cleanBase);

            const BYTE* liveBase = static_cast<const BYTE*>(mi.lpBaseOfDll);

            for (const char* fnName : target.funcs) {
                const BYTE* liveFn = reinterpret_cast<const BYTE*>(GetProcAddress(live, fnName));
                if (!liveFn) continue;
                if (liveFn < liveBase || liveFn + HOOK_CMP_BYTES > liveBase + mi.SizeOfImage) continue;

                const BYTE* cleanFn = cleanBase + (liveFn - liveBase);

                bool differ = false;
                if (!bytesDiffer(liveFn, cleanFn, HOOK_CMP_BYTES, differ) || !differ) continue;

                const BYTE* dest = resolveJumpTarget(liveFn);
                if (!dest && !target.strict) continue;

                std::string who = "memoria privata";
                bool benign = false;

                if (dest) {
                    HMODULE owner = nullptr;
                    if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                                           GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                                           reinterpret_cast<LPCWSTR>(dest), &owner) && owner) {
                        wchar_t ownerPath[MAX_PATH] = {};
                        if (GetModuleFileNameW(owner, ownerPath, MAX_PATH)) {
                            std::wstring lp = toLower(ownerPath);
                            who = narrow(fileNameOf(lp));
                            benign = startsWith(lp, systemDir + L"\\") ||
                                     startsWith(lp, windowsDir + L"\\") ||
                                     isFileSigned(ownerPath);
                        }
                    }
                } else {
                    who = "destinazione non risolta";
                }

                if (benign) continue;

                out.lastDetection = DetectionType::InlineHook;
                out.detectedDLL = who;
                out.detail = narrow(target.dll) + "!" + fnName + " hookata -> " + who;
                return false;
            }
        }
        return true;
    }

    typedef LONG(NTAPI* NtQueryInformationThread_t)(HANDLE, ULONG, PVOID, ULONG, PULONG);

    bool SecurityScanner::checkThreadInjection(SecurityState& out) {
        HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
        if (!ntdll) return true;

        auto queryThread = reinterpret_cast<NtQueryInformationThread_t>(
            GetProcAddress(ntdll, "NtQueryInformationThread"));
        if (!queryThread) return true;

        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
        if (snap == INVALID_HANDLE_VALUE) return true;

        const DWORD pid = GetCurrentProcessId();
        const DWORD selfTid = GetCurrentThreadId();
        const ULONG threadQueryWin32StartAddress = 9;

        THREADENTRY32 te = {};
        te.dwSize = sizeof(te);
        bool clean = true;

        if (Thread32First(snap, &te)) {
            do {
                if (te.th32OwnerProcessID != pid || te.th32ThreadID == selfTid) continue;

                HANDLE th = OpenThread(THREAD_QUERY_INFORMATION, FALSE, te.th32ThreadID);
                if (!th) continue;

                PVOID startAddr = nullptr;
                LONG status = queryThread(th, threadQueryWin32StartAddress, &startAddr, sizeof(startAddr), nullptr);
                CloseHandle(th);

                if (status != 0 || !startAddr) continue;

                HMODULE owner = nullptr;
                BOOL inModule = GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                                                   GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                                                   reinterpret_cast<LPCWSTR>(startAddr), &owner);
                if (!inModule) {
                    char msg[128];
                    std::snprintf(msg, sizeof(msg), "Thread %lu con start address fuori da moduli: %p",
                                  static_cast<unsigned long>(te.th32ThreadID), startAddr);
                    out.lastDetection = DetectionType::ThreadInjection;
                    out.detail = msg;
                    clean = false;
                    break;
                }
            } while (Thread32Next(snap, &te));
        }

        CloseHandle(snap);
        return clean;
    }

    bool SecurityScanner::checkProcessHandles(SecurityState& out) {
        HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
        if (!ntdll) return true;

        auto NtQuerySystemInformation = reinterpret_cast<pNtQuerySystemInformation>(
            GetProcAddress(ntdll, "NtQuerySystemInformation"));
        if (!NtQuerySystemInformation) return true;

        const DWORD currentPid = GetCurrentProcessId();
        ULONG size = 0x10000;
        std::vector<BYTE> buffer(size);

        NTSTATUS status = NtQuerySystemInformation(16, buffer.data(), size, &size);
        if (status == STATUS_INFO_LENGTH_MISMATCH) {
            buffer.resize(size);
            status = NtQuerySystemInformation(16, buffer.data(), size, &size);
        }
        if (status != 0) return true;

        auto* handleInfo = reinterpret_cast<PSYSTEM_HANDLE_INFORMATION>(buffer.data());
        if (!handleInfo) return true;

        const DWORD dangerousAccess = PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_ALL_ACCESS;

        for (ULONG i = 0; i < handleInfo->NumberOfHandles; i++) {
            auto& entry = handleInfo->Handles[i];
            if (entry.ProcessId != currentPid) continue;

            if (entry.GrantedAccess & dangerousAccess) {
                HANDLE procSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
                if (procSnap == INVALID_HANDLE_VALUE) continue;

                PROCESSENTRY32W pe = {};
                pe.dwSize = sizeof(pe);
                bool found = false;
                std::wstring attackerName;

                if (Process32FirstW(procSnap, &pe)) {
                    do {
                        if (pe.th32ProcessID == entry.ProcessId) {
                            attackerName = toLower(pe.szExeFile);
                            found = true;
                            break;
                        }
                    } while (Process32NextW(procSnap, &pe));
                }
                CloseHandle(procSnap);

                if (found) {
                    static const std::vector<std::wstring> safeProcesses = {
                        L"svchost.exe", L"csrss.exe", L"lsass.exe", L"wininit.exe",
                        L"services.exe", L"dwm.exe", L"explorer.exe", L"runtimebroker.exe",
                        L"audiodg.exe", L"system", L"smss.exe"
                    };

                    bool isSafe = false;
                    for (const auto& safe : safeProcesses) {
                        if (attackerName == safe) {
                            isSafe = true;
                            break;
                        }
                    }

                    if (!isSafe) {
                        char msg[512];
                        std::snprintf(msg, sizeof(msg), "Process handle pericoloso da %s (PID %lu, Access: 0x%08X)",
                                      narrow(attackerName).c_str(), static_cast<unsigned long>(entry.ProcessId),
                                      static_cast<unsigned int>(entry.GrantedAccess));
                        out.lastDetection = DetectionType::ProcessHandleViolation;
                        out.detectedProcess = narrow(attackerName);
                        out.detail = msg;
                        return false;
                    }
                }
            }
        }

        return true;
    }

    SecurityState SecurityScanner::performFullScan() {
        std::lock_guard<std::mutex> scanLock(scanMutex);

        SecurityState result;
        result.detectionTime = GetTickCount64();

        result.isClean = scanModules(result)
                      && checkDebugger(result)
                      && checkInlineHooks(result)
                      && checkThreadInjection(result)
                      && checkProcessHandles(result);

        {
            std::lock_guard<std::mutex> lock(stateMutex);
            state = result;
        }
        return result;
    }

    SecurityState SecurityScanner::getState() {
        std::lock_guard<std::mutex> lock(stateMutex);
        return state;
    }

    void SecurityScanner::resetState() {
        std::lock_guard<std::mutex> lock(stateMutex);
        state = SecurityState{};
    }

    static std::mutex g_mutex;
    static std::shared_ptr<SecurityScanner> g_scanner;

    static std::shared_ptr<SecurityScanner> acquire(bool create) {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (!g_scanner && create) g_scanner = std::make_shared<SecurityScanner>();
        return g_scanner;
    }

    static const char* copyTo(char* buffer, size_t size, const std::string& value) {
        strncpy_s(buffer, size, value.c_str(), _TRUNCATE);
        return buffer;
    }

    extern "C" {

        __declspec(dllexport) void InitializeScanner() {
            acquire(true);
        }

        __declspec(dllexport) bool PerformScan() {
            auto scanner = acquire(true);
            return scanner->performFullScan().isClean;
        }

        __declspec(dllexport) int GetDetectionType() {
            auto scanner = acquire(false);
            if (!scanner) return -1;
            return static_cast<int>(scanner->getState().lastDetection);
        }

        __declspec(dllexport) const char* GetDetectedProcess() {
            static thread_local char buffer[512];
            buffer[0] = '\0';
            auto scanner = acquire(false);
            if (!scanner) return buffer;
            return copyTo(buffer, sizeof(buffer), scanner->getState().detectedProcess);
        }

        __declspec(dllexport) const char* GetDetectedDLL() {
            static thread_local char buffer[512];
            buffer[0] = '\0';
            auto scanner = acquire(false);
            if (!scanner) return buffer;
            return copyTo(buffer, sizeof(buffer), scanner->getState().detectedDLL);
        }

        __declspec(dllexport) const char* GetDetectedTitle() {
            static thread_local char buffer[512];
            buffer[0] = '\0';
            auto scanner = acquire(false);
            if (!scanner) return buffer;
            return copyTo(buffer, sizeof(buffer), scanner->getState().detectedTitle);
        }

        __declspec(dllexport) const char* GetDetectedDetail() {
            static thread_local char buffer[1024];
            buffer[0] = '\0';
            auto scanner = acquire(false);
            if (!scanner) return buffer;
            return copyTo(buffer, sizeof(buffer), scanner->getState().detail);
        }

        __declspec(dllexport) uint64_t GetDetectionTime() {
            auto scanner = acquire(false);
            if (!scanner) return 0;
            return scanner->getState().detectionTime;
        }

        __declspec(dllexport) void ResetScanner() {
            auto scanner = acquire(false);
            if (scanner) scanner->resetState();
        }

        __declspec(dllexport) void CleanupScanner() {
            std::lock_guard<std::mutex> lock(g_mutex);
            g_scanner.reset();
        }
    }

}
