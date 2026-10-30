local uiVisible = false

RegisterNUICallback('closePanel', function(data, cb)
    SetNuiFocus(false)
    uiVisible = false
    cb({})
end)

RegisterNetEvent('hazeac_nui:openPanel')
AddEventHandler('hazeac_nui:openPanel', function()
    if not uiVisible then
        SendNUIMessage({
            action = 'openPanel'
        })
        SetNuiFocus(true, true)
        uiVisible = true
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if uiVisible and IsControlJustPressed(0, 200) then
            SendNUIMessage({
                action = 'closePanel'
            })
            SetNuiFocus(false, false)
            uiVisible = false
        end
    end
end)

print('[HazeAC NUI] Client-side bridge loaded')
