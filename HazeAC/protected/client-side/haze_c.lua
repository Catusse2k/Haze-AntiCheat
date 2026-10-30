if not HazeConfig then
    print('[haze_ac_client] FATAL: haze_config.lua not loaded')
    return
end

local state = {
    lastCamRot = nil,
    lastShotTime = 0,
    lastPos = nil,
    lastPosTime = 0,
    camSnapBuffer = {},
    shotBuffer = {},
    stateBuffer = nil,
    flagsBuffer = {},
    lastInventoryCheck = 0,
    inventoryBuffer = nil,
    heartbeatLast = 0,
    batchCounter = 0,
    eventTokens = {}
}

local function num(n)
    if type(n) ~= 'number' then return 0 end
    if n ~= n then return 0 end
    if n == math.huge or n == -math.huge then return 0 end
    return n
end

local function int(n)
    return math.floor(num(n))
end

local function getPed()
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

local function safeGroundHeight(ped)
    if GetEntityHeightAboveGround then
        return num(GetEntityHeightAboveGround(ped))
    end
    return 0
end

local function flushBuffers()
    if #state.camSnapBuffer > 0 then
        TriggerServerEvent('haze_ac:camSnapBatch', state.camSnapBuffer)
        state.camSnapBuffer = {}
    end
    if #state.shotBuffer > 0 then
        TriggerServerEvent('haze_ac:shotBatch', state.shotBuffer)
        state.shotBuffer = {}
    end
    if next(state.flagsBuffer) then
        TriggerServerEvent('haze_ac:flagsBatch', state.flagsBuffer)
        state.flagsBuffer = {}
    end
    if state.inventoryBuffer then
        TriggerServerEvent('haze_ac:weaponInventory', state.inventoryBuffer)
        state.inventoryBuffer = nil
    end
end

CreateThread(function()
    while true do
        Wait(HazeConfig.Intervals.HeartbeatClient)
        local ped = getPed()
        if ped then
            state.heartbeatLast = GetGameTimer()
            TriggerServerEvent('haze_ac:heartbeat')
        end
    end
end)

CreateThread(function()
    while true do
        Wait(HazeConfig.Intervals.StateClient)
        local ped = getPed()
        if ped then
            local coords = GetEntityCoords(ped)
            local velocity = GetEntityVelocity(ped)
            local vehicle = GetVehiclePedIsIn(ped, false)
            local weapon = GetSelectedPedWeapon(ped)
            
            state.stateBuffer = {
                coords = {x = num(coords.x), y = num(coords.y), z = num(coords.z)},
                velocity = {x = num(velocity.x), y = num(velocity.y), z = num(velocity.z)},
                speed = num(math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)),
                health = int(GetEntityHealth(ped)),
                maxHealth = int(GetEntityMaxHealth(ped)),
                armor = int(GetPedArmour(ped)),
                weapon = weapon,
                inVehicle = vehicle ~= 0,
                vehicleModel = vehicle ~= 0 and GetEntityModel(vehicle) or 0,
                vehicleSpeed = vehicle ~= 0 and num(GetEntitySpeed(vehicle)) or 0,
                vehicleBodyHealth = vehicle ~= 0 and num(GetVehicleBodyHealth(vehicle)) or 0,
                vehicleEngineHealth = vehicle ~= 0 and num(GetVehicleEngineHealth(vehicle)) or 0,
                vehicleHealth = vehicle ~= 0 and int(GetEntityHealth(vehicle)) or 0,
                vehicleMaxHealth = vehicle ~= 0 and int(GetEntityMaxHealth(vehicle)) or 0,
                heightAboveGround = safeGroundHeight(ped),
                falling = IsPedFalling(ped),
                ragdoll = IsPedRagdoll(ped),
                swimming = IsPedSwimming(ped),
                inWater = IsPedInWater(ped),
                climbing = IsPedClimbing(ped),
                jumping = IsPedJumping(ped),
                running = IsPedRunning(ped),
                sprinting = IsPedSprinting(ped),
                shooting = IsPedShooting(ped),
                aiming = IsPlayerFreeAiming(PlayerId()),
                visible = IsEntityVisible(ped),
                canRagdoll = CanPedRagdoll(ped),
                invincible = GetPlayerInvincible(PlayerId()),
                stamina = GetPlayerStamina and num(GetPlayerStamina(PlayerId())) or 100.0,
                dead = IsPedDeadOrDying(ped, false),
                ducking = IsPedDucking(ped),
                reloading = IsPedReloading(ped),
                parachuting = IsPedInParachuteFreeFall(ped),
                inCover = IsPedInCover(ped, false),
                timestamp = GetGameTimer()
            }
            
            if not state.lastPos then
                state.lastPos = {x = coords.x, y = coords.y, z = coords.z}
                state.lastPosTime = GetGameTimer()
            end
            
            state.batchCounter = state.batchCounter + 1
            if state.batchCounter >= 3 then
                TriggerServerEvent('haze_ac:stateReport', state.stateBuffer)
                state.batchCounter = 0
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(HazeConfig.Intervals.CamClient)
        local ped = getPed()
        if ped then
            local camRot = GetGameplayCamRot(0)
            if state.lastCamRot then
                local pd = math.abs(camRot.x - state.lastCamRot.x)
                local yd = math.abs(camRot.z - state.lastCamRot.z)
                if pd > 180 then pd = 360 - pd end
                if yd > 180 then yd = 360 - yd end
                if pd > 20 or yd > 20 then
                    state.camSnapBuffer[#state.camSnapBuffer + 1] = {
                        pitch = num(pd),
                        yaw = num(yd),
                        timestamp = GetGameTimer()
                    }
                    if #state.camSnapBuffer >= 5 then
                        TriggerServerEvent('haze_ac:camSnapBatch', state.camSnapBuffer)
                        state.camSnapBuffer = {}
                    end
                end
            end
            state.lastCamRot = camRot
        end
    end
end)

CreateThread(function()
    while true do
        Wait(HazeConfig.Intervals.ShotClient)
        local ped = getPed()
        if ped and IsPedShooting(ped) then
            local now = GetGameTimer()
            if now - state.lastShotTime > 30 then
                local weapon = GetSelectedPedWeapon(ped)
                local targetServerId = nil
                local distance = 0
                local hit, entityHit = GetEntityPlayerIsFreeAimingAt(PlayerId())
                if hit and entityHit and entityHit ~= 0 and IsPedAPlayer(entityHit) then
                    local idx = NetworkGetPlayerIndexFromPed(entityHit)
                    if idx and idx ~= -1 then
                        targetServerId = GetPlayerServerId(idx)
                        local tc = GetEntityCoords(entityHit)
                        local mc = GetEntityCoords(ped)
                        distance = num(math.sqrt((tc.x-mc.x)^2 + (tc.y-mc.y)^2 + (tc.z-mc.z)^2))
                    end
                end
                state.shotBuffer[#state.shotBuffer + 1] = {
                    weapon = weapon,
                    target = targetServerId,
                    distance = distance,
                    timestamp = now
                }
                if #state.shotBuffer >= 10 then
                    TriggerServerEvent('haze_ac:shotBatch', state.shotBuffer)
                    state.shotBuffer = {}
                end
                state.lastShotTime = now
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(HazeConfig.Intervals.VisionClient)
        local ped = getPed()
        if ped then
            if IsPlayerInFreeCamMode and IsPlayerInFreeCamMode(PlayerId()) then
                state.flagsBuffer.freecam = (state.flagsBuffer.freecam or 0) + 1
            else
                state.flagsBuffer.freecam = 0
            end
            if GetUsingnightvision and GetUsingnightvision() then
                state.flagsBuffer.nightvision = (state.flagsBuffer.nightvision or 0) + 1
            end
            if GetUsingseethrough and GetUsingseethrough() then
                state.flagsBuffer.thermal = (state.flagsBuffer.thermal or 0) + 1
            end
            if not IsEntityVisible(ped) then
                state.flagsBuffer.invisible = (state.flagsBuffer.invisible or 0) + 1
            else
                state.flagsBuffer.invisible = 0
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(HazeConfig.Intervals.StaminaClient)
        local ped = getPed()
        if ped and GetPlayerStamina then
            local st = GetPlayerStamina(PlayerId()) or 100.0
            if st < HazeConfig.Misc.MinStaminaThreshold then
                if IsPedRunning(ped) or IsPedSprinting(ped) then
                    state.flagsBuffer.stamina = (state.flagsBuffer.stamina or 0) + 1
                end
            else
                state.flagsBuffer.stamina = 0
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(HazeConfig.Intervals.WeaponClient)
        local ped = getPed()
        if ped then
            local weapons = {}
            for i = 1, 60 do
                local has, hash = GetPedWeapon(ped, i)
                if has and hash and hash ~= 0 then
                    weapons[tostring(hash)] = {
                        hash = hash,
                        ammo = int(GetAmmoInPedWeapon(ped, hash))
                    }
                end
            end
            state.inventoryBuffer = weapons
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        flushBuffers()
    end
end)

local tokenCallbacks = {}

local function requestToken(eventName, callback)
    if state.eventTokens[eventName] then
        local tokenData = state.eventTokens[eventName]
        if GetGameTimer() - tokenData.timestamp < 12000 then
            if callback then callback(tokenData.token) end
            return tokenData.token
        end
    end

    local requestId = eventName .. '_' .. GetGameTimer()
    tokenCallbacks[requestId] = callback

    TriggerServerEvent('haze_ac:requestToken', eventName, requestId)
end)

RegisterNetEvent('haze_ac:tokenResponse')
AddEventHandler('haze_ac:tokenResponse', function(responseEventName, token, requestId)
    if requestId and tokenCallbacks[requestId] then
        state.eventTokens[responseEventName] = {
            token = token,
            timestamp = GetGameTimer()
        }
        if tokenCallbacks[requestId] then
            tokenCallbacks[requestId](token)
            tokenCallbacks[requestId] = nil
        end
    end
end)

exports('getToken', function(eventName)
    if state.eventTokens[eventName] then
        local tokenData = state.eventTokens[eventName]
        if GetGameTimer() - tokenData.timestamp < 12000 then
            return tokenData.token
        end
    end
    return nil
end)

exports('requestToken', function(eventName, callback)
    requestToken(eventName, callback)
end)

exports('triggerProtectedEvent', function(eventName, ...)
    local args = {...}
    requestToken(eventName, function(token)
        if token then
            TriggerServerEvent(eventName, token, table.unpack(args))
        else
            TriggerServerEvent(eventName, table.unpack(args))
        end
    end)
end)

RegisterNetEvent('haze_ac:requestLos')
AddEventHandler('haze_ac:requestLos', function(targetServerId, requestId)
    local targetIdx = GetPlayerFromServerId(targetServerId)
    if not targetIdx or targetIdx == -1 then
        TriggerServerEvent('haze_ac:losResponse', requestId, false, false)
        return
    end
    local myPed = getPed()
    local targetPed = GetPlayerPed(targetIdx)
    if not myPed or targetPed == 0 then
        TriggerServerEvent('haze_ac:losResponse', requestId, false, false)
        return
    end
    local los = HasEntityClearLosToEntity(myPed, targetPed, 17)
    local losFront = HasEntityClearLosToEntityInFront(myPed, targetPed)
    TriggerServerEvent('haze_ac:losResponse', requestId, los, losFront)
end)

RegisterNetEvent('haze_ac:requestScreenshot')
AddEventHandler('haze_ac:requestScreenshot', function()
    if exports and exports['screenshot-basic'] then
        exports['screenshot-basic']:requestScreenshotUpload(
            GetCurrentServerEndpoint and GetCurrentServerEndpoint() or '',
            'haze_ac_screenshot',
            function(data)
                TriggerServerEvent('haze_ac:screenshotData', tostring(data))
            end
        )
    end
end)

RegisterNetEvent('haze_ac:notify')
AddEventHandler('haze_ac:notify', function(msg)
    print('[haze_ac] ' .. tostring(msg))
end)

RegisterNetEvent('haze_ac:printBan')
AddEventHandler('haze_ac:printBan', function(reason)
    print('==========================================')
    print('   HAZE_AC - YOU HAVE BEEN BANNED')
    print('   Reason: ' .. tostring(reason))
    print('==========================================')
end)

AddEventHandler('playerSpawned', function()
    state.lastCamRot = nil
    state.lastShotTime = 0
    state.lastPos = nil
    state.lastPosTime = 0
    state.camSnapBuffer = {}
    state.shotBuffer = {}
    state.stateBuffer = nil
    state.flagsBuffer = {}
    state.inventoryBuffer = nil
    state.heartbeatLast = 0
    state.batchCounter = 0
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local damage = args[3]
        local weaponHash = args[4]
        if victim and victim ~= 0 and IsPedAPlayer(victim) then
            local idx = NetworkGetPlayerIndexFromPed(victim)
            if idx and idx ~= -1 then
                local victimId = GetPlayerServerId(idx)
                if victimId and victimId > 0 then
                    TriggerServerEvent('haze_ac:damageEvent', victimId, damage or 0, weaponHash or 0)
                end
            end
        end
    end
end)
