local Framework = {
    name = nil,
    initialized = false
}

local function detectFramework()
    if GetResourceState('qb-core') == 'started' then
        Framework.name = 'qbcore'
        Framework.QBCore = exports['qb-core']:GetCoreObject()
        print('[HazeAC Bridge] QBcore detected')
    elseif GetResourceState('es_extended') == 'started' then
        Framework.name = 'esx'
        Framework.ESX = exports['es_extended']:getSharedObject()
        print('[HazeAC Bridge] ESX detected')
    elseif GetResourceState('qbox_core') == 'started' then
        Framework.name = 'qbox'
        Framework.QBox = exports['qbox_core']:GetCoreObject()
        print('[HazeAC Bridge] Qbox detected')
    else
        Framework.name = 'standalone'
        print('[HazeAC Bridge] No framework detected, running in standalone mode')
    end
    Framework.initialized = true
end

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    detectFramework()
end)

function Framework.GetPlayerIdentifier(playerId, type)
    if not playerId or playerId <= 0 then return nil end
    
    local identifiers = GetPlayerIdentifiers(playerId)
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, type .. ':') then
            return identifier
        end
    end
    return nil
end

function Framework.GetPlayerLicense(playerId)
    return Framework.GetPlayerIdentifier(playerId, 'license2') or Framework.GetPlayerIdentifier(playerId, 'license')
end

function Framework.IsPlayerAdmin(playerId)
    if not playerId or playerId <= 0 then return false end
    
    if IsPlayerAceAllowed(playerId, 'haze_ac.admin') then
        return true
    end
    
    if Framework.name == 'qbcore' and Framework.QBCore then
        return Framework.QBCore.Functions.HasPermission(playerId, 'admin')
    elseif Framework.name == 'esx' and Framework.ESX then
        local xPlayer = Framework.ESX.GetPlayerFromId(playerId)
        return xPlayer and xPlayer.getGroup() == 'admin'
    elseif Framework.name == 'qbox' and Framework.QBox then
        return Framework.QBox.HasPermission(playerId, 'admin')
    end
    
    return false
end

function Framework.IsPlayerWhitelisted(playerId)
    if not playerId or playerId <= 0 then return false end
    
    if IsPlayerAceAllowed(playerId, 'haze_ac.bypass') then
        return true
    end
    
    if Framework.name == 'qbcore' and Framework.QBCore then
        return Framework.QBCore.Functions.HasPermission(playerId, 'god')
    elseif Framework.name == 'esx' and Framework.ESX then
        local xPlayer = Framework.ESX.GetPlayerFromId(playerId)
        return xPlayer and xPlayer.getGroup() == 'admin'
    elseif Framework.name == 'qbox' and Framework.QBox then
        return Framework.QBox.HasPermission(playerId, 'admin')
    end
    
    return false
end

function Framework.GetPlayerName(playerId)
    if not playerId or playerId <= 0 then return 'Unknown' end
    
    local name = GetPlayerName(playerId)
    if name and name ~= '' then return name end
    
    if Framework.name == 'qbcore' and Framework.QBCore then
        local player = Framework.QBCore.Functions.GetPlayer(playerId)
        if player then return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname end
    elseif Framework.name == 'esx' and Framework.ESX then
        local xPlayer = Framework.ESX.GetPlayerFromId(playerId)
        return xPlayer and xPlayer.getName() or 'Unknown'
    end
    
    return 'Unknown'
end

function Framework.Notify(playerId, message, type)
    if not playerId or playerId <= 0 then return end
    
    type = type or 'info'
    
    if Framework.name == 'qbcore' and Framework.QBCore then
        Framework.QBCore.Functions.Notify(playerId, message, type)
    elseif Framework.name == 'esx' and Framework.ESX then
        Framework.ESX.ShowNotification(playerId, message, type)
    elseif Framework.name == 'qbox' and Framework.QBox then
        Framework.QBox.Notify(playerId, message, type)
    else
        TriggerClientEvent('chat:addMessage', playerId, {
            args = {'^3[HazeAC]^7 ' .. message}
        })
    end
end

function Framework.GetPlayerMoney(playerId)
    if not playerId or playerId <= 0 then return 0 end
    
    if Framework.name == 'qbcore' and Framework.QBCore then
        local player = Framework.QBCore.Functions.GetPlayer(playerId)
        if player then
            return player.PlayerData.money.bank + player.PlayerData.money.cash
        end
    elseif Framework.name == 'esx' and Framework.ESX then
        local xPlayer = Framework.ESX.GetPlayerFromId(playerId)
        return xPlayer and xPlayer.getMoney() or 0
    elseif Framework.name == 'qbox' and Framework.QBox then
        local money = Framework.QBox.GetMoney(playerId)
        return money.bank + money.cash
    end
    
    return 0
end

function Framework.RemoveMoney(playerId, amount, reason)
    if not playerId or playerId <= 0 or amount <= 0 then return false end
    
    if Framework.name == 'qbcore' and Framework.QBCore then
        Framework.QBCore.Functions.RemoveMoney(playerId, 'bank', amount)
        Framework.Notify(playerId, 'Removed $' .. amount .. ' - ' .. reason, 'error')
        return true
    elseif Framework.name == 'esx' and Framework.ESX then
        local xPlayer = Framework.ESX.GetPlayerFromId(playerId)
        if xPlayer then
            xPlayer.removeMoney(amount)
            return true
        end
    elseif Framework.name == 'qbox' and Framework.QBox then
        Framework.QBox.RemoveMoney(playerId, amount)
        return true
    end
    
    return false
end

function Framework.KickPlayer(playerId, reason)
    if not playerId or playerId <= 0 then return end
    
    Framework.Notify(playerId, reason, 'error')
    Citizen.Wait(1000)
    DropPlayer(playerId, reason)
end

function Framework.Log(message, level)
    level = level or 'info'
    
    if Framework.name == 'qbcore' and Framework.QBCore then
        Framework.QBCore.Functions.Log(message, level)
    elseif Framework.name == 'esx' and Framework.ESX then
        print('[ESX-HazeAC] ' .. message)
    elseif Framework.name == 'qbox' and Framework.QBox then
        print('[QBox-HazeAC] ' .. message)
    else
        print('[HazeAC] ' .. message)
    end
end

exports('GetFramework', function()
    return Framework.name
end)

exports('IsPlayerAdmin', function(playerId)
    return Framework.IsPlayerAdmin(playerId)
end)

exports('IsPlayerWhitelisted', function(playerId)
    return Framework.IsPlayerWhitelisted(playerId)
end)

exports('NotifyPlayer', function(playerId, message, type)
    Framework.Notify(playerId, message, type)
end)

print('[HazeAC Bridge] Framework bridge loaded')
