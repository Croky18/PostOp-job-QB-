local QBCore = exports['qb-core']:GetCoreObject()

RegisterServerEvent("deliveryjob:addMoney", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.AddMoney('cash', amount)
    end
end)

RegisterServerEvent("deliveryjob:server:payPlayer", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local amount = math.random(50, 150)
        Player.Functions.AddMoney('cash', amount)
        QBCore.Functions.Notify(src, "Je hebt verdiend €" .. amount .. " voor het voltooien van de taak!", "success")
    end
end)
