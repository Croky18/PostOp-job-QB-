local QBCore = exports['qb-core']:GetCoreObject()
local isWorking = false
local currentStep = 0
local spawnedVehicle = nil
local currentBlip = nil
local hasNotified = false

CreateThread(function()
    local model = GetHashKey(Config.NPC.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local ped = CreatePed(0, model, Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z - 1, Config.NPC.heading, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    local blip = AddBlipForCoord(Config.NPC.coords)
    SetBlipSprite(blip, 569)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 28)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("PostOp Job")
    EndTextCommandSetBlipName(blip)

    local npcCoords = vector3(Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z)

    CreateThread(function()
        while true do
            Wait(0)
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - npcCoords)

            if distance < 2.0 then
                DrawText3D(npcCoords.x, npcCoords.y, npcCoords.z + 1.0, "[E] Open Menu")
                if IsControlJustReleased(0, 38) then
                    lib.registerContext({
                        id = 'delivery_job_menu',
                        title = 'Post OP',
                        options = {
                            {
                                title = 'Start delivery',
                                description = 'Begin met pakketjes ophallen',
                                icon = 'truck',
                                onSelect = function()
                                    TriggerEvent('delivery_job:start')
                                end
                            },
                            {
                                title = 'Stop Delivery',
                                description = 'Stop met ophallen',
                                icon = 'xmark',
                                disabled = not isWorking,
                                onSelect = function()
                                    TriggerEvent('delivery_job:stop')
                                end
                            }
                        }
                    })
                    lib.showContext('delivery_job_menu')
                end
            end
        end
    end)
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

RegisterNetEvent("delivery_job:start", function()
    if isWorking then 
        return QBCore.Functions.Notify("Je bent al aan het werk!", "error") 
    end

    local player = QBCore.Functions.GetPlayerData()
    if player.job.name ~= Config.RequiredJob then
        return QBCore.Functions.Notify("Geen toegang tot deze baan.", "error")
    end

    QBCore.Functions.Notify("Voertuig spawnt...", "success")

    local vehicleModel = GetHashKey(Config.Vehicle.model)
    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Wait(500)
    end

    spawnedVehicle = CreateVehicle(vehicleModel, Config.Vehicle.spawnPoint.x, Config.Vehicle.spawnPoint.y, Config.Vehicle.spawnPoint.z, Config.Vehicle.spawnPoint.w, true, false)
    SetVehicleOnGroundProperly(spawnedVehicle)
    SetEntityAsMissionEntity(spawnedVehicle, true, true)

    if not DoesEntityExist(spawnedVehicle) then
        QBCore.Functions.Notify("Er is een probleem met het voertuig.", "error")
        return
    end

    isWorking = true
    currentStep = 1
    GoToNextLocation()
end)

function GoToNextLocation()
    if currentBlip then RemoveBlip(currentBlip) end
    if currentStep > #Config.Locations then
        QBCore.Functions.Notify("Breng het voertuig terug", "primary")
        SetGpsBlipForReturn()
        return
    end

    local coords = Config.Locations[currentStep]
    currentBlip = AddBlipForCoord(coords)
    SetBlipRoute(currentBlip, true)

    CreateThread(function()
        while isWorking do
            Wait(0)
            local playerCoords = GetEntityCoords(PlayerPedId())
            if #(playerCoords - coords) < 2.0 then
                if not hasNotified then
                    QBCore.Functions.Notify("Druk op [E] om het te Legen!", "success")
                    hasNotified = true 
                end

                if IsControlJustPressed(0, 38) then
                    TaskStartScenarioInPlace(PlayerPedId(), "PROP_HUMAN_BUM_BIN", 0, true)
                    local success = StartProgress(9000, "Bezig met legen...")

                    ClearPedTasks(PlayerPedId())
                    if success then
                        local randomReward = math.random(Config.RewardPerWindow.min, Config.RewardPerWindow.max)  -- Willekeurig bedrag tussen min en max
                        TriggerServerEvent("deliveryjob:addMoney", randomReward)
                        QBCore.Functions.Notify("Je hebt €" .. randomReward .. " verdiend door pakketten op te halen.", "success")
                    
                        currentStep = currentStep + 1
                    
                        GoToNextLocation()
                    end
                    break
                end
            else
                if hasNotified then
                    hasNotified = false
                end
            end
        end
    end)
end

function SetGpsBlipForReturn()
    if not Config.VehicleReturn or not Config.VehicleReturn.x or not Config.VehicleReturn.y or not Config.VehicleReturn.z then
        print("Error: VehicleReturn-coördinaten zijn niet ingesteld in de Config.")
        return
    end

    currentBlip = AddBlipForCoord(Config.VehicleReturn.x, Config.VehicleReturn.y, Config.VehicleReturn.z)
    SetBlipRoute(currentBlip, true)

    CreateThread(function()
        while true do
            Wait(500)

            local playerCoords = GetEntityCoords(PlayerPedId())
            local distanceToReturn = #(playerCoords - vector3(Config.VehicleReturn.x, Config.VehicleReturn.y, Config.VehicleReturn.z))

            if distanceToReturn < 2.0 then
                QBCore.Functions.Notify("Ga terug naar de NPC om de taak te stoppen.", "success")
                RemoveBlip(currentBlip)
                break
            end
        end
    end)
end

function StartProgress(duration, label)
    if Config.Progressbar == 'qs' then
        local result = exports['qs-interface']:ProgressBar({
            duration = duration,
            label = label,
            position = 'bottom',
            canCancel = false
        })
        return result
    else
        local finished = exports['qb-progressbar']:Progress({
            name = "deliveryjob",
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = false,
            controlDisables = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }
        })
        return finished
    end
end

RegisterNetEvent("delivery_job:stop", function()
    if not isWorking then return QBCore.Functions.Notify("Je werkt niet.", "error") end

    if DoesEntityExist(spawnedVehicle) then
        DeleteVehicle(spawnedVehicle)
    end

    isWorking = false
    currentStep = 0
    if currentBlip then RemoveBlip(currentBlip) end
    QBCore.Functions.Notify("Einde van de klus.", "primary")
end)