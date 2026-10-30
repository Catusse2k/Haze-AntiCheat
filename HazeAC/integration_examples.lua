RegisterNetEvent('myResource:doSomething')
AddEventHandler('myResource:doSomething', function(token, data)
    local source = source
    if not source or source <= 0 then return end

    if exports.haze_ac and exports.haze_ac:validateToken then
        if not exports.haze_ac:validateToken(source, 'myResource:doSomething', token) then
            print('[myResource] Invalid token from ' .. GetPlayerName(source))
            return
        end
    end

    print('[myResource] Valid event from ' .. GetPlayerName(source))
end)

local function triggerProtectedEvent(eventName, ...)
    if exports.haze_ac and exports.haze_ac:getToken then
        local token = exports.haze_ac:getToken(eventName)
        TriggerServerEvent(eventName, token, ...)
    else
        TriggerServerEvent(eventName, ...)
    end
end

if GetResourceState('qb-core') == 'started' then
    local QBCore = exports['qb-core']:GetCoreObject()

    local originalCallback = QBCore.Functions.CreateCallback
    QBCore.Functions.CreateCallback = function(name, cb)
        originalCallback(name, function(source, cb, ...)
            if exports.haze_ac and exports.haze_ac:validateToken then
            end
            cb(...)
        end)
    end
end

RegisterNetEvent('ox_inventory:useItem', function(data)
    local source = source
end)

local customRateLimits = {
    ['myResource:fastAction'] = {limit = 5, window = 1000},
    ['myResource:slowAction'] = {limit = 10, window = 60000}
}

local customRateLog = {}

local function checkCustomRateLimit(playerId, eventName)
    local config = customRateLimits[eventName]
    if not config then return true end

    local key = string.format('%s_%s', playerId, eventName)
    if not customRateLog[key] then
        customRateLog[key] = {count = 0, lastReset = GetGameTimer()}
    end

    local log = customRateLog[key]
    local now = GetGameTimer()

    if now - log.lastReset > config.window then
        log.count = 0
        log.lastReset = now
    end

    log.count = log.count + 1
    if log.count > config.limit then
        print('[RateLimit] ' .. eventName .. ' exceeded by ' .. GetPlayerName(playerId))
        return false
    end

    return true
end

RegisterCommand('admin_giveitem', function(source, args, rawCommand)
    if source ~= 0 then
        if not IsPlayerAceAllowed(source, 'admin') then
            print('[Security] Unauthorized command attempt by ' .. GetPlayerName(source))
            return
        end

        if exports.haze_ac and exports.haze_ac:hasStrike then
            local strikes = exports.haze_ac:getPlayerStrikes(source)
            if strikes and strikes > 2 then
                print('[Security] Command blocked - player has strikes: ' .. GetPlayerName(source))
                return
            end
        end
    end
end)

local function validateInput(data, schema)
    if type(data) ~= 'table' then return false end

    for key, validator in pairs(schema) do
        local value = data[key]
        if validator.type and type(value) ~= validator.type then
            return false
        end
        if validator.min and value < validator.min then
            return false
        end
        if validator.max and value > validator.max then
            return false
        end
        if validator.pattern and not string.match(tostring(value), validator.pattern) then
            return false
        end
    end

    return true
end

local trustedResources = {
    ['qb-core'] = true,
    ['ox_inventory'] = true,
    ['haze_ac'] = true,
    ['myResource'] = true
}

AddEventHandler('onResourceStarting', function(resourceName)
    if not trustedResources[resourceName] then
        print('[Security] Untrusted resource starting: ' .. resourceName)
    end
end)

local function logSuspiciousActivity(playerId, eventType, details)
    local logEntry = {
        timestamp = os.time(),
        playerId = playerId,
        playerName = GetPlayerName(playerId),
        license = GetPlayerIdentifier(playerId, 0),
        eventType = eventType,
        details = details
    }

    local file = io.open(GetResourcePath(GetCurrentResourceName()) .. '/suspicious_log.json', 'a')
    if file then
        file:write(json.encode(logEntry) .. '\n')
        file:close()
    end

    print('[Suspicious] ' .. logEntry.playerName .. ' - ' .. eventType)
end

local originalCreateVehicle = CreateVehicle
function CreateVehicle(model, x, y, z, heading, isNetwork, thisScriptCheck)
    local source = source

    if source and source > 0 then
        if not IsPlayerAceAllowed(source, 'vehicle.spawn') then
            print('[Security] Unauthorized vehicle spawn by ' .. GetPlayerName(source))
            return 0
        end

        if not checkCustomRateLimit(source, 'vehicle_spawn') then
            print('[Security] Vehicle spawn rate limit exceeded')
            return 0
        end
    end

    return originalCreateVehicle(model, x, y, z, heading, isNetwork, thisScriptCheck)
end

local function sendDiscordAlert(playerId, reason, severity)
    local webhook = 'YOUR_DISCORD_WEBHOOK_URL'
    if webhook == 'YOUR_DISCORD_WEBHOOK_URL' then return end

    local data = {
        username = 'HazeAC Alert',
        embeds = {{
            title = 'Anti-Cheat Alert',
            color = severity == 'high' and 16711680 or 16776960,
            fields = {
                {name = 'Player', value = GetPlayerName(playerId) or 'Unknown'},
                {name = 'License', value = GetPlayerIdentifier(playerId, 0) or 'Unknown'},
                {name = 'Reason', value = reason},
                {name = 'Severity', value = severity}
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }

    PerformHttpRequest(webhook, function(err, text, headers)
        if err ~= 200 then
            print('[Discord] Failed to send alert: ' .. err)
        end
    end, 'POST', json.encode(data), {'Content-Type: application/json'})
end
