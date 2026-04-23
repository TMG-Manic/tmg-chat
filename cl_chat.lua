local chatInputActive = false
local chatInputActivating = false
local chatHidden = false
local isRDR = GetGameName() == 'rdr3'

-- Open Chat Command
RegisterCommand('chat_open', function()
    if not chatInputActive and not chatHidden then
        chatInputActive = true
        chatInputActivating = true
        
        SendNUIMessage({
            type = 'ON_OPEN'
        })
    end
end, false)

-- Register Key Mapping (The Performance Fix)
-- This replaces the constant per-frame loop with a native engine listener.
RegisterKeyMapping('chat_open', 'Open Chat', 'keyboard', 'T')

-- Handling NUI Focus (Optimized Thread)
Citizen.CreateThread(function()
    SetTextChatEnabled(false)
    SetNuiFocus(false, false)

    while true do
        Wait(100) -- Check state every 100ms instead of every frame
        
        if chatInputActivating then
            SetNuiFocus(true, true)
            chatInputActivating = false
        end

        if not chatInputActive then
            Wait(400) -- Sleep the thread longer when chat is idle
        end
    end
end)

-- NUI Callbacks
RegisterNUICallback('chatResult', function(data, cb)
    chatInputActive = false
    SetNuiFocus(false, false)

    if not data.canceled and data.message then
        local message = data.message
        if string.sub(message, 1, 1) == "/" then
            ExecuteCommand(string.sub(message, 2))
        else
            TriggerServerEvent('_chat:messageEntered', GetPlayerName(PlayerId()), { r, g, b }, message)
        end
    end

    cb('ok')
end)

RegisterNUICallback('loaded', function(data, cb)
    TriggerServerEvent('chat:init')
    cb('ok')
end)

-- Message Events
RegisterNetEvent('chat:addMessage')
AddEventHandler('chat:addMessage', function(message)
    SendNUIMessage({
        type = 'ON_MESSAGE',
        message = message
    })
end)

RegisterNetEvent('chat:addTemplate')
AddEventHandler('chat:addTemplate', function(id, html)
    SendNUIMessage({
        type = 'ON_TEMPLATE',
        templateId = id,
        html = html
    })
end)

RegisterNetEvent('chat:addSuggestion')
AddEventHandler('chat:addSuggestion', function(name, help, params)
    SendNUIMessage({
        type = 'ON_SUGGESTION_ADD',
        suggestion = {
            name = name,
            help = help,
            params = params or nil
        }
    })
end)

RegisterNetEvent('chat:removeSuggestion')
AddEventHandler('chat:removeSuggestion', function(name)
    SendNUIMessage({
        type = 'ON_SUGGESTION_REMOVE',
        name = name
    })
end)

RegisterNetEvent('chat:clear')
AddEventHandler('chat:clear', function()
    SendNUIMessage({
        type = 'ON_CLEAR'
    })
end)

-- Command to hide chat (Useful for Cinematics)
RegisterCommand('hidechat', function()
    chatHidden = not chatHidden
    SendNUIMessage({
        type = 'ON_SCREEN_STATE_CHANGE',
        shouldHide = chatHidden
    })
end)