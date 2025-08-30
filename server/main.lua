lib.locale()

lib.callback.register('plenix-sell-vehicles:checkCar', function (source, vehicle, vehiclePlate)
    local xPlayer = ESX.GetPlayerFromId(source)

    local response = MySQL.query.await('SELECT owner FROM owned_vehicles WHERE owner = @owner AND plate = @plate LIMIT 1', {
        ['@owner'] = xPlayer.getIdentifier(),
        ['@plate'] = vehiclePlate
    })

    if response then
        if #response > 0 then
            return true
        else
            return false
        end
    else
        return false
    end
end)

lib.callback.register('plenix-sell-vehicles:putOnSale', function(source, money, vehicleProps)
    local xPlayer = ESX.GetPlayerFromId(source)
    local plate = vehicleProps.plate

    local response = MySQL.query.await('SELECT owner, mileage FROM owned_vehicles WHERE owner = @owner AND plate = @plate LIMIT 1', {
        ['@owner'] = xPlayer.getIdentifier(),
        ['@plate'] = plate
    })

    if not response then
        return false
    end

    if #response == 0 then
        return false
    end

    local mileage = response[1].mileage or 0

    MySQL.insert.await('INSERT INTO vehicles_for_sale (seller, vehicleProps, mileage, price) VALUES (@seller, @vehicleProps, @mileage, @price)', {
        ['@seller'] = xPlayer.getIdentifier(),
        ['@vehicleProps'] = json.encode(vehicleProps),
        ['@mileage'] = mileage,
        ['@price'] = money
    })

    MySQL.update.await('DELETE FROM owned_vehicles WHERE plate = @plate', {
        ['@plate'] = plate
    })

    return true
end)

lib.callback.register('plenix-sell-vehicles:getNumberOfCars', function (source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local plate = GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(source), false))

    local result = MySQL.query.await('SELECT COUNT(*) FROM vehicles_for_sale')

    return result
end)

lib.callback.register('plenix-sell-vehicles:getVehicleForSale', function (source, index)
    if index ~= '0' then
        index = tonumber(index)
    else
        index = 0
    end

    if index == nil then
        error("Invalid index")
    end

    local result = MySQL.query.await('SELECT vehicleProps, seller, price FROM vehicles_for_sale LIMIT 1 OFFSET @index', {
        ['@index'] = index
    })

    return result
end)

lib.callback.register('plenix-sell-vehicles:getVehiclesForSale', function (source)
    local result = MySQL.query.await('SELECT * FROM vehicles_for_sale')

    local id = 0
    for k, v in pairs(result) do
        v.id = id
        id = id + 1
    end

    return result
end)

RegisterNetEvent('plenix-sell-vehicles:buyVehicle')
AddEventHandler('plenix-sell-vehicles:buyVehicle', function (index)
    local xPlayer = ESX.GetPlayerFromId(source)

    if index ~= '0' then
        index = tonumber(index)
    else
        index = 0
    end

    if index == nil then
        error("Invalid index")
    end

    local result = MySQL.query.await('SELECT id, seller, vehicleProps, mileage, price FROM vehicles_for_sale LIMIT 1 OFFSET @index', {
        ['@index'] = index
    })

    if result[1] then
        local seller = result[1].seller
        local vehicleProps = json.decode(result[1].vehicleProps)
        local mileage = result[1].mileage
        local price = result[1].price

        if xPlayer.getMoney() >= price then
            xPlayer.removeMoney(price)
            UpdateCash(seller, price - (price * (Config.SellCarTax or 0.1)))

            MySQL.insert.await([[
                INSERT INTO owned_vehicles 
                (owner, plate, vehicle, type, stored, in_garage, stored_in_garage, mileage) 
                VALUES 
                (@owner, @plate, @vehicle, "car", 1, 1, @location, @mileage)
            ]], {
                ['@owner'] = xPlayer.getIdentifier(),
                ['@plate'] = vehicleProps.plate,
                ['@vehicle'] = json.encode(vehicleProps),
                ['@location'] = "Legion Square",
                ['@mileage'] = mileage
            })

            MySQL.update.await('DELETE FROM vehicles_for_sale WHERE id = @id', {
                ['@id'] = result[1].id
            })

            TriggerClientEvent('plenix-sell-vehicles:removedVehicle', -1, index)

            xPlayer.showNotification(locale('vehicle_bought', price))
        else
            xPlayer.showNotification(locale('not_enough_money'))
        end
    end
end)

RegisterNetEvent('plenix-sell-vehicles:returnVehicle')
AddEventHandler('plenix-sell-vehicles:returnVehicle', function (index)
    local xPlayer = ESX.GetPlayerFromId(source)

    if index ~= '0' then
        index = tonumber(index)
    else
        index = 0
    end

    if index == nil then
        error("Invalid index")
    end

    local result = MySQL.query.await('SELECT id, seller, vehicleProps, mileage, price FROM vehicles_for_sale LIMIT 1 OFFSET @index', {
        ['@index'] = index
    })

    if result[1] then
        local seller = result[1].seller
        local vehicleProps = json.decode(result[1].vehicleProps)
        local mileage = result[1].mileage
        if seller ~= xPlayer.getIdentifier() then
            xPlayer.showNotification(locale('not_your_vehicle'))
            return
        end

        MySQL.insert.await([[
            INSERT INTO owned_vehicles 
            (owner, plate, vehicle, type, stored, in_garage, garage_id, mileage) 
            VALUES 
            (@owner, @plate, @vehicle, "car", 1, 1, @location, @mileage)
        ]], {
            ['@owner'] = seller,
            ['@plate'] = vehicleProps.plate,
            ['@vehicle'] = json.encode(vehicleProps),
            ['@location'] = "Legion Square",
            ['@mileage'] = mileage
        })

        MySQL.update.await('DELETE FROM vehicles_for_sale WHERE id = @id', {
            ['@id'] = result[1].id
        })

        TriggerClientEvent('plenix-sell-vehicles:removedVehicle', -1, index)

        xPlayer.showNotification(locale('vehicle_returned'))
    end
end)

function UpdateCash(identifier, cash)
	local xPlayer = ESX.GetPlayerFromIdentifier(identifier)

	if xPlayer ~= nil then
		xPlayer.addAccountMoney("bank", cash)

        xPlayer.showNotification(locale('vehicle_sold', cash))
	else
		MySQL.Async.fetchAll('SELECT accounts FROM users WHERE identifier = @identifier', { ["@identifier"] = identifier }, function(result)
		    if result[1]["accounts"] ~= nil then
	       		local accountsData = json.decode(result[1]["accounts"]) 
        			accountsData["bank"] = accountsData["bank"] + cash

        			MySQL.Async.execute("UPDATE users SET accounts = @newBank WHERE identifier = @identifier",
            		{
                			["@identifier"] = identifier,
                			["@newBank"] = json.encode(accountsData) 
            		})
    		    end
		end)
	end
end

Trim = function(word)
	if word ~= nil then
		return word:match("^%s*(.-)%s*$")
	else
		return nil
	end
end