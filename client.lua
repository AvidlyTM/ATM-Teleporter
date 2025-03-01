local hasAlreadyEnteredMarker, currentMarker = false, nil
local PromptGroup = GetRandomIntInRange(0, 0xffffff)
local UseDoorPrompt

-- Check if Config is loaded
if not Config or not Config.Doors or not Config.PromptKey then
    return
end

-- Setup door prompt
function SetupUseDoorPrompt()
    Citizen.CreateThread(function()
        local str = 'Use Door'
        UseDoorPrompt = PromptRegisterBegin()
        PromptSetControlAction(UseDoorPrompt, Config.PromptKey)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(UseDoorPrompt, str)
        PromptSetEnabled(UseDoorPrompt, 0) -- Disabled by default
        PromptSetVisible(UseDoorPrompt, 0) -- Hidden by default
        PromptSetHoldMode(UseDoorPrompt, true)
        PromptSetGroup(UseDoorPrompt, PromptGroup)
        PromptRegisterEnd(UseDoorPrompt)
    end)
end

-- Function to get player's job using VORP
local function GetPlayerJob()
    local player = PlayerId()
    local job = exports.vorp_inventory:getUserJob(player)
    return job or "citizen" -- Default to "citizen" if job retrieval fails
end

-- Check if player has required job
local function HasRequiredJob(allowedJobs)
    if not allowedJobs or #allowedJobs == 0 then
        return true -- No job restriction
    end
    
    local playerJob = GetPlayerJob()
    print("[atm-teleporter] Player Job: " .. tostring(playerJob))
    print("[atm-teleporter] Allowed Jobs: " .. table.concat(allowedJobs, ", "))
    for _, job in ipairs(allowedJobs) do
        if playerJob == job then
            return true
        end
    end
    print("[atm-teleporter] No job match.")
    return false
end

-- Main loop to check for nearby doors
Citizen.CreateThread(function()
    SetupUseDoorPrompt()
    while true do
        Citizen.Wait(500)
        local player = PlayerPedId()
        local coords = GetEntityCoords(player)
        local isInMarker, tempMarker = false

        for k, v in pairs(Config.Doors) do
            local distEnter = #(coords - v.enter)
            local distExit = #(coords - v.exit)
            if distEnter < Config.MarkerDistance or distExit < Config.MarkerDistance then
                isInMarker = true
                tempMarker = k
            end
        end

        if isInMarker and not hasAlreadyEnteredMarker then
            hasAlreadyEnteredMarker = true
            currentMarker = tempMarker
            MarkerLoop(currentMarker)
        elseif not isInMarker and hasAlreadyEnteredMarker then
            hasAlreadyEnteredMarker = false
            currentMarker = nil
            PromptSetEnabled(UseDoorPrompt, 0)
            PromptSetVisible(UseDoorPrompt, 0)
        end
    end
end)

-- Handle door interaction
function MarkerLoop(markerIndex)
    Citizen.CreateThread(function()
        local door = Config.Doors[markerIndex]
        while currentMarker == markerIndex do
            Wait(0)
            local player = PlayerPedId()
            local coords = GetEntityCoords(player)
            
            local distEnter = #(coords - door.enter)
            local distExit = #(coords - door.exit)
            
            
            if distEnter >= Config.TriggerDistance and distExit >= Config.TriggerDistance then
                PromptSetEnabled(UseDoorPrompt, 0)
                PromptSetVisible(UseDoorPrompt, 0)
                print("[atm-teleporter] Outside trigger distance, disabling prompt.")
            elseif HasRequiredJob(door.allowedJobs) then
                -- Check if near enter point
                if distEnter < Config.TriggerDistance and distEnter < distExit then
                    print("[atm-teleporter] Near Enter point, showing prompt.")
                    PromptSetEnabled(UseDoorPrompt, 1)
                    PromptSetVisible(UseDoorPrompt, 1)
                    local label = CreateVarString(10, 'LITERAL_STRING', door.name .. " - Enter")
                    PromptSetActiveGroupThisFrame(PromptGroup, label)
                    if PromptHasHoldModeCompleted(UseDoorPrompt) then
                        DoScreenFadeOut(Config.FadeTime)
                        Wait(Config.FadeTime)
                        SetEntityCoords(player, door.exit.x, door.exit.y, door.exit.z)
                        Wait(Config.FadeTime)
                        DoScreenFadeIn(Config.FadeTime)
                        Wait(100)
                        PromptSetEnabled(UseDoorPrompt, 0)
                        PromptSetVisible(UseDoorPrompt, 0)
                    end
                -- Check if near exit point
                elseif distExit < Config.TriggerDistance and distExit < distEnter then
                    print("[atm-teleporter] Near Exit point, showing prompt.")
                    PromptSetEnabled(UseDoorPrompt, 1)
                    PromptSetVisible(UseDoorPrompt, 1)
                    local label = CreateVarString(10, 'LITERAL_STRING', door.name .. " - Exit")
                    PromptSetActiveGroupThisFrame(PromptGroup, label)
                    if PromptHasHoldModeCompleted(UseDoorPrompt) then
                        DoScreenFadeOut(Config.FadeTime)
                        Wait(Config.FadeTime)
                        SetEntityCoords(player, door.enter.x, door.enter.y, door.enter.z)
                        Wait(Config.FadeTime)
                        DoScreenFadeIn(Config.FadeTime)
                        Wait(100)
                        PromptSetEnabled(UseDoorPrompt, 0)
                        PromptSetVisible(UseDoorPrompt, 0)
                    end
                else
                    PromptSetEnabled(UseDoorPrompt, 0)
                    PromptSetVisible(UseDoorPrompt, 0)
                    print("[atm-teleporter] Not at enter or exit, disabling prompt.")
                end
            else
                if distEnter < Config.TriggerDistance or distExit < Config.TriggerDistance then
                    print("[atm-teleporter] Restricted access.")
                    local label = CreateVarString(10, 'LITERAL_STRING', "Restricted Access - Requires: " .. table.concat(door.allowedJobs or {}, ", "))
                    PromptSetActiveGroupThisFrame(PromptGroup, label)
                else
                    PromptSetEnabled(UseDoorPrompt, 0)
                    PromptSetVisible(UseDoorPrompt, 0)
                    print("[atm-teleporter] Restricted and outside range, disabling prompt.")
                end
            end
        end
        PromptSetEnabled(UseDoorPrompt, 0)
        PromptSetVisible(UseDoorPrompt, 0)
        print("[atm-teleporter] Exited MarkerLoop, disabling prompt.")
    end)
end