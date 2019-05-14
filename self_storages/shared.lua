locations = {
    ["bctp"] = {
        fee = 50, name = "Blaine County Tractor Parts", size = 40000, cost = 1000000,
        storage_locations = {
            {x = 388.36904907227, y = 3586.8146972656, z = 33.29222869873},
        }
    },
    ["pbsf"] = {
        fee = 200, name = "Paleto Bay Self Storage", size = 60000, cost = 1000000,
        storage_locations = {
            {x = 46.444091796875, y = 6458.7602539063, z = 31.425287246704},
        }
    },
    ["bhsl"] = {
        fee = 100, name = "Big House Storage LSIA", size = 250000, cost = 1000000,
        storage_locations = {
            {x = -512.517578125, y = -2200.123046875, z = 6.3940262794495},
        }
    },
    ["tsu"] = {
        fee = 200, name = "The Secure Unit", size = 80000, cost = 1000000,
        storage_locations = {
            {x = 911.31066894531, y = -1256.2835693359, z = 25.5778465271},
        }
    },
    ["dpss"] = {
        fee = 100, name = "Del Perro Self Storage", size = 80000, cost = 1000000,
        storage_locations = {
            {x = -1614.7346191406, y = -821.41516113281, z = 10.070293426514},
        }
    },
}

function ReadableNumber(num, places)
    local ret
    local placeValue = ("%%.%df"):format(places or 0)
    if not num then
        return 0
    elseif num >= 1000000000000 then
        ret = placeValue:format(num / 1000000000000) .. " Tril" -- trillion
    elseif num >= 1000000000 then
        ret = placeValue:format(num / 1000000000) .. " Bil" -- billion
    elseif num >= 1000000 then
        ret = placeValue:format(num / 1000000) .. " Mil" -- million
    elseif num >= 1000 then
        ret = placeValue:format(num / 1000) .. "k" -- thousand
    else
        ret = num -- hundreds
    end
    return ret
end
