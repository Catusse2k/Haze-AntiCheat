local Framework = nil
if GetResourceState('qb-core') == 'started' then
    Framework = 'qbcore'
elseif GetResourceState('es_extended') == 'started' then
    Framework = 'esx'
elseif GetResourceState('qbox_core') == 'started' then
    Framework = 'qbox'
end

print('[HazeAC NUI] Framework detected: ' .. (Framework or 'none'))

local function getPlayers()
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        if id then
            local name = GetPlayerName(id)
            local identifiers = {}
            
            for _, identifier in ipairs(GetPlayerIdentifiers(id)) do
                if string.find(identifier, 'license:') then
                    identifiers.license = identifier
                elseif string.find(identifier, 'license2:') then
                    identifiers.license2 = identifier
                elseif string.find(identifier, 'steam:') then
                    identifiers.steam = identifier
                elseif string.find(identifier, 'discord:') then
                    identifiers.discord = identifier
                elseif string.find(identifier, 'xbl:') then
                    identifiers.xbl = identifier
                elseif string.find(identifier, 'live:') then
                    identifiers.live = identifier
                elseif string.find(identifier, 'fivem:') then
                    identifiers.fivem = identifier
                elseif string.find(identifier, 'ip:') then
                    identifiers.ip = identifier
                end
            end
            
            local strikes = {}
            if exports.haze_ac and exports.haze_ac:getPlayerStrikes then
                strikes = exports.haze_ac:getPlayerStrikes(id) or {}
            end
            
            players[#players + 1] = {
                id = id,
                name = name,
                license = identifiers.license or '',
                license2 = identifiers.license2 or '',
                steam = identifiers.steam or '',
                discord = identifiers.discord or '',
                hwid = exports.haze_ac and exports.haze_ac:getHwid and exports.haze_ac:getHwid(id) or 'unknown',
                strikes = strikes,
                connected = true
            }
        end
    end
    return players
end

local function getBans()
    local bans = {}
    
    local banFile = io.open(GetResourcePath(GetCurrentResourceName()) .. '/../haze_ac_bans.json', 'r')
    if banFile then
        local content = banFile:read('*all')
        banFile:close()
        
        local ok, decoded = pcall(json.decode, content)
        if ok and decoded and decoded.bans then
            for _, ban in ipairs(decoded.bans) do

                local now = os.time()
                if not ban.expiresAt or ban.expiresAt == 0 or now < ban.expiresAt then
                    bans[#bans + 1] = {
                        name = ban.name or 'unknown',
                        license = ban.license or '',
                        license2 = ban.license2 or '',
                        hwid = ban.hwid or '',
                        reason = ban.reason or 'unknown',
                        bannedAt = ban.bannedAt or 0,
                        expiresAt = ban.expiresAt or 0,
                        permanent = (ban.expiresAt or 0) == 0
                    }
                end
            end
        end
    end
    
    return bans
end

local function getStats()
    local stats = {
        players = #GetPlayers(),
        monitored = 0,
        activeStrikes = 0,
        totalBans = 0,
        punishAction = 'ban',
        punishDuration = 0
    }
    
    if exports.haze_ac and exports.haze_ac:getStats then
        local acStats = exports.haze_ac:getStats()
        if acStats then
            stats = acStats
        end
    else

        local players = getPlayers()
        stats.monitored = #players
        for _, player in ipairs(players) do
            if player.strikes and type(player.strikes) == 'table' then
                for _, count in pairs(player.strikes) do
                    stats.activeStrikes = stats.activeStrikes + count
                end
            end
        end
        
        local bans = getBans()
        stats.totalBans = #bans
    end
    
    return stats
end

local function banPlayer(playerId, reason, duration)
    if not playerId or playerId <= 0 then
        return {success = false, message = 'Invalid player ID'}
    end
    
    if exports.haze_ac and exports.haze_ac:banPlayer then
        exports.haze_ac:banPlayer(playerId, reason, duration, 'nui_panel')
        return {success = true, message = 'Player banned via HazeAC'}
    else
        DropPlayer(playerId, 'Banned: ' .. reason)
        return {success = true, message = 'Player banned (manual)'}
    end
end

local function unban(license)
    if not license or license == '' then
        return {success = false, message = 'Invalid license'}
    end
    
    if exports.haze_ac and exports.haze_ac:unban then
        exports.haze_ac:unban(license)
        return {success = true, message = 'Player unbanned via HazeAC'}
    else

        local banFile = io.open(GetResourcePath(GetCurrentResourceName()) .. '/../haze_ac_bans.json', 'r')
        if banFile then
            local content = banFile:read('*all')
            banFile:close()
            
            local ok, decoded = pcall(json.decode, content)
            if ok and decoded and decoded.bans then
                local newBans = {}
                for _, ban in ipairs(decoded.bans) do
                    if ban.license ~= license then
                        newBans[#newBans + 1] = ban
                    end
                end
                decoded.bans = newBans
                
                local writeFile = io.open(GetResourcePath(GetCurrentResourceName()) .. '/../haze_ac_bans.json', 'w')
                if writeFile then
                    writeFile:write(json.encode(decoded))
                    writeFile:close()
                    return {success = true, message = 'Player unbanned (manual)'}
                end
            end
        end
        return {success = false, message = 'Failed to unban'}
    end
end

local function resetStrikes(playerId)
    if not playerId or playerId <= 0 then
        return {success = false, message = 'Invalid player ID'}
    end
    
    if exports.haze_ac and exports.haze_ac:resetStrikes then
        exports.haze_ac:resetStrikes(playerId)
        return {success = true, message = 'Strikes reset via HazeAC'}
    else
        return {success = false, message = 'HazeAC not available'}
    end
end

RegisterNUICallback('getPlayers', function(data, cb)
    cb(getPlayers())
end)

RegisterNUICallback('getBans', function(data, cb)
    cb(getBans())
end)

RegisterNUICallback('getStats', function(data, cb)
    cb(getStats())
end)

RegisterNUICallback('banPlayer', function(data, cb)
    local result = banPlayer(data.playerId, data.reason, data.duration)
    cb(result)
end)

RegisterNUICallback('unban', function(data, cb)
    local result = unban(data.license)
    cb(result)
end)

RegisterNUICallback('resetStrikes', function(data, cb)
    local result = resetStrikes(data.playerId)
    cb(result)
end)

RegisterCommand('hazeac_panel', function(source)
    if source ~= 0 then
        if not IsPlayerAceAllowed(source, 'haze_ac.admin') then
            TriggerClientEvent(source, 'chat:addMessage', source, {args = {'^1[ERROR]^7 You do not have permission to use this command'}})
            return
        end
    end
    
    print('[HazeAC NUI] Opening admin panel for player: ' .. source)
    TriggerClientEvent('hazeac_nui:openPanel', source)
end, true)

RegisterNetEvent('hazeac_nui:openPanel')
AddEventHandler('hazeac_nui:openPanel', function()
    SendNUIMessage({
        action = 'openPanel'
    })
end)

print('[HazeAC NUI] Server-side bridge loaded')
