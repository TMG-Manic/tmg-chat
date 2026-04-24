local chatInputActive = false
local chatInputActivating = false
local chatLoaded = false
local chatHidden = false
local currentResourceName = GetCurrentResourceName()
local isRDR = GetGameName() == 'rdr3'

local function UsePreSecurityBehavior()
    return GetConvar('sysresource_chat_disableOriginSecurityChecks', 'true') == 'true'
end

RegisterCommand('chat_open', function()
    if not chatInputActive and not IsPauseMenuActive() then
        chatInputActive = true
        chatInputActivating = true
        SendNUIMessage({ type = 'ON_OPEN' })
    end
end, false)

RegisterKeyMapping('chat_open', 'Open Chat', 'keyboard', 'T')

RegisterNetEvent('__cfx_internal:serverPrint')
AddEventHandler('__cfx_internal:serverPrint', function(msg)
    print(msg) -- Print to F8 console
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

local addMessage = function(message)
    if type(message) == 'string' then message = { args = { message } } end
    SendNUIMessage({ type = 'ON_MESSAGE', message = message })
end
exports('addMessage', addMessage)
AddEventHandler('chat:addMessage', addMessage)

RegisterNetEvent('chatMessage')
AddEventHandler('chatMessage', function(author, color, text)
    local args = { text }
    if author ~= "" then table.insert(args, 1, author) end
    SendNUIMessage({
        type = 'ON_MESSAGE',
        message = { color = color, multiline = true, args = args }
    })
end)

AddEventHandler('chat:addTemplate', function(id, html)
    SendNUIMessage({ type = 'ON_TEMPLATE_ADD', template = { id = id, html = html } })
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

local function refreshCommands()
    if GetRegisteredCommands then
        local registeredCommands = GetRegisteredCommands()
        local suggestions = {}
        for _, command in ipairs(registeredCommands) do
            if IsAceAllowed(('command.%s'):format(command.name)) then
                table.insert(suggestions, { name = '/' .. command.name, help = '' })
            end
        end
        TriggerEvent('chat:addSuggestions', suggestions)
    end
end

local function refreshThemes()
    local themes = {}
    for resIdx = 0, GetNumResources() - 1 do
        local resource = GetResourceByFindIndex(resIdx)
        if GetResourceState(resource) == 'started' then
            local themeName = GetResourceMetadata(resource, 'chat_theme')
            if themeName then
                local themeData = json.decode(GetResourceMetadata(resource, 'chat_theme_extra') or 'null')
                if themeData then
                    themeData.baseUrl = 'nui://' .. resource .. '/'
                    themes[themeName] = themeData
                end
            end
        end
    end
    SendNUIMessage({ type = 'ON_UPDATE_THEMES', themes = themes })
end

RegisterRawNuiCallback('chatResult', function(requestData, cb)
    local resource = requestData.resource
    local securityDisabled = UsePreSecurityBehavior()
    if resource == nil and not securityDisabled then return end
    
    chatInputActive = false
    SetNuiFocus(false, false)
    
    local data = json.decode(requestData.body)
    if not data.canceled and data.message then
        if data.message:sub(1, 1) == '/' then
            if resource == currentResourceName or securityDisabled then
                ExecuteCommand(data.message:sub(2))
            end
        else
            TriggerServerEvent('_chat:messageEntered', GetPlayerName(PlayerId()), { 0, 153, 255 }, data.message, data.mode)
        end
    end
    cb({ body = 'ok' })
end)

RegisterNUICallback('loaded', function(data, cb)
    TriggerServerEvent('chat:init')
    refreshCommands()
    refreshThemes()
    chatLoaded = true
    cb('ok')
end)

Citizen.CreateThread(function()
    SetTextChatEnabled(false)
    SetNuiFocus(false, false)

    while true do
        local sleep = 250 -- Check states every 250ms (0.00ms Resmon)

        if chatInputActivating then
            SetNuiFocus(true, true)
            chatInputActivating = false
            sleep = 0
        end

        if chatLoaded then
            local shouldHide = IsScreenFadedOut() or IsPauseMenuActive()
            if shouldHide ~= chatHidden then
                chatHidden = shouldHide
                SendNUIMessage({
                    type = 'ON_SCREEN_STATE_CHANGE',
                    shouldHide = chatHidden
                })
            end
        end

        if chatInputActive then sleep = 0 end
        Wait(sleep)
    end
end)

AddEventHandler('onClientResourceStart', function(resName)
    Wait(500)
    refreshCommands()
    refreshThemes()
end)
