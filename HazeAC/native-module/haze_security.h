#ifndef HAZE_SECURITY_H
#define HAZE_SECURITY_H

#ifndef _WIN64
#error HazeSecurity richiede una build x64
#endif

#include <windows.h>
#include <cstdint>
#include <mutex>
#include <string>
#include <unordered_map>

namespace HazeSecurity {

    enum class DetectionType {
        None = 0,
        RemoteDebugger = 1,
        InlineHook = 2,
        UnsignedModule = 3,
        ThreadInjection = 4,
        ProcessHandleViolation = 5
    };

    struct SecurityState {
        bool isClean = true;
        DetectionType lastDetection = DetectionType::None;
        std::string detectedProcess;
        std::string detectedDLL;
        std::string detectedTitle;
        std::string detail;
        uint64_t detectionTime = 0;
    };

    class SecurityScanner {
    public:
        SecurityScanner();
        ~SecurityScanner() = default;

        SecurityState performFullScan();
        SecurityState getState();
        void resetState();

    private:
        bool scanModules(SecurityState& out);
        bool checkDebugger(SecurityState& out);
        bool checkInlineHooks(SecurityState& out);
        bool checkThreadInjection(SecurityState& out);
        bool checkProcessHandles(SecurityState& out);

        bool isTrustedPath(const std::wstring& lowerPath) const;
        bool isFileSigned(const std::wstring& path);

        std::mutex scanMutex;
        std::mutex stateMutex;
        SecurityState state;

        std::wstring systemDir;
        std::wstring windowsDir;
        std::wstring hostDir;
        std::wstring ownPath;
        std::unordered_map<std::wstring, bool> signCache;
    };

    extern "C" {
        __declspec(dllexport) void InitializeScanner();
        __declspec(dllexport) bool PerformScan();
        __declspec(dllexport) int GetDetectionType();
        __declspec(dllexport) const char* GetDetectedProcess();
        __declspec(dllexport) const char* GetDetectedDLL();
        __declspec(dllexport) const char* GetDetectedTitle();
        __declspec(dllexport) const char* GetDetectedDetail();
        __declspec(dllexport) uint64_t GetDetectionTime();
        __declspec(dllexport) void ResetScanner();
        __declspec(dllexport) void CleanupScanner();
    }
}

#endif
