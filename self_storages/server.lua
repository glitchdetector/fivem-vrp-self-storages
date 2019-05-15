local Proxy = module("vrp", "lib/Proxy")
local Tunnel = module("vrp", "lib/Tunnel")

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP","omni_self_storage")

local CHESTS = {}
local CHESTS_OCCUPIED = {}

local function chest_create(player, x, y, z, name, size, title, fee, permissions, area)

    local user_id = vRP.getUserId({player})
    local chestName = "self_storage:"..user_id..":" .. name .. ":chest"
    local permissions = permissions or {}

    local nid = "area:" .. chestName
    if area ~= nil then
        nid = nid..":"..area
    end

    local chest_put = function(idname, amount)
        local weight = vRP.getItemWeight({idname})
        local cost = amount * fee
        if weight > 0.0 then
            if fee > 0.0 then
                if vRP.tryGetInventoryItem({user_id, "storage_card", 1, false}) then
                    vRPclient.notify(player, {("~y~Saved ~g~$%s ~w~by using the Storage Card!"):format(ReadableNumber(cost, 2))})
                else
                    vRP.giveMoney({user_id, -cost})
                    vRPclient.notify(player, {("~y~Self Storage Fee: ~g~$%s ~w~(~y~x%i~w~)"):format(ReadableNumber(cost, 2), amount)})
                end
            end
        end
    end

    local chest_enter = function(player, area)
        local allowed = false
        local user_id = vRP.getUserId({player})
        if user_id then
            if not vRP.hasPermission({user_id, "omni.storage_override"}) and #permissions > 0 then
                for _,perm in next, permissions do
                    if vRP.hasPermission({user_id, perm}) then
                        allowed = true
                    end
                end
            else
                allowed = true
            end
            if allowed then
                local menudata = {}
                menudata.name = title

                menudata["<span sort='a' style='color:orange'>Open Storage</span>"] = {function(player)
                    vRP.openChest({player, chestName, size * 10.0, function() end, chest_put, function() end, title})
                end, "Access the storage unit"}

                vRP.openMenu({player, menudata})
            else
                vRPclient.notify(player, {"~r~You do not have access to this storage unit"})
            end
        end
    end

    local chest_leave = function(player, area)
        vRP.closeMenu({player})
    end
    -- vRP.setArea({player, nid, x, y, z, 2, 4.5, chest_enter, chest_leave})
    if not CHESTS[player] then
        CHESTS[player] = {}
    end
    CHESTS[player][name] = {nid, chest_enter, chest_leave}
end

AddEventHandler("omni:self_storage:add", function(source, data)
    chest_create(source, data.pos.x, data.pos.y, data.pos.z, data.id, data.size, data.name, data.fee, data.permissions, data.area)
    TriggerClientEvent("omni:self_storage:add", source, data)
end)

RegisterServerEvent("omni:self_storage:open")
AddEventHandler("omni:self_storage:open", function(name)
    print("Opening storage " .. name)
    if CHESTS[source] then
        print("Player has storages")
        if CHESTS[source][name] then
            print("Player has storage " .. name)
            CHESTS[source][name][2](source)
        end
    end
end)

function make_chests(source)
    for storageId, storageData in next, locations do
        for _,coords in next, storageData.storage_locations do
            chest_create(source, coords.x, coords.y, coords.z, storageId, storageData.size, storageData.name, storageData.fee, storageData.permissions, coords.area)
        end
    end
end

Citizen.CreateThread(function()
    local users = vRP.getUsers({})
    for user_id, player in next, users do
        make_chests(player)
    end
end)

AddEventHandler("vRP:playerSpawn", function(user_id, source, first_spawn)
    if first_spawn then
        make_chests(source)
    end
end)
