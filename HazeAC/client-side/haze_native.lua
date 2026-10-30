local nativeModule = nil
local scanInterval = 5000
local lastScanTime = 0
local scanEnabled = true

local function loadNativeModule()
    nativeModule = LoadResourceFile(GetCurrentResourceName(), 'native-module/haze_security.dll')

    if not nativeModule or nativeModule == '' then
        print('[HazeAC Native] ERROR: Failed to load haze_security.dll')
        return false
    end

    print('[HazeAC Native] Loaded security module')
    return true
end

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    if loadNativeModule() then
        print('[HazeAC Native] Security scanner initialized')
    end
end)

local function performSecurityScan()
    if not scanEnabled then return end

    local isWhitelisted = IsPlayerAceAllowed(PlayerId(), 'haze_ac.bypass')
    if isWhitelisted then
        return true
    end

    local isClean = true
    local detectionType = 0
    local detectedProcess = ""
    local detectedDLL = ""
    local detectedTitle = ""
    local detectedDetail = ""
    local detectionTime = 0

    if nativeModule and nativeModule ~= '' then
        local result = Citizen.InvokeNative("PerformScan")
        if result == 0 then
            isClean = false
            detectionType = Citizen.InvokeNative("GetDetectionType")
            detectedProcess = Citizen.InvokeNative("GetDetectedProcess") or ""
            detectedDLL = Citizen.InvokeNative("GetDetectedDLL") or ""
            detectedTitle = Citizen.InvokeNative("GetDetectedTitle") or ""
            detectedDetail = Citizen.InvokeNative("GetDetectedDetail") or ""
            detectionTime = Citizen.InvokeNative("GetDetectionTime") or 0
        end
    end

    if not isClean then
        local token = exports.haze_ac and exports.haze_ac:getToken and exports.haze_ac:getToken('haze_ac:native_scan')

        if token then
            TriggerServerEvent('haze_ac:nativeDetection', token, {
                detectionType = detectionType,
                detectedProcess = detectedProcess,
                detectedDLL = detectedDLL,
                detectedTitle = detectedTitle,
                detectedDetail = detectedDetail,
                detectionTime = detectionTime
            })
        else
            TriggerServerEvent('haze_ac:nativeDetection', nil, {
                detectionType = detectionType,
                detectedProcess = detectedProcess,
                detectedDLL = detectedDLL,
                detectedTitle = detectedTitle,
                detectedDetail = detectedDetail,
                detectionTime = detectionTime
            })
        end
    end

    return isClean
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(scanInterval)
        
        if scanEnabled then
            local now = GetGameTimer()
            if now - lastScanTime >= scanInterval then
                performSecurityScan()
                lastScanTime = now
            end
        end
    end
end)

RegisterNetEvent('haze_ac:triggerNativeScan')
AddEventHandler('haze_ac:triggerNativeScan', function()
    performSecurityScan()
end)

RegisterNetEvent('haze_ac:setNativeScanEnabled')
AddEventHandler('haze_ac:setNativeScanEnabled', function(enabled)
    scanEnabled = enabled
    print('[HazeAC Native] Scan ' .. (enabled and 'enabled' or 'disabled'))
end)

RegisterNetEvent('haze_ac:getNativeStatus')
AddEventHandler('haze_ac:getNativeStatus', function()
    local status = {
        loaded = (nativeModule ~= nil),
        scanEnabled = scanEnabled,
        lastScanTime = lastScanTime
    }
    TriggerServerEvent('haze_ac:nativeStatus', status)
end)

print('[HazeAC Native] Client-side native integration loaded')
