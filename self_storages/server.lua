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

                if vRP.hasPermission({user_id, "premium.storage_features"}) then
                    menudata["<span sort='b' style='color:green'>Dump from Trunk</span>"] = {function(player)
                        vRPclient.getNearbyOwnedVehicles(player, {25}, function(b, vehs)
                            if b and #vehs > 0 then
                                local vehSelectionMenu = {name = "Select Vehicle Trunk"}
                                for _, veh in next, vehs do
                                    vehSelectionMenu[veh[3]] = {function(player)
                                        local itemsMoved = 0
                                        local itemsToPayFor = 0
                                        local trunkName = "chest:u"..user_id.."veh_"..veh[1].."_"..string.lower(veh[2])
                                        vRP.getSData({"chest:" .. chestName, function(ssJson)
                                            local STORAGE_DATA = {}
                                            STORAGE_DATA.items = json.decode(ssJson) or {} -- load items
                                            vRP.getSData({trunkName, function(trunkJson)
                                                local TRUNK_DATA = {}
                                                TRUNK_DATA.items = json.decode(trunkJson) or {} -- load items
                                                local trunkWeight = vRP.computeItemsWeight({TRUNK_DATA.items})
                                                local storageWeight = vRP.computeItemsWeight({STORAGE_DATA.items})
                                                local size = vRP.getActualChestSize({user_id, size})
                                                if storageWeight + trunkWeight > size * 10.0 then
                                                    vRPclient.notify(player, {"~r~Storage full"})
                                                else
                                                    for itemId, itemData in next, TRUNK_DATA.items do
                                                        if vRP.isValidItem({itemId}) then
                                                            itemsMoved = itemsMoved + itemData.amount
                                                            if vRP.getItemWeight({itemId}) > 0.0 then
                                                                itemsToPayFor = itemsToPayFor + itemData.amount
                                                                chest_put(itemId, itemData.amount)
                                                            end
                                                            if not STORAGE_DATA.items[itemId] then
                                                                STORAGE_DATA.items[itemId] = {amount = itemData.amount}
                                                            else
                                                                STORAGE_DATA.items[itemId].amount = STORAGE_DATA.items[itemId].amount + itemData.amount
                                                            end
                                                            TRUNK_DATA.items[itemId] = nil
                                                        end
                                                    end

                                                    vRPclient.notify(player, {("~y~Self Storage: ~w~Moved %s items"):format(itemsMoved)})

                                                    vRP.setSData({"chest:" .. chestName, json.encode(STORAGE_DATA.items)})
                                                    vRP.setSData({trunkName, json.encode(TRUNK_DATA.items)})
                                                    vRP.closeMenu({player})
                                                end
                                            end})
                                        end})
                                    end, ""}
                                end
                                vRP.openMenu({player, vehSelectionMenu})
                            else
                                vRPclient.notify(player, {"~r~No owned vehicle nearby"})
                            end
                        end)
                    end, "[Premium] Dump an entire trunk into the storage unit"}
                end

                if vRP.hasPermission({user_id, "premium.storage_features"}) then
                    menudata["<span sort='c' style='color:green'>Take to Trunk</span>"] = {function(player)
                        vRPclient.getNearbyOwnedVehicles(player, {25}, function(b, vehs)
                            if b and #vehs > 0 then
                                local vehSelectionMenu = {name = "Select Vehicle Trunk"}
                                for _, veh in next, vehs do
                                    vehSelectionMenu[veh[3]] = {function(player)
                                        local TRUNK_SIZE = vRP.getTrunkSize({veh[2]})
                                        TRUNK_SIZE = vRP.getActualChestSize({user_id, TRUNK_SIZE})
                                        local trunkName = "chest:u"..user_id.."veh_"..veh[1].."_"..string.lower(veh[2])
                                        vRP.getSData({"chest:" .. chestName, function(ssJson)
                                            local STORAGE_DATA = {}
                                            STORAGE_DATA.items = json.decode(ssJson) or {} -- load items
                                            vRP.getSData({trunkName, function(trunkJson)
                                                local TRUNK_DATA = {}
                                                local block = false
                                                TRUNK_DATA.items = json.decode(trunkJson) or {} -- load items
                                                local trunkWeight = vRP.computeItemsWeight({TRUNK_DATA.items})
                                                local storageWeight = vRP.computeItemsWeight({STORAGE_DATA.items})

                                                -- Move amount to trunk
                                                local ch_take = function(idname)
                                                    local item = STORAGE_DATA.items[idname]
                                                    if item then
                                                        vRP.prompt({player, "Amount to take to trunk (Max " .. item.amount .. ")", "", function(player, amount)
                                                            local amount = vRP.parseInt({amount})
                                                            if amount > 0 and amount <= item.amount then
                                                                local weight = vRP.getItemWeight({idname})
                                                                local total_weight = weight * amount
                                                                local remaining_weight = TRUNK_SIZE - trunkWeight
                                                                if total_weight <= remaining_weight then
                                                                    TRUNK_DATA.items[idname] = TRUNK_DATA.items[idname] or {}
                                                                    TRUNK_DATA.items[idname].amount = (TRUNK_DATA.items[idname].amount or 0) + amount
                                                                    STORAGE_DATA.items[idname].amount = STORAGE_DATA.items[idname].amount - amount
                                                                    if STORAGE_DATA.items[idname].amount <= 0 then
                                                                        STORAGE_DATA.items[idname] = nil
                                                                    end
                                                                    vRP.setSData({"chest:" .. chestName, json.encode(STORAGE_DATA.items)})
                                                                    vRP.setSData({trunkName, json.encode(TRUNK_DATA.items)})
                                                                    vRPclient.notify(player, {"Moved " .. amount .. " items to the trunk"})
                                                                    vRP.closeMenu({player})
                                                                else
                                                                    vRPclient.notify(player, {"~r~Trunk full"})
                                                                end
                                                            else
                                                                vRPclient.notify(player, {"~r~Invalid amount"})
                                                            end
                                                        end})
                                                    end
                                                end

                                                -- Move stack to trunk, maybe add auto-take max?
                                                local ch_take_stack = function(idname)
                                                    if not block then
                                                        block = true
                                                    else
                                                        return false
                                                    end
                                                    local item = STORAGE_DATA.items[idname]
                                                    if item then
                                                        local amount = item.amount
                                                        local weight = vRP.getItemWeight({idname})

                                                        local remaining_weight = TRUNK_SIZE - trunkWeight
                                                        if weight > 0.0 then
                                                            local max_items = math.floor(remaining_weight / weight)
                                                            amount = math.min(max_items, amount)
                                                        end
                                                        local total_weight = weight * amount

                                                        if total_weight <= remaining_weight and amount > 0 then
                                                            TRUNK_DATA.items[idname] = TRUNK_DATA.items[idname] or {}
                                                            TRUNK_DATA.items[idname].amount = (TRUNK_DATA.items[idname].amount or 0) + amount
                                                            STORAGE_DATA.items[idname].amount = STORAGE_DATA.items[idname].amount - amount
                                                            if STORAGE_DATA.items[idname].amount <= 0 then
                                                                STORAGE_DATA.items[idname] = nil
                                                            end
                                                            vRP.setSData({"chest:" .. chestName, json.encode(STORAGE_DATA.items)})
                                                            vRP.setSData({trunkName, json.encode(TRUNK_DATA.items)})
                                                            vRPclient.notify(player, {"Moved " .. amount .. " items to the trunk"})
                                                            vRP.closeMenu({player})
                                                        else
                                                            block = false
                                                            vRPclient.notify(player, {"~r~Trunk full"})
                                                        end
                                                    end
                                                end

                                                local submenu = vRP.buildItemlistMenu({"Take to Trunk", STORAGE_DATA.items, ch_take, ch_take_stack})
                                                vRP.openMenu({player, submenu})
                                            end})
                                        end})
                                    end, ""}
                                end
                                vRP.openMenu({player, vehSelectionMenu})
                            else
                                vRPclient.notify(player, {"~r~No owned vehicle nearby"})
                            end
                        end)
                    end, "[Premium] Move items directly from the storage into a trunk"}
                end

                if vRP.hasPermission({user_id, "transfer.self_storage"}) then
                    menudata["<span sort='d' style='color:orange'>Transfer to Player</span>"] = {function(player)
                        local plySelectionMenu = {name = "Select a Player"}
                        local plys = vRP.getUsers({})
                        for uid, ply in next, plys do
                            local plyName = GetPlayerName(ply)
                            if uid ~= user_id and not vRP.isUserIronMan({uid}) and not vRP.isUserIronMan({user_id}) then
                                plySelectionMenu[uid .. " " .. plyName] = {function(player)
                                    local TRUNK_SIZE = size * 10.0
                                    TRUNK_SIZE = vRP.getActualChestSize({user_id, TRUNK_SIZE})
                                    local trunkName = "self_storage:"..uid..":" .. name .. ":chest"
                                    vRP.getSData({"chest:" .. chestName, function(ssJson)
                                        local STORAGE_DATA = {}
                                        STORAGE_DATA.items = json.decode(ssJson) or {} -- load items
                                        vRP.getSData({"chest:" .. trunkName, function(trunkJson)
                                            local TRUNK_DATA = {}
                                            local block = false
                                            TRUNK_DATA.items = json.decode(trunkJson) or {} -- load items
                                            local trunkWeight = vRP.computeItemsWeight({TRUNK_DATA.items})
                                            local storageWeight = vRP.computeItemsWeight({STORAGE_DATA.items})

                                            -- Move amount to trunk
                                            local ch_take = function(idname)
                                                local item = STORAGE_DATA.items[idname]
                                                if item and vRP.isItemTradeable({idname}) then
                                                    vRP.prompt({player, "Amount to transfer (Max " .. item.amount .. ")", "", function(player, amount)
                                                        local amount = vRP.parseInt({amount})
                                                        if amount > 0 and amount <= item.amount then
                                                            local weight = vRP.getItemWeight({idname})
                                                            local total_weight = weight * amount
                                                            local remaining_weight = TRUNK_SIZE - trunkWeight
                                                            if total_weight <= remaining_weight then
                                                                TRUNK_DATA.items[idname] = TRUNK_DATA.items[idname] or {}
                                                                TRUNK_DATA.items[idname].amount = (TRUNK_DATA.items[idname].amount or 0) + amount
                                                                STORAGE_DATA.items[idname].amount = STORAGE_DATA.items[idname].amount - amount
                                                                if STORAGE_DATA.items[idname].amount <= 0 then
                                                                    STORAGE_DATA.items[idname] = nil
                                                                end
                                                                if vRP.isChestOpen({trunkName}) or vRP.isChestOpen({chestName}) then
                                                                    vRPclient.notify(player, {"~r~Failed to read/write to chest"})
                                                                else
                                                                    if vRP.isValidItem({idname}) then
                                                                        if vRP.getItemWeight({idname}) > 0.0 then
                                                                            chest_put(idname, amount)
                                                                        end
                                                                    end
                                                                    vRP.setSData({"chest:" .. chestName, json.encode(STORAGE_DATA.items)})
                                                                    vRP.setSData({"chest:" .. trunkName, json.encode(TRUNK_DATA.items)})
                                                                    vRPclient.notify(player, {"Moved " .. amount .. " items to " .. plyName})
                                                                    vRPclient.notify(ply, {GetPlayerName(player) .. " transfered " .. amount .. "x " .. vRP.getItemName({idname}) .. " to your " .. title .. " storage"})
                                                                end
                                                                vRP.closeMenu({player})
                                                            else
                                                                vRPclient.notify(player, {"~r~Storage full"})
                                                            end
                                                        else
                                                            vRPclient.notify(player, {"~r~Invalid amount"})
                                                        end
                                                    end})
                                                else
                                                    vRPclient.notify(player, {"~r~This item can not be traded"})
                                                end
                                            end

                                            -- Move stack to trunk, maybe add auto-take max?
                                            local ch_take_stack = function(idname)
                                                if not block then
                                                    block = true
                                                else
                                                    return false
                                                end
                                                local item = STORAGE_DATA.items[idname]
                                                if item and vRP.isItemTradeable({idname}) then
                                                    local amount = item.amount
                                                    local weight = vRP.getItemWeight({idname})

                                                    local remaining_weight = TRUNK_SIZE - trunkWeight
                                                    if weight > 0.0 then
                                                        local max_items = math.floor(remaining_weight / weight)
                                                        amount = math.min(max_items, amount)
                                                    end
                                                    local total_weight = weight * amount

                                                    if total_weight <= remaining_weight and amount > 0 then
                                                        TRUNK_DATA.items[idname] = TRUNK_DATA.items[idname] or {}
                                                        TRUNK_DATA.items[idname].amount = (TRUNK_DATA.items[idname].amount or 0) + amount
                                                        STORAGE_DATA.items[idname].amount = STORAGE_DATA.items[idname].amount - amount
                                                        if STORAGE_DATA.items[idname].amount <= 0 then
                                                            STORAGE_DATA.items[idname] = nil
                                                        end
                                                        if vRP.isChestOpen({trunkName}) or vRP.isChestOpen({chestName}) then
                                                            vRPclient.notify(player, {"~r~Failed to read/write to chest, is it already open?"})
                                                        else
                                                            if vRP.isValidItem({idname}) then
                                                                if vRP.getItemWeight({idname}) > 0.0 then
                                                                    chest_put(idname, amount)
                                                                end
                                                            end
                                                            vRP.setSData({"chest:" .. chestName, json.encode(STORAGE_DATA.items)})
                                                            vRP.setSData({"chest:" .. trunkName, json.encode(TRUNK_DATA.items)})
                                                            vRPclient.notify(player, {"Moved " .. amount .. " items to " .. plyName})
                                                            vRPclient.notify(ply, {GetPlayerName(player) .. " transfered " .. amount .. "x " .. vRP.getItemName({idname}) .. " to your " .. title .. " storage"})
                                                        end
                                                        vRP.closeMenu({player})
                                                    else
                                                        block = false
                                                        vRPclient.notify(player, {"~r~Storage full"})
                                                    end
                                                else
                                                    vRPclient.notify(player, {"~r~This item can not be traded"})
                                                end
                                            end

                                            local submenu = vRP.buildItemlistMenu({"Transfer to " .. plyName, STORAGE_DATA.items, ch_take, ch_take_stack})
                                            vRP.openMenu({player, submenu})
                                        end})
                                    end})
                                end, "Transfer items to " .. plyName .. ""}
                            end
                        end
                        vRP.openMenu({player, plySelectionMenu})
                    end, "[Transfer] Move items directly to another players storage<br/><em>Untradeable items can not be transfered<br/>Players with Ironman mode can not transfer items<br/>You can not transfer items to Ironman mode players</em>"}
                end



                vRP.openMenu({player, menudata})
                        --(source, name, max_weight, cb_close, cb_in, cb_out, title)
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
