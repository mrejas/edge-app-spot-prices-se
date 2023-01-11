--
--

local edge = require("edge")
last_processed_date = nil

function findFunctionMeta(meta)
        functions, err = lynx.apiCall("GET", "/api/v2/functionx/" .. app.installation_id)
        local match = 1
        for i, dev in ipairs(functions) do
                match = 1;
                for k, v in pairs(meta) do
                        if dev.meta[k] ~= v then
                                match = 0
                        end
                end
                if match == 1 then
                        return functions[i]
                end
        end
        return nil;
end

function findDeviceMeta(meta)
        devices, err = lynx.apiCall("GET", "/api/v2/devicex/" .. app.installation_id)
        local match = 1
        for i, dev in ipairs(devices) do
                match = 1;
                for k, v in pairs(meta) do
                        if dev.meta[k] ~= v then
                                match = 0
                        end
                end
                if match == 1 then
                        return devices[i]
                end
        end
        return nil;
end

function create_function_if_needed(area, device)
	local func = findFunctionMeta({
		spot_market_area = area
	})

	if func == nil then
		fn = {
			type = "spot price",
			installation_id = app.installation_id,
			meta = {
				name = "Spot proice - " .. area,
				spot_market_area = area,
				device_id = tostring(device),
				unit = "SEK/kWh",
				format = "%0.4f SEK/kWh",
				topic_read = "obj/spot/" .. area .. "/sek" 
			}
		}
	end

	lynx.createFunction(fn)
end

function setup_device(device) 
	local dev = findDeviceMeta({
		device_type = "Spotprice electricity",
		credits = "mgrey.se"
	})

	if dev == nil then
		print("Creating device")
		local _dev = {
			type = "spotprices",
			installation_id = app.installation_id,
			meta = {
				name = "Spotpriser",
				device_type = "Spotprice electricity",
				credits = "mgrey.se"
			}
		}
		
		lynx.apiCall("POST", "/api/v2/devicex/" .. app.installation_id , _dev)

		dev = findDeviceMeta({
			device_type = "Spotprice electricity",
			credits = "mgrey.se"
		})
	end
	return dev
end

function fetchAndSend(date) 
	local http_request = require "http.request"
	local url = "https://mgrey.se/espot?format=json&date=" .. date
	local headers, stream = assert(http_request.new_from_uri(url):go())
	local body = assert(stream:get_body_as_string())
	if headers:get ":status" ~= "200" then
	    -- error(body)
	    print("Could not fetch " .. url)
	    return nil
	end

	local data, err = json:decode(body)

	date = data.date;
 
	local xyear = string.sub(date, 1, 4) 
	local xmonth = string.sub(date, 6, 7) 
	local xday = string.sub(date, 9, 10) 


	local convertedTimestamp = os.time({year = xyear, month = xmonth, day = xday, hour = 0, min = 0, sec = 0})  

	if cfg.SE1 == "yes" then
		print("Sending: SE1 " .. os.date("%Y-%m-%d", convertedTimestamp))
		local topic_read = "obj/spot/SE1/sek" 
		create_function_if_needed("SE1", device_id)
		for i, price in ipairs(data.SE1) do
  			timestamp = convertedTimestamp + ( price.hour * 3600 )
  			value = price.price_sek / 100
			local data = json:encode({ timestamp = timestamp, value = value })
			mq:pub(topic_read, data);
		end
	else
		print("Skipping: SE1")
	end

	if cfg.SE2 == "yes" then
		print("Sending: SE2 " .. os.date("%Y-%m-%d", convertedTimestamp))
		local topic_read = "obj/spot/SE2/sek" 
		create_function_if_needed("SE2", device_id)
		for i, price in ipairs(data.SE2) do
	  		timestamp = convertedTimestamp + ( price.hour * 3600 )
	  		value = price.price_sek / 100
			local data = json:encode({ timestamp = timestamp, value = value })
			mq:pub(topic_read, data);
		end
	else
		print("Skipping: SE2")
	end

	if cfg.SE3 == "yes" then
		print("Sending: SE3 " .. os.date("%Y-%m-%d", convertedTimestamp))
		local topic_read = "obj/spot/SE3/sek" 
		create_function_if_needed("SE3", device_id)
		for i, price in ipairs(data.SE3) do
	  		timestamp = convertedTimestamp + ( price.hour * 3600 )
	  		value = price.price_sek / 100
			local data = json:encode({ timestamp = timestamp, value = value })
			mq:pub(topic_read, data);
		end
	else
		print("Skipping: SE3")
	end


	if cfg.SE4 == "yes" then
		print("Sending: SE4 " .. os.date("%Y-%m-%d", convertedTimestamp))
		local topic_read = "obj/spot/SE4/sek" 
		create_function_if_needed("SE4", device_id)
		for i, price in ipairs(data.SE4) do
	  		timestamp = convertedTimestamp + ( price.hour * 3600 )
	  		value = price.price_sek / 100
			local data = json:encode({ timestamp = timestamp, value = value })
			mq:pub(topic_read, data);
		end
	else
		print("Skipping: SE4")
	end

end

function sendData()
	fetchAndSend(os.date("%Y-%m-%d"))
	fetchAndSend(os.date("%Y-%m-%d", os.time()+24*3600))

end

function onStart()
	print("Starting")
	device = setup_device(cfg.device);
	device_id = device.id

	sendData()
	local t = timer:interval(3600, sendData)
end
