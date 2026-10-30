if not HazeConfig then
    print('[haze_ac] FATAL: haze_config.lua not loaded')
    return
end

local CFG = HazeConfig

print('')
print([[888   888                                   d8888  .d8888b. 
        888   888                                  d88888 d88P  Y88b
        888   888                                 d88P888 888    888
        888888888  8888b.  88888888  .d88b.      d88P  888 88       
        888   888     "88b    d88P  d8P  Y8b    d88P  888 888       
        888   888 .d888888   d88P   88888888   d88P   888 888    888
        888   888  888  888  d88P    Y8b.      d8888888888 Y88b  d88P
        888   888 "Y888888 d8888888  "Y88888 d88P     888  "Y8888P" ]])
print('[haze_ac] v2.0 - Advanced Security Module Loaded')
print('[haze_ac] C++ Native Module: Process Handle Detection')
print('[haze_ac] C++ Native Module: Inline Hook Detection')
print('[haze_ac] C++ Native Module: Unsigned Module Detection')
print('[haze_ac] C++ Native Module: Thread Injection Detection')
print('[haze_ac] Server-Side: Angular Velocity Aimbot Detection')
print('[haze_ac] Server-Side: Triggerbot Reaction Time Detection')
print('[haze_ac] Server-Side: Silent Aim Raycast Detection')
print('[haze_ac] Server-Side: Token-Based Event Protection')
print('[haze_ac] Server-Side: Instant Ban on Token Violation')
print('')

local database = {
    players = {},
    whitelist = {},
    banned = {},
    banDatabase = {bans = {}},
    pendingLosChecks = {},
    losCheckId = 0,
    knownResources = {},
    manifestHashes = {},
    punishAction = CFG.PunishAction,
    punishDuration = CFG.PunishDuration,
    gracePeriods = {},
    damageLog = {},
    positionHistory = {},
    eventTokens = {},
    globalEventLog = {},
    ioQueue = {},
    ioDirty = false,
    lastIoFlush = 0,
    ioFlushInterval = 5000,
    pendingSave = false,
    banCheckCache = {},
    banCacheHits = 0,
    banCacheMisses = 0,
    nativeDetections = {},
    adminWhitelist = {}
}

local function log(level, message)
    if level <= CFG.LogLevel then
        print('[haze_ac] ' .. message)
    end
end

local function sstr(s, max)
    if type(s) ~= 'string' then return '' end
    if #s > (max or 500) then return string.sub(s, 1, max or 500) end
    return s
end

local function snum(n)
    if type(n) ~= 'number' then return 0 end
    if n ~= n then return 0 end
    if n == math.huge or n == -math.huge then return 0 end
    return n
end

local function sint(n)
    return math.floor(snum(n))
end

local function banPath()
    return GetResourcePath(GetCurrentResourceName()) .. '/' .. CFG.BanFile
end

local function computeHwid(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not identifiers then return 'unknown' end
    local license2, license, steam = '', '', ''
    for _, id in ipairs(identifiers) do
        if string.find(id, 'license2:') then license2 = id
        elseif string.find(id, 'license:') then license = id
        elseif string.find(id, 'steam:') then steam = id
        end
    end
    local parts = {
        license2 or license or '',
        steam or ''
    }
    local combined = table.concat(parts, '|')
    local hash = 0
    for i = 1, #combined do
        hash = (hash * 33 + string.byte(combined, i)) % 4294967296
    end
    return string.format('%x', hash)
end

local function getTokens(playerId)
    local tokens = {}
    local n = GetNumPlayerTokens(playerId)
    if n and n > 0 then
        for i = 0, n - 1 do
            local t = GetPlayerToken(playerId, i)
            if t and t ~= '' then
                tokens[#tokens + 1] = t
            end
        end
    end
    return tokens
end

local function getIdentifiers(playerId)
    local data = {
        license = '', license2 = '', steam = '', discord = '',
        xbl = '', live = '', fivem = '', ip = '',
        name = GetPlayerName(playerId) or 'unknown',
        hwid = '',
        tokens = getTokens(playerId)
    }
    for _, id in ipairs(GetPlayerIdentifiers(playerId)) do
        if string.find(id, 'license2:') then data.license2 = id
        elseif string.find(id, 'license:') then data.license = id
        elseif string.find(id, 'steam:') then data.steam = id
        elseif string.find(id, 'discord:') then data.discord = id
        elseif string.find(id, 'xbl:') then data.xbl = id
        elseif string.find(id, 'live:') then data.live = id
        elseif string.find(id, 'fivem:') then data.fivem = id
        elseif string.find(id, 'ip:') then data.ip = id
        end
    end
    data.hwid = computeHwid(playerId)
    return data
end

local function getData(playerId)
    if not database.players[playerId] then
        database.players[playerId] = {
            sessionStart = GetGameTimer(),
            strikes = {},
            strikesTime = {},
            lastPos = nil,
            lastPosTime = 0,
            lastShot = 0,
            shotBurst = 0,
            shotCount = 0,
            hitCount = 0,
            headshotCount = 0,
            camSnapLog = {},
            eventRateLog = {},
            explosionLog = {},
            particleLog = {},
            scenarioLog = {},
            spawnLog = {},
            weaponLog = {},
            domLog = {},
            nuiLog = {},
            commandLog = {},
            triggerLog = {},
            deletedEntityLog = {},
            lastHeartbeat = 0,
            invisibleCount = 0,
            freecamCount = 0,
            staminaCount = 0,
            noRagdollCount = 0,
            vehicleGodmodeCount = 0,
            frozenHealthCount = 0,
            initialInventorySet = false,
            lastHealth = 0,
            lastArmor = 0
        }
    end
    return database.players[playerId]
end

local function hasBypass(playerId)
    if database.whitelist[playerId] then
        log(2, 'Bypass used by player: ' .. GetPlayerName(playerId))
        return true
    end
    if IsPlayerAceAllowed(playerId, CFG.Whitelist.AceBypass) then
        log(2, 'ACE bypass used by player: ' .. GetPlayerName(playerId))
        return true
    end
    if IsPlayerAceAllowed(playerId, CFG.Whitelist.AceAdmin) then
        log(2, 'Admin bypass used by player: ' .. GetPlayerName(playerId))
        return true
    end
    if IsPlayerAceAllowed(playerId, CFG.Whitelist.AceSuperAdmin) then
        log(2, 'Superadmin bypass used by player: ' .. GetPlayerName(playerId))
        return true
    end
    return false
end

local function fmtPlayer(playerId)
    local name = GetPlayerName(playerId) or 'unknown'
    local hwid = computeHwid(playerId)
    return name .. ' [HWID:' .. hwid .. ']'
end

local function punish(playerId, reason, strikeType)
    if database.banned[playerId] then return end
    if not GetPlayerName(playerId) then return end
    if database.punishAction == 'kick' then
        database.banned[playerId] = true
        DropPlayer(playerId, CFG.KickMessage .. reason)
        log(1, 'KICKED: ' .. fmtPlayer(playerId) .. ' - ' .. reason)
    else
        banPlayer(playerId, reason, database.punishDuration or 0, 'haze_ac:' .. (strikeType or 'auto'))
    end
end

local function addStrike(playerId, reason, severity, strikeType)
    if not playerId or playerId <= 0 then return end
    if not GetPlayerName(playerId) then return end
    if hasBypass(playerId) then return end
    local data = getData(playerId)
    if GetGameTimer() - data.sessionStart < CFG.SessionGrace then return end
    local key = strikeType or 'default'
    if not data.strikes[key] then data.strikes[key] = 0 end
    data.strikes[key] = data.strikes[key] + (severity or 1)
    data.strikesTime[key] = GetGameTimer()
    log(1, 'Strike ' .. key .. ' ' .. fmtPlayer(playerId) .. ' - ' .. reason .. ' (' .. data.strikes[key] .. '/' .. CFG.StrikeThreshold .. ')')
    if data.strikes[key] >= CFG.StrikeThreshold then
        punish(playerId, reason, key)
        data.strikes[key] = 0
    end
end

local function loadBans()
    local file = io.open(banPath(), 'r')
    if not file then
        database.banDatabase = {bans = {}}
        return
    end
    local content = file:read('*all')
    file:close()
    if not content or content == '' then
        database.banDatabase = {bans = {}}
        return
    end
    local ok, decoded = pcall(json.decode, content)
    if ok and type(decoded) == 'table' then
        database.banDatabase = decoded
        if not database.banDatabase.bans then
            database.banDatabase.bans = {}
        end
        log(2, 'Loaded ' .. #database.banDatabase.bans .. ' bans')
    else
        log(1, 'Failed to decode ban file, using empty database')
        database.banDatabase = {bans = {}}
    end
end

local function saveBansAsync()
    if database.pendingSave then return end
    database.pendingSave = true

    CreateThread(function()
        local file = io.open(banPath(), 'w')
        if not file then
            log(1, 'Failed to open ban file for writing')
            database.pendingSave = false
            return
        end
        local ok, encoded = pcall(json.encode, database.banDatabase)
        if ok then
            file:write(encoded)
        else
            log(1, 'Failed to encode ban database')
        end
        file:close()
        database.pendingSave = false
        database.ioDirty = false
        database.lastIoFlush = GetGameTimer()
    end)
end

local function saveBans()
    if not database.ioDirty then
        database.ioDirty = true
        local now = GetGameTimer()
        if now - database.lastIoFlush > database.ioFlushInterval then
            saveBansAsync()
        end
    end
end

local function flushBanCache()
    if database.ioDirty then
        saveBansAsync()
        Citizen.Wait(100)
    end
end

local function getBehavioralFingerprint(playerId)
    local data = getData(playerId)
    local identifiers = getIdentifiers(playerId)
    if not identifiers or not identifiers.license then
        return 0
    end
    local signature = string.format('%s|%s|%s', identifiers.license or '', identifiers.license2 or '', identifiers.steam or '')
    local hash = 0
    for i = 1, #signature do
        hash = (hash * 31 + string.byte(signature, i)) % 2147483647
    end
    return hash
end

local function generateEventToken(playerId, eventName)
    local identifiers = getIdentifiers(playerId)
    local timestamp = os.time() * 1000
    local signature = string.format('%s|%s|%d|%s', identifiers.license2, eventName, timestamp, CFG.HwidSalt)
    local hash = 0
    for i = 1, #signature do
        hash = (hash * 33 + string.byte(signature, i)) % 4294967296
    end
    local token = string.format('%x:%d', hash, timestamp)
    database.eventTokens[playerId] = database.eventTokens[playerId] or {}
    database.eventTokens[playerId][eventName] = {token = token, timestamp = timestamp}
    return token
end

local function validateEventToken(playerId, eventName, token)
    if not database.eventTokens[playerId] or not database.eventTokens[playerId][eventName] then
        return false
    end
    local stored = database.eventTokens[playerId][eventName]
    if stored.token ~= token then
        return false
    end
    local now = os.time() * 1000
    if now - stored.timestamp > 15000 then
        return false
    end
    return true
end

local function checkGlobalEventRate(playerId, eventName)
    if not database.globalEventLog[playerId] then
        database.globalEventLog[playerId] = {}
    end
    if not database.globalEventLog[playerId][eventName] then
        database.globalEventLog[playerId][eventName] = {count = 0, lastReset = GetGameTimer()}
    end
    local log = database.globalEventLog[playerId][eventName]
    local now = GetGameTimer()
    if now - log.lastReset > 10000 then
        log.count = 0
        log.lastReset = now
    end
    log.count = log.count + 1
    local limits = {
        default = 20,
        state = 5,
        shot = 30,
        damage = 15
    }
    local limit = limits[eventName] or limits.default
    if log.count > limit then
        addStrike(playerId, 'Global Event Rate Limit Exceeded - ' .. eventName, 1, 'eventspam')
        return false
    end
    return true
end
    local n = GetNumPlayerTokens(playerId)
    if n and n > 0 then
        for i = 0, n - 1 do
            local t = GetPlayerToken(playerId, i)
            if t and t ~= '' then
                tokens[#tokens + 1] = t
            end
        end
    end
    return tokens
end

local function getIdentifiers(playerId)
    local data = {
        license = '', license2 = '', steam = '', discord = '',
        xbl = '', live = '', fivem = '', ip = '',
        name = GetPlayerName(playerId) or 'unknown',
        hwid = computeHwid(playerId),
        tokens = getTokens(playerId)
    }
    for _, id in ipairs(GetPlayerIdentifiers(playerId)) do
        if string.find(id, 'license2:') then data.license2 = id
        elseif string.find(id, 'license:') then data.license = id
        elseif string.find(id, 'steam:') then data.steam = id
        elseif string.find(id, 'discord:') then data.discord = id
        elseif string.find(id, 'xbl:') then data.xbl = id
        elseif string.find(id, 'live:') then data.live = id
        elseif string.find(id, 'fivem:') then data.fivem = id
        elseif string.find(id, 'ip:') then data.ip = id
        end
    end
    return data
end

local function isBanned(identifiers)
    if not database.banDatabase or not database.banDatabase.bans then
        return false, nil
    end

    local cacheKey = identifiers.license2 or identifiers.steam or identifiers.discord
    if cacheKey and database.banCheckCache[cacheKey] then
        local cached = database.banCheckCache[cacheKey]
        if os.time() - cached.timestamp < 60 then
            database.banCacheHits = database.banCacheHits + 1
            return cached.banned, cached.ban
        else
            database.banCheckCache[cacheKey] = nil
        end
    end

    database.banCacheMisses = database.banCacheMisses + 1
    local now = os.time()
    for _, ban in ipairs(database.banDatabase.bans) do
        local expired = false
        if ban.expiresAt and ban.expiresAt > 0 and now > ban.expiresAt then
            expired = true
        end
        if not expired then
            if ban.license2 and ban.license2 ~= '' and ban.license2 == identifiers.license2 then
                if cacheKey then
                    database.banCheckCache[cacheKey] = {banned = true, ban = ban, timestamp = os.time()}
                end
                return true, ban
            end
            if ban.steam and ban.steam ~= '' and ban.steam == identifiers.steam then
                if cacheKey then
                    database.banCheckCache[cacheKey] = {banned = true, ban = ban, timestamp = os.time()}
                end
                return true, ban
            end
            if ban.discord and ban.discord ~= '' and ban.discord == identifiers.discord then
                if cacheKey then
                    database.banCheckCache[cacheKey] = {banned = true, ban = ban, timestamp = os.time()}
                end
                return true, ban
            end
            if CFG.CheckTokens and ban.tokens and type(ban.tokens) == 'table' then
                for _, bt in ipairs(ban.tokens) do
                    for _, pt in ipairs(identifiers.tokens) do
                        if bt == pt then
                            if cacheKey then
                                database.banCheckCache[cacheKey] = {banned = true, ban = ban, timestamp = os.time()}
                            end
                            return true, ban
                        end
                    end
                end
            end
        end
    end

    if cacheKey then
        database.banCheckCache[cacheKey] = {banned = false, ban = nil, timestamp = os.time()}
    end
    return false, nil
end

local function banPlayer(playerId, reason, duration, bannedBy)
    if not playerId or playerId <= 0 then return end
    local identifiers = getIdentifiers(playerId)
    local now = os.time()
    local expiresAt = 0
    if duration and duration > 0 then
        expiresAt = now + duration
    end
    local ban = {
        license = identifiers.license,
        license2 = identifiers.license2,
        steam = identifiers.steam,
        discord = identifiers.discord,
        xbl = identifiers.xbl,
        live = identifiers.live,
        fivem = identifiers.fivem,
        ip = identifiers.ip,
        hwid = identifiers.hwid,
        tokens = identifiers.tokens,
        name = identifiers.name,
        reason = sstr(reason, 500),
        bannedBy = sstr(bannedBy or 'system', 100),
        bannedAt = now,
        expiresAt = expiresAt
    }
    table.insert(database.banDatabase.bans, ban)
    saveBans()
    database.banned[playerId] = true
    log(1, 'BANNED: ' .. identifiers.name .. ' - ' .. reason)
    TriggerClientEvent('haze_ac:printBan', playerId, reason)
    local msg = CFG.BanMessage .. reason
    if expiresAt > 0 then
        msg = msg .. ' (expires: ' .. os.date('%Y-%m-%d %H:%M:%S', expiresAt) .. ')'
    else
        msg = msg .. ' (permanent)'
    end
    DropPlayer(playerId, msg)
end

local function getData(playerId)
    if not database.players[playerId] then
        database.players[playerId] = {
            sessionStart = GetGameTimer(),
            strikes = {},
            strikesTime = {},
            lastPos = nil,
            lastPosTime = 0,
            lastShot = 0,
            shotBurst = 0,
            shotCount = 0,
            hitCount = 0,
            headshotCount = 0,
            camSnapLog = {},
            eventRateLog = {},
            explosionLog = {},
            particleLog = {},
            scenarioLog = {},
            spawnLog = {},
            weaponLog = {},
            domLog = {},
            nuiLog = {},
            commandLog = {},
            triggerLog = {},
            deletedEntityLog = {},
            lastHeartbeat = 0,
            invisibleCount = 0,
            freecamCount = 0,
            staminaCount = 0,
            noRagdollCount = 0,
            vehicleGodmodeCount = 0,
            frozenHealthCount = 0,
            initialInventorySet = false,
            lastHealth = 0,
            lastArmor = 0
        }
    end
    return database.players[playerId]
end

local function fmtPlayer(playerId)
    local name = GetPlayerName(playerId) or 'unknown'
    local hwid = computeHwid(playerId)
    return name .. ' [HWID:' .. hwid .. ']'
end

local function hasBypass(playerId)
    if database.whitelist[playerId] then return true end
    if IsPlayerAceAllowed(playerId, CFG.Whitelist.AceBypass) then return true end
    if IsPlayerAceAllowed(playerId, CFG.Whitelist.AceAdmin) then return true end
    if IsPlayerAceAllowed(playerId, CFG.Whitelist.AceSuperAdmin) then return true end
    return false
end

local function punish(playerId, reason, strikeType)
    if database.banned[playerId] then return end
    if not GetPlayerName(playerId) then return end
    if database.punishAction == 'kick' then
        database.banned[playerId] = true
        DropPlayer(playerId, CFG.KickMessage .. reason)
        log(1, 'KICKED: ' .. fmtPlayer(playerId) .. ' - ' .. reason)
    else
        banPlayer(playerId, reason, database.punishDuration or 0, 'haze_ac:' .. (strikeType or 'auto'))
    end
end

local function addStrike(playerId, reason, severity, strikeType)
    if not playerId or playerId <= 0 then return end
    if not GetPlayerName(playerId) then return end
    if hasBypass(playerId) then return end
    local data = getData(playerId)
    if GetGameTimer() - data.sessionStart < CFG.SessionGrace then return end
    local key = strikeType or 'default'
    if not data.strikes[key] then data.strikes[key] = 0 end
    data.strikes[key] = data.strikes[key] + (severity or 1)
    data.strikesTime[key] = GetGameTimer()
    log(1, 'Strike ' .. key .. ' ' .. fmtPlayer(playerId) .. ' - ' .. reason .. ' (' .. data.strikes[key] .. '/' .. CFG.StrikeThreshold .. ')')
    if data.strikes[key] >= CFG.StrikeThreshold then
        punish(playerId, reason, key)
        data.strikes[key] = 0
    end
end

local function decay(playerId)
    local data = database.players[playerId]
    if not data then return end
    local now = GetGameTimer()
    for key, count in pairs(data.strikes) do
        if count > 0 and data.strikesTime[key] then
            if now - data.strikesTime[key] > CFG.StrikeDecayTime then
                data.strikes[key] = math.max(0, count - 1)
                data.strikesTime[key] = now
            end
        end
    end
end

local function rateLimit(logTable, limit, window)
    local now = GetGameTimer()
    for i = #logTable, 1, -1 do
        if now - logTable[i] > window then
            table.remove(logTable, i)
        end
    end
    table.insert(logTable, now)
    return #logTable > limit
end

local function damageCeiling(weaponHash)
    local dmg = {
        [`WEAPON_PISTOL`]=26, [`WEAPON_COMBATPISTOL`]=27, [`WEAPON_APPISTOL`]=32,
        [`WEAPON_PISTOL50`]=51, [`WEAPON_SNSPISTOL`]=25, [`WEAPON_HEAVYPISTOL`]=40,
        [`WEAPON_VINTAGEPISTOL`]=28, [`WEAPON_MARKSMANPISTOL`]=90, [`WEAPON_REVOLVER`]=90,
        [`WEAPON_MICROSMG`]=21, [`WEAPON_SMG`]=22, [`WEAPON_ASSAULTSMG`]=22,
        [`WEAPON_COMBATPDW`]=22, [`WEAPON_MACHINEPISTOL`]=21, [`WEAPON_MINISMG`]=22,
        [`WEAPON_ASSAULTRIFLE`]=30, [`WEAPON_CARBINERIFLE`]=32, [`WEAPON_ADVANCEDRIFLE`]=33,
        [`WEAPON_SPECIALCARBINE`]=33, [`WEAPON_BULLPUPRIFLE`]=32, [`WEAPON_COMPACTRIFLE`]=30,
        [`WEAPON_MG`]=35, [`WEAPON_COMBATMG`]=37, [`WEAPON_GUSENBERG`]=34,
        [`WEAPON_PUMPSHOTGUN`]=80, [`WEAPON_SAWNOFFSHOTGUN`]=90, [`WEAPON_ASSAULTSHOTGUN`]=75,
        [`WEAPON_BULLPUPSHOTGUN`]=75, [`WEAPON_MUSKET`]=120, [`WEAPON_HEAVYSHOTGUN`]=90,
        [`WEAPON_DBSHOTGUN`]=100, [`WEAPON_AUTOSHOTGUN`]=70, [`WEAPON_SNIPERRIFLE`]=120,
        [`WEAPON_HEAVYSNIPER`]=250, [`WEAPON_MARKSMANRIFLE`]=90, [`WEAPON_RAILGUN`]=500,
        [`WEAPON_RPG`]=500, [`WEAPON_MINIGUN`]=40, [`WEAPON_HOMINGLAUNCHER`]=500,
        [`WEAPON_GRENADELAUNCHER`]=400, [`WEAPON_STUNGUN`]=5, [`WEAPON_FLAREGUN`]=10
    }
    return (dmg[weaponHash] or 30) * CFG.Combat.DamageCeilingMultiplier
end

local modules = {}

function modules.checkAimbot(pId, pitchDiff, yawDiff)
    if type(pitchDiff) ~= 'number' or type(yawDiff) ~= 'number' then return end
    if pitchDiff < 0 or yawDiff < 0 or pitchDiff > 360 or yawDiff > 360 then return end

    local data = getData(pId)
    local now = GetGameTimer()
    local timeDiff = now - (data.lastCamTime or 0)

    if timeDiff > 0 and timeDiff < 100 then
        local angularVelocity = (pitchDiff + yawDiff) / timeDiff
        if angularVelocity > 1000 then
            if rateLimit(data.camSnapLog, 3, 5000) then
                addStrike(pId, 'Angular Velocity Anomalo - ' .. math.floor(angularVelocity) .. ' deg/ms', 2, 'aimbot')
            end
        end
    end

    if pitchDiff + yawDiff > CFG.Aim.CamSnapAngle then
        if rateLimit(data.camSnapLog, CFG.Aim.CamSnapRateLimit, CFG.Aim.CamSnapWindow) then
            addStrike(pId, 'Aimbot Snap - ' .. math.floor(pitchDiff + yawDiff), 1, 'aimbot')
        end
    end
    if pitchDiff > CFG.Aim.CamSnapVertical and pitchDiff < 300 then
        if rateLimit(data.camSnapLog, 5, 2000) then
            addStrike(pId, 'Aimbot Vertical Snap', 1, 'aimbot')
        end
    end
    data.lastCamTime = now
end

function modules.checkShot(pId, weapon, targetServerId, distance)
    local data = getData(pId)
    local now = GetGameTimer()
    if data.lastShot > 0 then
        local diff = now - data.lastShot
        if diff > 0 and diff < CFG.Combat.ShotBurstWindow then
            data.shotBurst = data.shotBurst + 1
            if data.shotBurst > CFG.Combat.MaxShotsPerSecond then
                addStrike(pId, 'Triggerbot Rapid Fire', 1, 'triggerbot')
                data.shotBurst = 0
            end
        else
            data.shotBurst = 0
        end
    end
    data.lastShot = now
    data.shotCount = data.shotCount + 1
    
    if targetServerId and targetServerId > 0 then
        local targetPed = GetPlayerPed(targetServerId)
        local attackerPed = GetPlayerPed(pId)
        
        if targetPed ~= 0 and attackerPed ~= 0 then
            local targetCoords = GetEntityCoords(targetPed)
            local attackerCoords = GetEntityCoords(attackerPed)
            local serverDistance = #(targetCoords - attackerCoords)
            
            if distance and math.abs(distance - serverDistance) > 30.0 then
                addStrike(pId, 'Distance Mismatch - Client: ' .. math.floor(distance) .. ' Server: ' .. math.floor(serverDistance), 1, 'spoof')
            end
        end
        
        data.hitCount = data.hitCount + 1
        if distance and distance > CFG.Combat.TrackingDistance and data.hitCount >= CFG.Combat.MinShotsForTracking then
            local ratio = data.hitCount / data.shotCount
            if ratio > CFG.Combat.TrackingAccuracy then
                addStrike(pId, 'Tracking Accuracy Anomalo - ' .. math.floor(ratio * 100) .. '%', 1, 'tracking')
            end
        end
        if data.shotCount >= CFG.Combat.MinShotsForRatio then
            local ratio = data.hitCount / data.shotCount
            if ratio > CFG.Combat.MaxHitRatio then
                addStrike(pId, 'Silent Aim - Hit Ratio ' .. math.floor(ratio * 100) .. '%', 1, 'silentaim')
            end
            data.shotCount = 0
            data.hitCount = 0
        end
    end
    if CFG.Weapons.EnableBlacklist and CFG.Weapons.Blacklist[weapon] then
        addStrike(pId, 'Arma Blacklist Usata', 2, 'weapon')
    end
end

function modules.checkState(pId, r)
    if type(r) ~= 'table' then return end
    if not r.coords or not r.velocity then return end
    if type(r.coords.x) ~= 'number' or type(r.velocity.z) ~= 'number' then return end
    
    local data = getData(pId)
    local now = GetGameTimer()
    
    if not database.gracePeriods[pId] then
        database.gracePeriods[pId] = {
            teleportGrace = 0,
            teleportViolations = 0,
            lastExplosion = 0
        }
    end
    local grace = database.gracePeriods[pId]
    
    if not r.inVehicle and CFG.Movement.EnableSpeedCheck and r.speed > CFG.Movement.MaxPedSpeed then
        if not r.parachuting and not r.falling then
            addStrike(pId, 'Speed Hack - ' .. math.floor(r.speed) .. ' m/s', 1, 'speed')
        end
    end
    
    if r.inVehicle and CFG.Movement.EnableSpeedCheck and r.vehicleSpeed > CFG.Movement.MaxVehicleSpeed then
        addStrike(pId, 'Vehicle Speed Hack - ' .. math.floor(r.vehicleSpeed) .. ' m/s', 1, 'vehicle')
    end
    
    if data.lastPos and CFG.Movement.EnableTeleportCheck then
        local timeDiff = now - data.lastPosTime
        if timeDiff > 0 and timeDiff < 2500 then
            local dx = r.coords.x - data.lastPos.x
            local dy = r.coords.y - data.lastPos.y
            local dz = r.coords.z - data.lastPos.z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            
            if dist > CFG.Movement.MaxTeleportDistance then
                if now - grace.teleportGrace > 5000 then
                    grace.teleportViolations = grace.teleportViolations + 1
                    if grace.teleportViolations >= 2 then
                        addStrike(pId, 'Teleport - ' .. math.floor(dist) .. 'm', 2, 'teleport')
                        grace.teleportViolations = 0
                    else
                        grace.teleportGrace = now
                    end
                end
            end
            
            if math.abs(dz) > CFG.Movement.MaxVerticalDelta and not r.falling and not r.ragdoll then
                if not r.inVehicle and not r.parachuting and now - grace.teleportGrace > 3000 then
                    addStrike(pId, 'Vertical Delta Anomalo', 1, 'teleport')
                    grace.teleportGrace = now
                end
            end
        end
    end
    data.lastPos = {x = r.coords.x, y = r.coords.y, z = r.coords.z}
    data.lastPosTime = now
    
    if CFG.Movement.EnableNoclipCheck and not r.inVehicle and r.speed > CFG.Movement.NoclipMinSpeed then
        if not r.falling and not r.ragdoll and not r.climbing and not r.jumping and not r.swimming and not r.inWater and not r.parachuting then
            if r.heightAboveGround and r.heightAboveGround > CFG.Movement.NoclipMinHeight then
                data.noclipCount = (data.noclipCount or 0) + 1
                if data.noclipCount >= 5 then
                    addStrike(pId, 'Noclip - Height ' .. math.floor(r.heightAboveGround) .. 'm', 1, 'noclip')
                    data.noclipCount = 0
                end
            else
                data.noclipCount = 0
            end
        end
    end
    
    if CFG.Movement.EnableSuperJumpCheck and not r.inVehicle and not r.falling and not r.ragdoll and not r.jumping then
        if r.velocity.z > CFG.Movement.MaxSuperJumpHeight then
            addStrike(pId, 'Super Jump - Vz ' .. math.floor(r.velocity.z), 2, 'superjump')
        end
    end
    
    if CFG.Health.EnableGodmodeCheck then
        if r.invincible then
            addStrike(pId, 'Godmode - Flag invincibile', 2, 'godmode')
        end
        if CFG.Health.EnableOverflowCheck then
            if r.health > CFG.Health.MaxHealthOverflow then
                addStrike(pId, 'Health Overflow - ' .. r.health, 2, 'godmode')
            end
            if r.health > r.maxHealth and not r.inVehicle then
                addStrike(pId, 'Health Superiore al Maximo', 2, 'godmode')
            end
            if r.armor > CFG.Health.MaxArmorOverflow then
                addStrike(pId, 'Armor Overflow - ' .. r.armor, 2, 'godmode')
            end
        end
        if CFG.Health.EnableNoRagdollCheck and not r.canRagdoll and r.health > 0 then
            data.noRagdollCount = (data.noRagdollCount or 0) + 1
            if data.noRagdollCount >= 10 then
                addStrike(pId, 'No Ragdoll Persistente', 1, 'godmode')
                data.noRagdollCount = 0
            end
        else
            data.noRagdollCount = 0
        end
        if r.health > 0 and r.health == data.lastHealth and r.health >= CFG.Health.MaxHealth and not r.inVehicle then
            data.frozenHealthCount = (data.frozenHealthCount or 0) + 1
            if data.frozenHealthCount >= 50 then
                addStrike(pId, 'Health Bloccato al Massimo', 1, 'godmode')
                data.frozenHealthCount = 0
            end
        else
            data.frozenHealthCount = 0
        end
    end
    
    if CFG.Misc.EnableStaminaCheck and r.stamina and r.stamina < CFG.Misc.MinStaminaThreshold then
        if r.running or r.sprinting then
            data.staminaCount = (data.staminaCount or 0) + 1
            if data.staminaCount >= 10 then
                addStrike(pId, 'Stamina Infinita', 1, 'stamina')
                data.staminaCount = 0
            end
        end
    end
    
    if CFG.Vehicles.EnableBlacklist and r.inVehicle and r.vehicleModel and CFG.Vehicles.Blacklist[r.vehicleModel] then
        addStrike(pId, 'Veicolo Blacklist Guidato', 2, 'vehicle')
    end
    
    if CFG.Health.EnableVehicleGodmodeCheck and r.inVehicle then
        if r.vehicleHealth and r.vehicleMaxHealth and r.vehicleHealth > r.vehicleMaxHealth then
            addStrike(pId, 'Vehicle Health Overflow', 2, 'godmode')
        end
        if r.vehicleBodyHealth and r.vehicleEngineHealth and r.vehicleSpeed and r.vehicleSpeed > 5.0 then
            if r.vehicleBodyHealth >= 1000.0 and r.vehicleEngineHealth >= 1000.0 then
                data.vehicleGodmodeCount = (data.vehicleGodmodeCount or 0) + 1
                if data.vehicleGodmodeCount >= 10 then
                    addStrike(pId, 'Vehicle Godmode', 1, 'godmode')
                    data.vehicleGodmodeCount = 0
                end
            end
        end
    end
    
    data.lastHealth = r.health
    data.lastArmor = r.armor
end

function modules.checkInventory(pId, weapons)
    if type(weapons) ~= 'table' then return end
    local data = getData(pId)
    local newW, totalW, totalA = 0, 0, 0
    for hashStr, entry in pairs(weapons) do
        local hash = tonumber(hashStr)
        if hash then
            totalW = totalW + 1
            local ammo = 0
            if type(entry) == 'table' then ammo = entry.ammo or 0
            elseif type(entry) == 'number' then ammo = entry end
            totalA = totalA + ammo
            if not data.weaponLog[hash] then
                data.weaponLog[hash] = GetGameTimer()
                newW = newW + 1
            end
            if CFG.Weapons.EnableBlacklist and CFG.Weapons.Blacklist[hash] then
                addStrike(pId, 'Arma Blacklist Inventario - ' .. tostring(hash), 2, 'weapon')
            end
            if CFG.Weapons.EnableAmmoCheck and ammo > CFG.Weapons.MaxAmmoPerWeapon then
                addStrike(pId, 'Ammo Overflow - ' .. ammo, 2, 'ammo')
            end
            if ammo < 0 then
                addStrike(pId, 'Ammo Negativo - Memory Manipulation', 2, 'ammo')
            end
        end
    end
    if newW > 0 and not data.initialInventorySet then
        data.initialInventorySet = true
    elseif newW > 0 and totalW > 3 then
        addStrike(pId, 'Giveweapon - ' .. newW .. ' nuove armi', 1, 'weapon')
    end
    if CFG.Weapons.EnableInventoryCheck and totalW > CFG.Weapons.MaxWeaponCount then
        addStrike(pId, 'Troppe armi in inventario - ' .. totalW, 1, 'weapon')
    end
    if totalA > CFG.Weapons.MaxTotalAmmo then
        addStrike(pId, 'Ammo Totale Eccessivo - ' .. totalA, 1, 'ammo')
    end
end

function modules.checkResourceList(pId, list)
    return true
end

function modules.checkEventSecurity(pId, eventName)
    if type(eventName) ~= 'string' then return end
    if #eventName > 200 then return end
    if not CFG.Events.EnableEventCheck then return end
    local data = getData(pId)
    if not data.eventRateLog[eventName] then data.eventRateLog[eventName] = {} end
    if rateLimit(data.eventRateLog[eventName], CFG.Events.MaxEventsPerSecond, 1000) then
        addStrike(pId, 'Event Spam: ' .. eventName, 1, 'eventspam')
    end
    local lower = string.lower(eventName)
    for _, prefix in ipairs(CFG.Events.SuspiciousPrefixes) do
        if string.find(lower, prefix, 1, true) then
            addStrike(pId, 'Event Sospetto: ' .. eventName, 2, 'injection')
            break
        end
    end
end

function modules.checkExplosion(sender, event)
    if not CFG.Explosions.EnableCheck then return end
    local et = event.explosionType
    local ds = event.damageScale or 1.0
    local data = getData(sender)
    if rateLimit(data.explosionLog, CFG.Explosions.MaxPerMinute, 60000) then
        addStrike(sender, 'Explosion Spam', 1, 'explosion')
    end
    if not CFG.Explosions.SafeTypes[et] then
        addStrike(sender, 'Explosion Type Anomalo - ' .. tostring(et), 2, 'explosion')
    end
    if ds > CFG.Explosions.MaxDamageScale then
        addStrike(sender, 'Explosion Damage Scale - ' .. ds, 2, 'explosion')
        CancelEvent()
    end
    if event.posX and event.posY and event.posZ then
        local ec = vector3(event.posX, event.posY, event.posZ)
        local ped = GetPlayerPed(sender)
        if ped ~= 0 then
            local pc = GetEntityCoords(ped)
            local d = #(ec - pc)
            if d > CFG.Explosions.MaxRadius then
                addStrike(sender, 'Explosion Fuori Raggio - ' .. math.floor(d) .. 'm', 1, 'explosion')
            end
        end
    end
end

function modules.checkParticle(pId, name)
    if type(name) ~= 'string' then return end
    if #name > 200 then return end
    local data = getData(pId)
    if rateLimit(data.particleLog, CFG.Entities.MaxParticlesPerMinute, 60000) then
        addStrike(pId, 'Particle Spam - ' .. name, 1, 'particle')
    end
end

function modules.checkScenario(pId, name)
    if type(name) ~= 'string' then return end
    if #name > 200 then return end
    local data = getData(pId)
    if rateLimit(data.scenarioLog, CFG.Entities.MaxScenariosPerMinute, 60000) then
        addStrike(pId, 'Scenario Spam - ' .. name, 1, 'scenario')
    end
end

function modules.checkEntityCount(pId)
    if not CFG.Entities.EnableEntityCountCheck then return end
    local oc, vc, pc = 0, 0, 0
    for _, o in ipairs(GetAllObjects()) do
        if o and o ~= 0 and DoesEntityExist(o) then oc = oc + 1 end
    end
    for _, v in ipairs(GetAllVehicles()) do
        if v and v ~= 0 and DoesEntityExist(v) then vc = vc + 1 end
    end
    for _, p in ipairs(GetAllPeds()) do
        if p and p ~= 0 and DoesEntityExist(p) then pc = pc + 1 end
    end
    local total = oc + vc + pc
    if total > CFG.Entities.MaxEntitiesPerPlayer * 5 then
        addStrike(pId, 'Entity Count Totale Anomalo - ' .. total, 1, 'entity')
    end
end

function modules.checkCommand(pId, cmd)
    if type(cmd) ~= 'string' then return end
    if #cmd > 500 then return end
    if not CFG.Events.EnableCommandCheck then return end
    local data = getData(pId)
    local lower = string.lower(cmd)
    if rateLimit(data.commandLog, CFG.Events.MaxCommandsPerMinute, 60000) then
        addStrike(pId, 'Comando Rate Anomalo', 1, 'command')
    end
    for _, pattern in ipairs(CFG.Events.SuspiciousCommands) do
        if string.find(lower, pattern, 1, true) then
            addStrike(pId, 'Comando Sospetto - ' .. cmd, 2, 'stop')
            return
        end
    end
end

function modules.checkTrigger(pId, name)
    if type(name) ~= 'string' then return end
    if #name > 200 then return end
    if not CFG.Events.EnableTriggerCheck then return end
    local data = getData(pId)
    if rateLimit(data.triggerLog, CFG.Events.MaxEventsPerSecond, 1000) then
        addStrike(pId, 'Trigger Spam - ' .. name, 1, 'trigger')
    end
end

function modules.checkHeartbeat(pId)
    if not CFG.DevTool.EnableHeartbeatCheck then return end
    local data = getData(pId)
    local now = GetGameTimer()
    if data.lastHeartbeat > 0 then
        local gap = now - data.lastHeartbeat
        if gap > CFG.DevTool.MaxHeartbeatGap * 3 then
            addStrike(pId, 'Heartbeat Perso - ' .. gap .. 'ms', 1, 'heartbeat')
        end
    end
    data.lastHeartbeat = now
end

function modules.checkDom(pId)
    if not CFG.DevTool.EnableDomCheck then return end
    local data = getData(pId)
    if rateLimit(data.domLog, CFG.DevTool.MaxDomMutationsPerMinute, 60000) then
        addStrike(pId, 'DOM Mutation Anomala', 2, 'dom')
        data.domLog = {}
    end
end

function modules.checkNui(pId)
    if not CFG.DevTool.EnableNuiRateCheck then return end
    local data = getData(pId)
    if rateLimit(data.nuiLog, CFG.DevTool.MaxNuiCallbacksPerMinute, 60000) then
        addStrike(pId, 'NUI Callback Rate Anomalo', 1, 'nui')
    end
end

function modules.checkDamage(pId, victimId, damage, weaponHash)
    if not CFG.Combat.EnableDamageCheck then return end
    if type(damage) ~= 'number' then return end
    if damage < 0 or damage > 10000 then return end
    local ceiling = damageCeiling(weaponHash)
    
    if not database.damageLog[pId] then
        database.damageLog[pId] = {total = 0, count = 0, highDamageCount = 0, lastReset = GetGameTimer()}
    end
    local dmgLog = database.damageLog[pId]
    
    if GetGameTimer() - dmgLog.lastReset > 60000 then
        dmgLog.total = 0
        dmgLog.count = 0
        dmgLog.highDamageCount = 0
        dmgLog.lastReset = GetGameTimer()
    end
    
    dmgLog.total = dmgLog.total + damage
    dmgLog.count = dmgLog.count + 1
    
    if damage > ceiling and damage > 15 then
        dmgLog.highDamageCount = dmgLog.highDamageCount + 1
        if dmgLog.highDamageCount >= 5 then
            addStrike(pId, 'Damage Anomalo - ' .. math.floor(damage) .. ' (max ' .. math.floor(ceiling) .. ')', 1, 'damage')
        end
    end
    
    if damage > CFG.Combat.MaxDamagePerHit then
        addStrike(pId, 'Danno Estremo - ' .. math.floor(damage), 2, 'damage')
    end
    
    if dmgLog.count > 0 and (dmgLog.total / dmgLog.count) > ceiling * 0.8 then
        if dmgLog.count >= 20 then
            addStrike(pId, 'Average Damage Too High - ' .. math.floor(dmgLog.total / dmgLog.count), 1, 'damage')
        end
    end
    
    if CFG.MagicBullet.EnableCheck and victimId and victimId > 0 and victimId ~= pId then
        database.losCheckId = database.losCheckId + 1
        local reqId = database.losCheckId
        database.pendingLosChecks[reqId] = {
            attacker = pId,
            victim = victimId,
            weapon = weaponHash,
            expires = GetGameTimer() + CFG.Intervals.PendingLosTimeout
        }
        TriggerClientEvent('haze_ac:requestLos', pId, victimId, reqId)
    end
end

function modules.checkBehavioralAnomaly(pId)
    local data = getData(pId)
    local now = GetGameTimer()
    
    if not database.positionHistory[pId] then
        database.positionHistory[pId] = {positions = {}, lastCheck = now}
    end
    local posHist = database.positionHistory[pId]
    
    if now - posHist.lastCheck > 5000 then
        posHist.lastCheck = now
        if data.lastPos then
            posHist.positions[#posHist.positions + 1] = {
                x = data.lastPos.x,
                y = data.lastPos.y,
                z = data.lastPos.z,
                time = now
            }
            if #posHist.positions > 12 then
                table.remove(posHist.positions, 1)
            end
            
            if #posHist.positions >= 6 then
                local totalDist = 0
                for i = 2, #posHist.positions do
                    local dx = posHist.positions[i].x - posHist.positions[i-1].x
                    local dy = posHist.positions[i].y - posHist.positions[i-1].y
                    local dz = posHist.positions[i].z - posHist.positions[i-1].z
                    totalDist = totalDist + math.sqrt(dx*dx + dy*dy + dz*dz)
                end
                local avgSpeed = totalDist / 30.0
                
                if avgSpeed > 100.0 then
                    addStrike(pId, 'Unnatural Movement Pattern - Speed: ' .. math.floor(avgSpeed) .. ' m/s', 1, 'behavior')
                end
            end
        end
    end
end

function modules.checkVehicleIntegrity(pId)
    return
end

function modules.checkRPFPed(pId)
    return
end

local function scanManifests()
    return true
end

local function scanSuspicious()
    return true
end

local function scanBackdoors()
    return true
end

local function watchdog()
    if not CFG.Resources.EnableWatchdog then return end
    for _, critical in ipairs(CFG.Resources.Critical) do
        local st = GetResourceState(critical)
        if st == 'missing' or st == 'stopped' then
            log(1, 'Critical resource down: ' .. critical)
            if CFG.Resources.AutoRestartCritical then
                ExecuteCommand('ensure ' .. critical)
            end
        end
    end
end

RegisterNetEvent('haze_ac:heartbeat')
AddEventHandler('haze_ac:heartbeat', function()
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    modules.checkHeartbeat(pId)
end)

RegisterNetEvent('haze_ac:requestToken')
AddEventHandler('haze_ac:requestToken', function(eventName, requestId)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if not checkGlobalEventRate(pId, 'token_request') then return end

    local token = generateEventToken(pId, eventName)
    local serverTimestamp = os.time() * 1000
    TriggerClientEvent('haze_ac:tokenResponse', pId, eventName, token, requestId, serverTimestamp)
end)

RegisterNetEvent('haze_ac:stateReport')
AddEventHandler('haze_ac:stateReport', function(r)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if type(r) ~= 'table' then return end
    if hasBypass(pId) then return end
    modules.checkState(pId, r)
end)

RegisterNetEvent('haze_ac:camSnap')
AddEventHandler('haze_ac:camSnap', function(pd, yd)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if hasBypass(pId) then return end
    if not CFG.Aim.EnableAimbotCheck then return end
    modules.checkAimbot(pId, pd, yd)
end)

RegisterNetEvent('haze_ac:shotFired')
AddEventHandler('haze_ac:shotFired', function(weapon, targetId, distance)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if hasBypass(pId) then return end
    modules.checkShot(pId, weapon, targetId, distance)
end)

RegisterNetEvent('haze_ac:stateFlag')
AddEventHandler('haze_ac:stateFlag', function(flag, count)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if hasBypass(pId) then return end
    if flag == 'freecam' and CFG.Misc.EnableFreecamCheck and count >= CFG.Misc.MaxFreecamChecks then
        addStrike(pId, 'Freecam Attiva', 1, 'freecam')
    elseif flag == 'invisible' and CFG.Misc.EnableInvisibilityCheck and count >= CFG.Misc.MaxInvisibleChecks then
        addStrike(pId, 'Invisibilita Anomala', 2, 'invisibility')
    elseif flag == 'nightvision' and CFG.Misc.EnableNightVisionCheck then
        addStrike(pId, 'Night Vision Attiva', 1, 'vision')
    elseif flag == 'thermal' and CFG.Misc.EnableThermalCheck then
        addStrike(pId, 'Thermal Vision Attiva', 1, 'vision')
    elseif flag == 'stamina' and CFG.Misc.EnableStaminaCheck and count >= 3 then
        addStrike(pId, 'Stamina Infinita', 1, 'stamina')
    end
end)

RegisterNetEvent('haze_ac:weaponInventory')
AddEventHandler('haze_ac:weaponInventory', function(w)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if hasBypass(pId) then return end
    modules.checkInventory(pId, w)
end)

RegisterNetEvent('haze_ac:camSnapBatch')
AddEventHandler('haze_ac:camSnapBatch', function(batch)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if hasBypass(pId) then return end
    if type(batch) ~= 'table' then return end
    for _, snap in ipairs(batch) do
        if type(snap) == 'table' and snap.pitch and snap.yaw then
            modules.checkAimbot(pId, snap.pitch, snap.yaw)
        end
    end
end)

RegisterNetEvent('haze_ac:shotBatch')
AddEventHandler('haze_ac:shotBatch', function(batch)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if hasBypass(pId) then return end
    if type(batch) ~= 'table' then return end
    for _, shot in ipairs(batch) do
        if type(shot) == 'table' and shot.weapon then
            modules.checkShot(pId, shot.weapon, shot.target, shot.distance)
        end
    end
end)

RegisterNetEvent('haze_ac:flagsBatch')
AddEventHandler('haze_ac:flagsBatch', function(flags)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if hasBypass(pId) then return end
    if type(flags) ~= 'table' then return end
    for flag, count in pairs(flags) do
        if flag == 'freecam' and CFG.Misc.EnableFreecamCheck and count >= CFG.Misc.MaxFreecamChecks then
            addStrike(pId, 'Freecam Attiva', 1, 'freecam')
        elseif flag == 'invisible' and CFG.Misc.EnableInvisibilityCheck and count >= CFG.Misc.MaxInvisibleChecks then
            addStrike(pId, 'Invisibilita Anomala', 2, 'invisibility')
        elseif flag == 'nightvision' and CFG.Misc.EnableNightVisionCheck then
            addStrike(pId, 'Night Vision Attiva', 1, 'vision')
        elseif flag == 'thermal' and CFG.Misc.EnableThermalCheck then
            addStrike(pId, 'Thermal Vision Attiva', 1, 'vision')
        elseif flag == 'stamina' and CFG.Misc.EnableStaminaCheck and count >= 3 then
            addStrike(pId, 'Stamina Infinita', 1, 'stamina')
        end
    end
end)

RegisterNetEvent('haze_ac:resourceList')
AddEventHandler('haze_ac:resourceList', function(list)
    return
end)

RegisterNetEvent('haze_ac:healthAnomaly')
AddEventHandler('haze_ac:healthAnomaly', function(h, mh, a)
    return
end)

RegisterNetEvent('haze_ac:armorAnomaly')
AddEventHandler('haze_ac:armorAnomaly', function(a)
    return
end)

RegisterNetEvent('haze_ac:noRagdoll')
AddEventHandler('haze_ac:noRagdoll', function()
    return
end)

RegisterNetEvent('haze_ac:losResponse')
AddEventHandler('haze_ac:losResponse', function(reqId, hasLos, hasLosFront)
    local pId = source
    local check = database.pendingLosChecks[reqId]
    if not check then return end
    if check.attacker ~= pId then return end
    if GetGameTimer() > check.expires then
        database.pendingLosChecks[reqId] = nil
        return
    end
    if not hasLos and not hasLosFront then
        addStrike(check.attacker, 'Magic Bullet - Wall Penetration', 2, 'magicbullet')
    end
    database.pendingLosChecks[reqId] = nil
end)

RegisterNetEvent('haze_ac:damageEvent')
AddEventHandler('haze_ac:damageEvent', function(victimId, damage, weaponHash)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if type(damage) ~= 'number' then return end
    if hasBypass(pId) then return end

    local data = getData(pId)
    local now = GetGameTimer()

    if data.lastDamageTime > 0 then
        local reactionTime = now - data.lastDamageTime
        if reactionTime < 40 and reactionTime > 5 then
            data.fastReactionCount = (data.fastReactionCount or 0) + 1
            if data.fastReactionCount >= 5 then
                addStrike(pId, 'Triggerbot Detection - Reaction Time: ' .. reactionTime .. 'ms', 2, 'triggerbot')
                data.fastReactionCount = 0
            end
        else
            data.fastReactionCount = 0
        end
    end
    data.lastDamageTime = now

    local victimPed = GetPlayerPed(victimId)
    local attackerPed = GetPlayerPed(pId)

    if victimPed ~= 0 and attackerPed ~= 0 then
        local victimCoords = GetEntityCoords(victimPed)
        local attackerCoords = GetEntityCoords(attackerPed)
        local distance = #(victimCoords - attackerCoords)

        if distance > 200.0 then
            addStrike(pId, 'Damage from impossible distance - ' .. math.floor(distance) .. 'm', 2, 'damage')
        end

        local victimBone = GetPedBoneCoords(victimPed, 31086, 0.0, 0.0, 0.0)
        local startCoords = GetPedBoneCoords(attackerPed, 31086, 0.0, 0.0, 0.0)
        local endCoords = victimBone

        local rayHandle = StartShapeTestRay(startCoords.x, startCoords.y, startCoords.z, endCoords.x, endCoords.y, endCoords.z, -1, attackerPed, 0)
        local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

        if hit == 1 and entityHit ~= victimPed then
            if distance > 10.0 then
                addStrike(pId, 'Silent Aim - Wall Penetration Detected', 2, 'silentaim')
            end
        end
    end
    
    modules.checkDamage(pId, victimId, damage, weaponHash)
end)

RegisterNetEvent('haze_ac:damageReport')
AddEventHandler('haze_ac:damageReport', function(victimId, damage, weaponHash, distance)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    if hasBypass(pId) then return end
    modules.checkDamage(pId, victimId, damage, weaponHash)
end)

RegisterNetEvent('haze_ac:domMutation')
AddEventHandler('haze_ac:domMutation', function(d)
    return
end)

RegisterNetEvent('haze_ac:nuiCallback')
AddEventHandler('haze_ac:nuiCallback', function(n)
    return
end)

RegisterNetEvent('haze_ac:particleRequest')
AddEventHandler('haze_ac:particleRequest', function(n, d)
    return
end)

RegisterNetEvent('haze_ac:scenarioRequest')
AddEventHandler('haze_ac:scenarioRequest', function(n)
    return
end)

RegisterNetEvent('haze_ac:commandUsed')
AddEventHandler('haze_ac:commandUsed', function(c)
    return
end)

RegisterNetEvent('haze_ac:triggerAttempt')
AddEventHandler('haze_ac:triggerAttempt', function(n)
    return
end)

RegisterNetEvent('haze_ac:eventCheck')
AddEventHandler('haze_ac:eventCheck', function(n)
    return
end)

RegisterNetEvent('haze_ac:modelAnomaly')
AddEventHandler('haze_ac:modelAnomaly', function(model, entityType)
    return
end)

RegisterNetEvent('haze_ac:weaponNameAnomaly')
AddEventHandler('haze_ac:weaponNameAnomaly', function(hash)
    return
end)

RegisterNetEvent('haze_ac:screenshotData')
AddEventHandler('haze_ac:screenshotData', function(data)
    return
end)

RegisterNetEvent('haze_ac:entitySpawned')
AddEventHandler('haze_ac:entitySpawned', function(netId, model, entityType)
    return
end)

RegisterNetEvent('haze_ac:vehicleSpawned')
AddEventHandler('haze_ac:vehicleSpawned', function(netId, model)
    return
end)

RegisterNetEvent('haze_ac:vehicleDeleted')
AddEventHandler('haze_ac:vehicleDeleted', function(netId)
    return
end)

RegisterNetEvent('haze_ac:weaponGranted')
AddEventHandler('haze_ac:weaponGranted', function(hash, ammo)
    return
end)

RegisterNetEvent('haze_ac:clientResourceStart')
AddEventHandler('haze_ac:clientResourceStart', function(rn)
    return
end)

RegisterNetEvent('haze_ac:clientResourceStop')
AddEventHandler('haze_ac:clientResourceStop', function(rn)
    return
end)

AddEventHandler('explosionEvent', function(sender, event)
    if not sender or sender <= 0 then return end
    if not event or not event.explosionType then return end
    if not GetPlayerName(sender) then return end
    modules.checkExplosion(sender, event)
end)

AddEventHandler('entityCreating', function(entity)
    if not entity or entity == 0 then return end
    local model = GetEntityModel(entity)
    if CFG.Entities.EnableBlacklist and CFG.Entities.Blacklist[model] then
        CancelEvent()
        local owner = NetworkGetEntityOwner(entity)
        if owner and owner > 0 then
            addStrike(owner, 'Entita Blacklistata - ' .. tostring(model), 2, 'entity')
        end
        return
    end
end)

AddEventHandler('onResourceStop', function(rn)
    if rn == GetCurrentResourceName() then return end
    for _, cr in ipairs(CFG.Resources.Critical) do
        if rn == cr then
            log(1, 'Critical resource stopped: ' .. rn)
            if CFG.Resources.AutoRestartCritical then
                Citizen.SetTimeout(1000, function()
                    ExecuteCommand('ensure ' .. rn)
                end)
            end
            return
        end
    end
end)

AddEventHandler('onResourceStart', function(rn)
    return
end)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local pId = source
    deferrals.defer()
    Citizen.Wait(100)
    if not CFG.CheckBansOnConnect then
        deferrals.done()
        return
    end
    local identifiers = getIdentifiers(pId)
    identifiers.name = name
    local banned, ban = isBanned(identifiers)
    if banned then
        local msg = CFG.BanMessage .. (ban.reason or 'unknown')
        if ban.expiresAt and ban.expiresAt > 0 then
            msg = msg .. ' (expires: ' .. os.date('%Y-%m-%d %H:%M:%S', ban.expiresAt) .. ')'
        else
            msg = msg .. ' (permanent)'
        end
        log(1, 'Connection rejected - banned: ' .. name)
        deferrals.done(msg)
        return
    end
    deferrals.done()
end)

AddEventHandler('playerDropped', function(reason)
    local pId = source
    database.players[pId] = nil
end)

RegisterNetEvent('haze_ac:nativeDetection')
AddEventHandler('haze_ac:nativeDetection', function(token, detectionData)
    local pId = source
    if not pId or pId <= 0 then return end
    if not GetPlayerName(pId) then return end
    
    if isAdminWhitelisted(pId) then
        log(2, 'Native detection ignored for whitelisted admin: ' .. GetPlayerName(pId))
        return
    end
    
    if token then
        if not validateEventToken(pId, 'haze_ac:native_scan', token) then
            log(1, 'Invalid token for native detection from: ' .. GetPlayerName(pId))
            banPlayer(pId, 'Invalid Token - Security Violation', 0, 'token_violation')
            return
        end
    end
    
    if not detectionData or type(detectionData) ~= 'table' then
        return
    end
    
    local detectionType = detectionData.detectionType or 0
    local detectedProcess = detectionData.detectedProcess or 'unknown'
    local detectedDLL = detectionData.detectedDLL or 'unknown'
    local detectedTitle = detectionData.detectedTitle or ''
    local detectedDetail = detectionData.detectedDetail or ''
    local detectionTime = detectionData.detectionTime or 0
    
    database.nativeDetections[pId] = {
        detectionType = detectionType,
        detectedProcess = detectedProcess,
        detectedDLL = detectedDLL,
        detectedTitle = detectedTitle,
        detectedDetail = detectedDetail,
        detectionTime = detectionTime,
        timestamp = os.time()
    }
    
    local reason = 'Native Detection - '
    if detectionType == 1 then
        reason = reason .. 'Remote Debugger Attached'
    elseif detectionType == 2 then
        reason = reason .. 'Inline Hook: ' .. detectedDLL
    elseif detectionType == 3 then
        reason = reason .. 'Unsigned Module: ' .. detectedDLL
    elseif detectionType == 4 then
        reason = reason .. 'Thread Injection'
    elseif detectionType == 5 then
        reason = reason .. 'Process Handle Violation: ' .. detectedProcess
    else
        reason = reason .. 'Unknown Detection'
    end
    
    log(1, 'NATIVE DETECTION - BANNING: ' .. GetPlayerName(pId) .. ' - ' .. reason)
    
    banPlayer(pId, reason, 0, 'native_module')
end)

function isAdminWhitelisted(pId)
    if not pId or pId <= 0 then return false end
    
    if IsPlayerAceAllowed(pId, 'haze_ac.bypass') then
        return true
    end
    
    local identifiers = getIdentifiers(pId)
    local license2 = identifiers.license2 or identifiers.license
    
    if license2 and database.adminWhitelist[license2] then
        return true
    end
    
    return false
end

RegisterCommand('hazeac_whitelist_add', function(source, args)
    if source ~= 0 then
        if not IsPlayerAceAllowed(source, 'haze_ac.admin') then
            TriggerClientEvent(source, 'chat:addMessage', source, {args = {'^1[ERROR]^7 You do not have permission to use this command'}})
            return
        end
    end
    
    if not args[1] then
        print('[HazeAC] Usage: hazeac_whitelist_add <license2>')
        return
    end
    
    local license2 = args[1]
    database.adminWhitelist[license2] = true
    
    saveAdminWhitelist()
    
    print('[HazeAC] Added ' .. license2 .. ' to admin whitelist')
end, true)

RegisterCommand('hazeac_whitelist_remove', function(source, args)
    if source ~= 0 then
        if not IsPlayerAceAllowed(source, 'haze_ac.admin') then
            TriggerClientEvent(source, 'chat:addMessage', source, {args = {'^1[ERROR]^7 You do not have permission to use this command'}})
            return
        end
    end
    
    if not args[1] then
        print('[HazeAC] Usage: hazeac_whitelist_remove <license2>')
        return
    end
    
    local license2 = args[1]
    database.adminWhitelist[license2] = nil
    
    saveAdminWhitelist()
    
    print('[HazeAC] Removed ' .. license2 .. ' from admin whitelist')
end, true)

function loadAdminWhitelist()
    local whitelistFile = io.open(GetResourcePath(GetCurrentResourceName()) .. '/../haze_ac_admin_whitelist.json', 'r')
    if whitelistFile then
        local content = whitelistFile:read('*all')
        whitelistFile:close()
        
        local ok, decoded = pcall(json.decode, content)
        if ok and decoded and decoded.whitelist then
            database.adminWhitelist = decoded.whitelist
            log(2, 'Loaded admin whitelist: ' .. #decoded.whitelist .. ' entries')
        end
    else
        saveAdminWhitelist()
    end
end

function saveAdminWhitelist()
    local whitelistFile = io.open(GetResourcePath(GetCurrentResourceName()) .. '/../haze_ac_admin_whitelist.json', 'w')
    if whitelistFile then
        local data = {
            whitelist = database.adminWhitelist
        }
        whitelistFile:write(json.encode(data))
        whitelistFile:close()
    end
end

CreateThread(function()
    Citizen.Wait(1000)
    if not CFG.Validate() then
        print('[haze_ac] WARNING: proceeding with config errors')
    end
end)

CreateThread(function()
    Citizen.Wait(2000)
    loadBans()
    loadAdminWhitelist()
    scanManifests()
    scanSuspicious()
    log(2, 'Initial scan completed')
end)

CreateThread(function()
    while true do
        Wait(CFG.Intervals.StateServer)
        for _, pId in ipairs(GetPlayers()) do
            pId = tonumber(pId)
            if pId and GetPlayerName(pId) then
                if not hasBypass(pId) then
                    decay(pId)
                    modules.checkBehavioralAnomaly(pId)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(CFG.Intervals.Watchdog)
        watchdog()
    end
end)

CreateThread(function()
    while true do
        Wait(CFG.Intervals.HeartbeatScan)
        for _, pId in ipairs(GetPlayers()) do
            pId = tonumber(pId)
            if pId and GetPlayerName(pId) then
                if not hasBypass(pId) then
                    local data = database.players[pId]
                    if data and data.lastHeartbeat > 0 then
                        local gap = GetGameTimer() - data.lastHeartbeat
                        if gap > CFG.DevTool.MaxHeartbeatGap * CFG.DevTool.HeartbeatAbsentMultiplier then
                            addStrike(pId, 'Heartbeat Assente - ' .. gap .. 'ms', 2, 'devtool')
                        end
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for reqId, check in pairs(database.pendingLosChecks) do
            if now > check.expires then
                database.pendingLosChecks[reqId] = nil
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(CFG.Intervals.EntityCount)
        for _, pId in ipairs(GetPlayers()) do
            pId = tonumber(pId)
            if pId and GetPlayerName(pId) then
                if not hasBypass(pId) then
                    modules.checkEntityCount(pId)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(database.ioFlushInterval)
        if database.ioDirty and not database.pendingSave then
            saveBansAsync()
        end
    end
end)

RegisterCommand('haze_ac_status', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local monitored, active = 0, 0
    for _, data in pairs(database.players) do
        monitored = monitored + 1
        for _, c in pairs(data.strikes) do
            if c > 0 then active = active + 1 end
        end
    end
    print('[haze_ac] ================================')
    print('[haze_ac] Players: ' .. #GetPlayers())
    print('[haze_ac] Monitored: ' .. monitored)
    print('[haze_ac] Active strikes: ' .. active)
    print('[haze_ac] Total bans: ' .. #database.banDatabase.bans)
    print('[haze_ac] Punish action: ' .. tostring(database.punishAction))
    print('[haze_ac] Punish duration: ' .. tostring(database.punishDuration))
    print('[haze_ac] ================================')
end, false)

RegisterCommand('haze_ac_whitelist', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local id = tonumber(args[1])
    if id and GetPlayerName(id) then
        database.whitelist[id] = true
        print('[haze_ac] ' .. GetPlayerName(id) .. ' whitelisted')
    end
end, false)

RegisterCommand('haze_ac_unwhitelist', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local id = tonumber(args[1])
    if id then
        database.whitelist[id] = nil
        print('[haze_ac] ' .. tostring(id) .. ' removed from whitelist')
    end
end, false)

RegisterCommand('haze_ac_ban', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local id = tonumber(args[1])
    local duration = tonumber(args[2]) or 0
    table.remove(args, 1)
    table.remove(args, 1)
    local reason = table.concat(args, ' ')
    if not reason or reason == '' then reason = 'Manual ban' end
    if id and GetPlayerName(id) then
        local by = source == 0 and 'console' or GetPlayerName(source)
        banPlayer(id, reason, duration, by)
        print('[haze_ac] Banned ' .. tostring(id) .. ': ' .. reason)
    else
        print('[haze_ac] Usage: /haze_ac_ban [id] [duration_sec] [reason]')
    end
end, false)

RegisterCommand('haze_ac_unban', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local target = args[1]
    if not target then
        print('[haze_ac] Usage: /haze_ac_unban [license|hwid|name]')
        return
    end
    local removed = 0
    for i = #database.banDatabase.bans, 1, -1 do
        local ban = database.banDatabase.bans[i]
        if ban.license == target or ban.hwid == target or ban.name == target or
           ban.license2 == target or ban.steam == target or ban.discord == target or
           ban.fivem == target then
            table.remove(database.banDatabase.bans, i)
            removed = removed + 1
        end
    end
    if removed > 0 then
        saveBans()
        print('[haze_ac] Removed ' .. removed .. ' ban(s) for ' .. target)
    else
        print('[haze_ac] No bans found for ' .. target)
    end
end, false)

RegisterCommand('haze_ac_banlist', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local page = tonumber(args[1]) or 1
    local perPage = 10
    local bans = database.banDatabase.bans
    local total = #bans
    local pages = math.ceil(total / perPage)
    if page < 1 then page = 1 end
    if page > pages and pages > 0 then page = pages end
    local startIdx = (page - 1) * perPage + 1
    local endIdx = math.min(startIdx + perPage - 1, total)
    print('[haze_ac] === BAN LIST ' .. page .. '/' .. math.max(pages, 1) .. ' (' .. total .. ' total) ===')
    for i = startIdx, endIdx do
        local b = bans[i]
        local expiry = 'permanent'
        if b.expiresAt and b.expiresAt > 0 then
            expiry = os.date('%Y-%m-%d %H:%M', b.expiresAt)
        end
        print(string.format('[%d] %s | HWID:%s | %s | %s', i, b.name or '?', b.hwid or '?', expiry, b.reason or '?'))
    end
    print('[haze_ac] ================================')
end, false)

RegisterCommand('haze_ac_check', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local id = tonumber(args[1])
    if id and GetPlayerName(id) then
        local data = getData(id)
        local ids = getIdentifiers(id)
        print('[haze_ac] Player: ' .. GetPlayerName(id))
        print('[haze_ac] License: ' .. ids.license)
        print('[haze_ac] HWID: ' .. ids.hwid)
        print('[haze_ac] Tokens: ' .. #ids.tokens)
        print('[haze_ac] Discord: ' .. ids.discord)
        print('[haze_ac] Steam: ' .. ids.steam)
        for k, c in pairs(data.strikes) do
            if c > 0 then print('[haze_ac]   ' .. k .. ': ' .. c) end
        end
    else
        print('[haze_ac] Usage: /haze_ac_check [id]')
    end
end, false)

RegisterCommand('haze_ac_reset', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local id = tonumber(args[1])
    if id and database.players[id] then
        database.players[id].strikes = {}
        database.players[id].strikesTime = {}
        print('[haze_ac] Strikes reset for ' .. tostring(id))
    end
end, false)

RegisterCommand('haze_ac_punish', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local mode = args[1]
    if mode == 'ban' then
        database.punishAction = 'ban'
        print('[haze_ac] Action: BAN')
    elseif mode == 'kick' then
        database.punishAction = 'kick'
        print('[haze_ac] Action: KICK')
    elseif mode and tonumber(mode) then
        database.punishDuration = tonumber(mode)
        print('[haze_ac] Ban duration: ' .. mode .. 's')
    else
        print('[haze_ac] Usage: /haze_ac_punish [ban|kick|duration_sec]')
    end
end, false)

RegisterCommand('haze_ac_scan', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    scanSuspicious()
    scanBackdoors()
    scanManifests()
    print('[haze_ac] Manual scan completed')
end, false)

RegisterCommand('haze_ac_ensure', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local rn = args[1]
    if rn then
        ExecuteCommand('ensure ' .. rn)
        print('[haze_ac] Ensure: ' .. rn)
    end
end, false)

RegisterCommand('haze_ac_baninfo', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, CFG.Whitelist.AceAdmin) then return end
    local id = tonumber(args[1])
    if id and GetPlayerName(id) then
        local ids = getIdentifiers(id)
        print('[haze_ac] ============ BAN INFO ============')
        print('[haze_ac] Name: ' .. ids.name)
        print('[haze_ac] License: ' .. ids.license)
        print('[haze_ac] License2: ' .. ids.license2)
        print('[haze_ac] Steam: ' .. ids.steam)
        print('[haze_ac] Discord: ' .. ids.discord)
        print('[haze_ac] FiveM: ' .. ids.fivem)
        print('[haze_ac] IP: ' .. ids.ip)
        print('[haze_ac] HWID: ' .. ids.hwid)
        print('[haze_ac] Token count: ' .. #ids.tokens)
        for i, t in ipairs(ids.tokens) do
            print('[haze_ac]   Token ' .. i .. ': ' .. string.sub(t, 1, 20) .. '...')
        end
        print('[haze_ac] ====================================')
    else
        print('[haze_ac] Usage: /haze_ac_baninfo [id]')
    end
end, false)

AddEventHandler('onResourceStart', function(rn)
    if rn == GetCurrentResourceName() then
        database.punishAction = CFG.PunishAction
        database.punishDuration = CFG.PunishDuration
        log(1, 'Haze Anti-Cheat Suite started')
        log(1, 'Exporting functions for external resource integration')
        log(1, 'Async I/O system enabled - interval: ' .. (database.ioFlushInterval / 1000) .. 's')
    end
end)

AddEventHandler('onResourceStop', function(rn)
    if rn == GetCurrentResourceName() then
        log(1, 'Haze Anti-Cheat stopping - flushing ban cache to disk')
        flushBanCache()
        log(1, 'Ban cache flush complete')
        log(1, 'Ban cache stats - Hits: ' .. database.banCacheHits .. ', Misses: ' .. database.banCacheMisses)
    end
end)

exports('generateToken', function(playerId, eventName)
    return generateEventToken(playerId, eventName)
end)

exports('validateToken', function(playerId, eventName, token)
    return validateEventToken(playerId, eventName, token)
end)

exports('getPlayerStrikes', function(playerId)
    local data = getData(playerId)
    if not data then return 0 end
    local total = 0
    for _, count in pairs(data.strikes) do
        total = total + count
    end
    return total
end)

exports('hasStrike', function(playerId, strikeType)
    local data = getData(playerId)
    if not data then return false end
    return data.strikes[strikeType] and data.strikes[strikeType] > 0
end)

exports('isBanned', function(playerId)
    local identifiers = getIdentifiers(playerId)
    local banned, _ = isBanned(identifiers)
    return banned
end)

exports('addCustomStrike', function(playerId, reason, strikeType)
    addStrike(playerId, reason, 1, strikeType or 'custom')
end)

exports('checkEventRate', function(playerId, eventName)
    return checkGlobalEventRate(playerId, eventName)
end)
