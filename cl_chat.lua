local chatInputActive = false
local chatInputActivating = false
local chatLoaded = false
local currentResourceName = GetCurrentResourceName()

-- Visibility States
local CHAT_HIDE_STATES = {
    SHOW_WHEN_ACTIVE = 0,
    ALWAYS_SHOW = 1,
    ALWAYS_HIDE = 2
}

local kvpEntry = GetResourceKvpString('hideState')
local chatHideState = kvpEntry and tonumber(kvpEntry) or CHAT_HIDE_STATES.SHOW_WHEN_ACTIVE
local isFirstHide = true
local lastChatHideState = -1
local origChatHideState = -1

-- ==========================================
--  Security & Utility
-- ==========================================
local function UsePreSecurityBehavior()
    return GetConvar('sysresource_chat_disableOriginSecurityChecks', 'true') == 'true'
end

-- ==========================================
--  Optimization: RegisterKeyMapping (0.00ms)
-- ==========================================
RegisterCommand('chat_open', function()
    if not chatInputActive and not IsPauseMenuActive() then
        chatInputActive = true
        chatInputActivating = true
        SendNUIMessage({ type = 'ON_OPEN' })
    end
end, false)

RegisterKeyMapping('chat_open', 'Open Chat', 'keyboard', 'T')

-- ==========================================
--  Net Event Registration
-- ==========================================
RegisterNetEvent('chat:addMessage')
RegisterNetEvent('chat:addTemplate')
RegisterNetEvent('chat:addSuggestion')
RegisterNetEvent('chat:addSuggestions')
RegisterNetEvent('chat:removeSuggestion')
RegisterNetEvent('chat:clear')
RegisterNetEvent('__cfx_internal:serverPrint')

-- ==========================================
--  Event Handlers
-- ==========================================

AddEventHandler('chat:addMessage', function(message)
    if type(message) == 'string' then message = { args = { message } } end
    -- F8 Console Mirror
    if message.args then print(table.concat(message.args, " ")) end
    SendNUIMessage({ type = 'ON_MESSAGE', message = message })
end)

AddEventHandler('__cfx_internal:serverPrint', function(msg)
    print(msg) 
    SendNUIMessage({
        type = 'ON_MESSAGE',
        message = {
            templateId = 'print',
            multiline = true,
            args = { msg },
            mode = '_global'
        }
    })
end)

AddEventHandler('chat:addSuggestion', function(name, help, params)
    SendNUIMessage({ type = 'ON_SUGGESTION_ADD', suggestion = { name = name, help = help, params = params or nil } })
end)

AddEventHandler('chat:addSuggestions', function(suggestions)
    SendNUIMessage({ type = 'ON_SUGGESTION_ADD', suggestion = suggestions })
end)

AddEventHandler('chat:removeSuggestion', function(name)
    SendNUIMessage({ type = 'ON_SUGGESTION_REMOVE', name = name })
end)

AddEventHandler('chat:clear', function()
    SendNUIMessage({ type = 'ON_CLEAR' })
end)

-- ==========================================
--  Toggle Chat Logic (KVP Support)
-- ==========================================
RegisterCommand('toggleChat', function(source, args)
    if not args[1] then
        if chatHideState == CHAT_HIDE_STATES.SHOW_WHEN_ACTIVE then chatHideState = CHAT_HIDE_STATES.ALWAYS_SHOW
        elseif chatHideState == CHAT_HIDE_STATES.ALWAYS_SHOW then chatHideState = CHAT_HIDE_STATES.ALWAYS_HIDE
        elseif chatHideState == CHAT_HIDE_STATES.ALWAYS_HIDE then chatHideState = CHAT_HIDE_STATES.SHOW_WHEN_ACTIVE end
    else
        if args[1] == "visible" then chatHideState = CHAT_HIDE_STATES.ALWAYS_SHOW
        elseif args[1] == "hidden" then chatHideState = CHAT_HIDE_STATES.ALWAYS_HIDE
        elseif args[1] == "whenactive" then chatHideState = CHAT_HIDE_STATES.SHOW_WHEN_ACTIVE end
    end
    SetResourceKvp('hideState', tostring(chatHideState))
end, false)

-- ==========================================
--  NUI Callbacks
-- ==========================================
RegisterRawNuiCallback('chatResult', function(requestData, cb)
    chatInputActive = false
    SetNuiFocus(false, false)
    local data = json.decode(requestData.body)
    if not data.canceled and data.message then
        if data.message:sub(1, 1) == '/' then
            ExecuteCommand(data.message:sub(2))
        else
            TriggerServerEvent('_chat:messageEntered', GetPlayerName(PlayerId()), { 0, 153, 255 }, data.message, data.mode)
        end
    end
    cb({ body = 'ok' })
end)

RegisterNUICallback('loaded', function(data, cb)
    TriggerServerEvent('chat:init')
    chatLoaded = true
    cb('ok')
end)

-- ==========================================
--  Optimized Background Thread (State Management)
-- ==========================================
Citizen.CreateThread(function()
    SetTextChatEnabled(false)
    SetNuiFocus(false, false)

    while true do
        local sleep = 250 

        if chatInputActivating then
            SetNuiFocus(true, true)
            chatInputActivating = false
            sleep = 0
        end

        if chatLoaded then
            local forceHide = IsScreenFadedOut() or IsPauseMenuActive()
            local wasForceHide = false

            -- Handle temporary force hides (fades/pause)
            if chatHideState ~= CHAT_HIDE_STATES.ALWAYS_HIDE then
                if forceHide then
                    origChatHideState = chatHideState
                    chatHideState = CHAT_HIDE_STATES.ALWAYS_HIDE
                end
            elseif not forceHide and origChatHideState ~= -1 then
                chatHideState = origChatHideState
                origChatHideState = -1
                wasForceHide = true
            end

            -- Update NUI only if state actually changed
            if chatHideState ~= lastChatHideState then
                lastChatHideState = chatHideState
                SendNUIMessage({
                    type = 'ON_SCREEN_STATE_CHANGE',
                    hideState = chatHideState,
                    fromUserInteraction = not forceHide and not isFirstHide and not wasForceHide
                })
                isFirstHide = false
            end
        end

        if chatInputActive then sleep = 0 end
        Wait(sleep)
    end
end)
