local blip_data = {
    id = 50,
    color = 4,
}

function SetBlipName(blip, name)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name)
    EndTextCommandSetBlipName(blip)
end

local function useOrigin()
    return true
end

function DrawText3D(text, x, y, z, s, font, a)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px, py, pz, x, y, z, 1)

    if s == nil then
        s = 1.0
    end
    if font == nil then
        font = 4
    end
    if a == nil then
        a = 255
    end

    local scale = ((1 / dist) * 2) * s
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = scale * fov

    if onScreen then
        if useOrigin() then
            SetDrawOrigin(x, y, z, 0)
        end
        SetTextScale(0.0 * scale, 1.1 * scale)
        if useOrigin() then
            SetTextFont(font)
        else
            SetTextFont(font)
        end
        SetTextProportional(1)
        -- SetTextScale(0.0, 0.55)
        SetTextColour(255, 255, 255, a)
        -- SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        if useOrigin() then
            DrawText(0.0, 0.0)
            ClearDrawOrigin()
        else
            DrawText(_x, _y)
        end
    end
end

RegisterNetEvent("omni:self_storage:add")
AddEventHandler("omni:self_storage:add", function(data)
    local uqid = data.id
    if data.area then
        uqid = uqid .. ":" .. data.area
    end
    locations[uqid] = {
        fee = data.fee, name = data.name, size = data.size, cost = 5000000000,
        id = data.id,
        hidden = data.hidden,
        storage_locations = {
            {x = data.pos.x, y = data.pos.y, z = data.pos.z},
        },
    }
end)

Citizen.CreateThread(function()
    while true do
        Wait(0)
        local ped = GetPlayerPed(-1)
        local pos = GetEntityCoords(ped)
        local veh = GetVehiclePedIsIn(ped, true)
        for id, location in next, locations do
            for _,coords in next, location.storage_locations do
                if not coords.blip and not location.hidden then
                    coords.blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                    SetBlipAsShortRange(coords.blip, true)
                    SetBlipSprite(coords.blip, blip_data.id)
                    SetBlipColour(coords.blip, blip_data.color)
                    SetBlipScale(coords.blip, 1.0)
                    SetBlipName(coords.blip, "Self Storage")
                    exports['blip_info']:SetBlipInfoTitle(coords.blip, "Self Storage", false)
                    exports['blip_info']:AddBlipInfoName(coords.blip, "Location", location.name)
                    exports['blip_info']:AddBlipInfoText(coords.blip, "Capacity", (location.size * 10) .. " kg")
                    exports['blip_info']:AddBlipInfoText(coords.blip, "Fee", "$" .. location.fee)
                end
                local dist = #(vector3(pos.x, pos.y, pos.z) - vector3(coords.x, coords.y, coords.z))
                if dist < 30.0 then
                    if dist > 3.0 then
                        DrawText3D("~y~Self Storage | ~g~$" .. location.fee.." ~y~fee~n~~w~" .. location.name, coords.x, coords.y, coords.z + 1.5, 1.5)
                    else
                        DrawText3D("~w~Press ~g~E ~w~to open the ~y~Self Storage", coords.x, coords.y, coords.z + 1.5, 1.5)
                        if IsControlJustPressed(0, 38) and not IsPedInVehicle(ped, veh, true) then
                            TriggerServerEvent("omni:self_storage:open", location.id or id)
                        end
                    end
                    DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 4.0, 4.0, 1.0, 255, 255, 255, 20)
                end
            end
        end
    end
end)
