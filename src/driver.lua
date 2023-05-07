JSON = require ('drivers-common-public.module.json')
WebSocket = require ('drivers-common-public.module.websocket')

do	--Globals
	OPC = OPC or {}
	EC = EC or {}
	RFP = RFP or {}
	Tuya = {}
	PersistData["Scenes"] = PersistData["Scenes"] or {}
	DeviceID = nil
	ProxyID = nil
	info = {}
    ScanResult = {}
end

function dbg (strDebugText, ...)
     if (Properties["Debug Mode"] == 'On') then
		DEBUGPRINT = true
	end

	if (DEBUGPRINT) then print (os.date ('%x %X : ')..(strDebugText or ''), ...) end
end

--Driver Inits

function OnDriverInit()
	C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=false})
end

function OnDriverLateInit()

     dbg("On driver late init...")
	
	DeviceID = C4:GetDeviceID()
	ProxyID = C4:GetProxyDevicesById(DeviceID)

    Tuya.GetDeviceInfo()

end

--[[--
RECEIVED FROM PROXY
--]]--

function ReceivedFromProxy (idBinding, strCommand, tParams)
	strCommand = strCommand or ''
	tParams = tParams or {}
	local args = {}
	if (tParams.ARGS) then
		local parsedArgs = C4:ParseXml(tParams.ARGS)
		for _, v in pairs(parsedArgs.ChildNodes) do
			args[v.Attributes.name] = v.Value
		end
		tParams.ARGS = nil
	end
	if (DEBUGPRINT) then
		local output = {"--- ReceivedFromProxy: "..idBinding, strCommand, "----PARAMS----"}
		for k, v in pairs(tParams) do table.insert(output, tostring(k).." = "..tostring(v)) end
		table.insert(output, "-----ARGS-----")
		for k, v in pairs(args) do table.insert(output, tostring(k).." = "..tostring(v)) end
		table.insert(output, "---")
		print (table.concat(output, "\r\n"))
	end
     local success, ret
	--strProperty = string.gsub (strProperty, '%s+', '_')
	if (RFP and RFP [strCommand] and type (RFP [strCommand]) == 'function') then
		success, ret = pcall (RFP [strCommand], tParams)
	end
	if (success == true) then
		return (ret)
	elseif (success == false) then
		print ('ReceivedFromProxy Lua error: ', strCommand, ret)
	end
end

function RFP.RAMP_TO_LEVEL(tParams)

    level = tParams["LEVEL"]
	defaultMode = Tuya.GetColorMode()

    dbg("Ramping to "..level)
	
	Tuya.SetLevel(level, defaultMode)
	
end

function RFP.SET_LEVEL(tParams)

    level = tParams["LEVEL"]
	defaultMode = Tuya.GetColorMode()

    dbg("Setting level to "..level.." in mode "..defaultMode)
	
	Tuya.SetLevel(level, defaultMode)
	
end

function RFP.ON()
     Tuya.Power("on")
end

function RFP.OFF()
     Tuya.Power("off")
end

function RFP.BUTTON_ACTION(tParams)

    buttonId = tonumber(tParams["BUTTON_ID"])
	buttonAction = tonumber(tParams["ACTION"])
	
	--dbg("button id: "..buttonId)
	--dbg("button action: "..buttonAction)

     if (buttonId == 0) then -- Top
	
	   if (buttonAction == 1) then -- Press
		  Tuya.Power("on")
	   
	   elseif (buttonAction == 0) then -- Release

	   end
	   
	
	elseif (buttonId == 1) then -- Bottom
	
	   if (buttonAction == 1) then -- Press
	   
		  Tuya.Power("off")
	   
	   elseif (buttonAction == 0) then -- Release
	   
	   end
	
	elseif (buttonId == 2) then -- Toggle
	
	   if (buttonAction == 1) then -- Press
	   
		  Tuya.Power("toggle")
	   
	   elseif (buttonAction == 0) then -- Release
	   
	   end
	
	end

end

function RFP.SET_PRESET_LEVEL(tParams)

     PersistData["PRESET_LEVEL"] = tParams["LEVEL"]

end

function RFP.SET_CLICK_RATE_UP(tParams)

     PersistData["CLICK_RATE_UP"] = tParams["RATE"]

end

function RFP.SET_CLICK_RATE_DOWN(tParams)

     PersistData["CLICK_RATE_DOWN"] = tParams["RATE"]

end

function RFP.SET_COLOR_TARGET(tParams)

     Tuya.SetColor(tParams)

end

function RFP.PUSH_SCENE(tParams)

     SceneID = tonumber(tParams["SCENE_ID"])

     PersistData["Scenes"][SceneID] = tParams

end

function RFP.ACTIVATE_SCENE(tParams)

    SceneID = tParams["SCENE_ID"]

    elements = PersistData["Scenes"][tonumber(SceneID)]["ELEMENTS"]
	elements = C4:ParseXml(elements)
	
	data = {}
	
	for k,v in pairs(elements.ChildNodes) do
	    data[v["Name"]] = v["Value"]
    end
	
    if (data["colorEnabled"] == "True") then
	
	   dbg("Color mode enabled")
	   colorData = {}
	   colorData["LIGHT_COLOR_TARGET_X"] = data["colorX"]
	   colorData["LIGHT_COLOR_TARGET_Y"] = data["colorY"]
	   colorData["LIGHT_COLOR_TARGET_MODE"] = data["colorMode"]
	   --colorData["RATE"] = data["colorRate"]
	   
	   Tuya.SetColor(colorData)
	
    end

	if (data["brightnessEnabled"] == "True") then
	 
		dbg("Brightness mode enabled")
 
		if (data["colorEnabled"] == "True") then
			mode = "color"
		else
			mode = "white"
		end
		
		Tuya.SetLevel(data["brightness"],mode)
 
	 end

end

--[[--
EXECUTE COMMAND
--]]--

function ExecuteCommand (strCommand, tParams)
	tParams = tParams or {}
    if (DEBUGPRINT) then
        local output = {"--- ExecuteCommand", strCommand, "----PARAMS----"}
        for k, v in pairs(tParams) do
            table.insert(output, tostring(k).." = "..tostring(v))
        end
        table.insert(output, "---")
        print (table.concat(output, "\r\n"))
    end
    if (strCommand == "LUA_ACTION") then
        if (tParams.ACTION) then
            strCommand = tParams.ACTION
            tParams.ACTION = nil
        end
    end
    local success, ret
    strCommand = string.gsub(strCommand, "%s+", "_")
    if (EC and EC[strCommand] and type(EC[strCommand]) == "function") then
        success, ret = pcall(EC[strCommand], tParams)
    end
    if (success == true) then
        return (ret)
    elseif (success == false) then
        print ("ExecuteCommand Lua error: ", strCommand, ret)
    end
end

--Device Scan

function EC.scan_devices()
    dbg("Scanning devices...")
    Tuya.GetURL("/scan","scan")
end

function EC.populate_devices()
    dbg("Populating devices...")
    Tuya.GetURL("/scanresult","scan")
end

function Tuya.ScanCallback(response)
    data = JSON:decode(response)
    ScanResult = data

    devices = ""

    for ip,data in pairs(data) do
        id = data["id"]
        key = data["key"]
        name = data["name"] or "No Name"

        device = name.." ("..ip..")"

        devices = devices..device..","
    end

    devices = devices:sub(1, -2)

	C4:UpdatePropertyList("Device Selector", devices)
end

--[[--
ON PROPERTY CHANGED
--]]--

function OnPropertyChanged (strProperty)
	local value = Properties [strProperty]
	if (value == nil) then
		value = ''
	end
	if (DEBUGPRINT) then
		local output = {"--- OnPropertyChanged: "..strProperty, value}
		print (output)
	end
	local success, ret
	strProperty = string.gsub (strProperty, '%s+', '_')
	if (OPC and OPC [strProperty] and type (OPC [strProperty]) == 'function') then
		success, ret = pcall (OPC [strProperty], value)
	end
	
	dbg("Property "..strProperty.." changed to "..value)
	
	if (success == true) then
		return (ret)
	elseif (success == false) then
		print ('OnPropertyChanged Lua error: ', strProperty, ret)
	end
end

function OPC.Debug_Mode (value)
	if (DEBUGPRINT) then
		DEBUGPRINT = false
	end
	if (value == 'On') then
		DEBUGPRINT = true
	end
end

function OPC.Device_Selector(value)

    for ip,data in pairs(data) do
        if string.find(value,ip) then
            id = data["id"]
            key = data["key"]
            name = data["name"]
            ver = data["version"]
        
            print("Setting device: "..name)
        
            --Update Properties
            C4:UpdateProperty("Device Name",name)
            C4:UpdateProperty("Device ID",id)
            C4:UpdateProperty("Device Key",key)
            C4:UpdateProperty("Device IP",ip)
            C4:UpdateProperty("Device Version",ver)

			--Rename Driver
			C4:RenameDevice(ProxyID, name)
            
            Tuya.PostURL("/state",{},"GetDeviceInfo")

        end
    end
end

--[[--
MAIN FUNCTIONS
--]]--

function Tuya.GetDeviceInfo()
	Tuya.PostURL("/state",{},"GetDeviceInfo")
	C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=false})
end

function Tuya.Power(state)

    dbg("Setting Tuya power to "..state)

    currentState = tonumber(C4:GetVariable(ProxyID, 1000))
	
	defaultLevel = C4:GetVariable(ProxyID, 1006) or 100

	defaultMode = Tuya.GetColorMode()

    if (state == "on") then
	   Tuya.SetLevel(defaultLevel, defaultMode)
	elseif (state == "off") then
	   Tuya.SetLevel(0, defaultMode)
	elseif (state == "toggle") then
	    dbg("Current state: "..currentState)
	   if (currentState ~= 0) then
		  Tuya.SetLevel(0, defaultMode)
	   else
		  Tuya.SetLevel(defaultLevel, defaultMode)
	   end
	end


end

function Tuya.SetDevice(data)

	data = JSON:decode(data)
	data = data["attributes"]

	dbg("Setting device online and updating dynamic capabilites...")

	C4:SendToProxy(5001, "ONLINE_CHANGED", {STATE=true})

    --Update Dynamic Capabilities

    DynamicCapabilities = {}

    if (data["has_brightness"]) then
        DynamicCapabilities["dimmmer"] = true
		DynamicCapabilities["set_level"] = true
    else
        DynamicCapabilities["dimmmer"] = false
		DynamicCapabilities["set_level"] = false
    end

    if (data["has_colour"]) then
        DynamicCapabilities["supports_color"] = true
    else
        DynamicCapabilities["supports_color"] = false
    end

    if (data["has_colourtemp"]) then
        DynamicCapabilities["supports_color_correlated_temperature"] = true
    else
        DynamicCapabilities["supports_color_correlated_temperature"] = false
    end

	dbg("Dynamic Capabilities:")
	for name,val in pairs(DynamicCapabilities) do
		if (val) then
			val = "true"
		else
			val = "false"
		end
		dbg(name..": "..val)
	end

    C4:SendToProxy(5001, "DYNAMIC_CAPABILITIES_CHANGED", DynamicCapabilities)

end

function Tuya.SetLevel(level, mode)
	
	mode = Tuya.GetColorMode()

	PostData = {
		mode = mode,
		brightness = tonumber(level)
	}

	CurrentColor = C4:GetDeviceVariable(ProxyID,1200)
	x,y,z = CurrentColor:match("([^,]+),([^,]+),([^,]+)")

	if (mode == "color") then
		r,g,b = C4:ColorXYtoRGB(x,y)
		PostData["color"] = r..","..g..","..b
	elseif (mode == "white") then
		k = C4:ColorXYtoCCT(x,y)
		PostData["temp"] = k
	end
	
	Tuya.PostURL("/control",PostData,"SetLevel")
	
	dataToSend = {
	    LIGHT_BRIGHTNESS_CURRENT = level
    }
	
	dbg("Setting level to "..level)
	
	C4:SendToProxy(5001,"LIGHT_BRIGHTNESS_CHANGED",dataToSend)

end

function Tuya.SetColor(tParams)
	
	x1 = tParams["LIGHT_COLOR_TARGET_X"]
	y1 = tParams["LIGHT_COLOR_TARGET_Y"]
	
	mode = tonumber(tParams["LIGHT_COLOR_TARGET_MODE"])
	--rate = tParams["RATE"] or tParams["LIGHT_COLOR_TARGET_RATE"]
	
	CurrentLevel = tonumber(C4:GetVariable(ProxyID, 1001))
	
	if (mode == 0) then

	    r1,g1,b1 = C4:ColorXYtoRGB(x1,y1)

		color = r1..","..g1..","..b1

		PostData = {
			mode = "color",
			color = color,
			brightness = CurrentLevel
		}
	    
	    dbg("Setting color to "..r1..","..g1..","..b1)
	
    else
	    k = C4:ColorXYtoCCT (x1, y1)

		--Convert to percent
		--3800 is diff between temps in driver.xml
		--2700 is min temp
		pct = ((k-2700)/3800)*100
	    
	    PostData = {
			mode = "white",
			temp = pct,
			brightness = CurrentLevel
		}

	    dbg("Setting temperature to "..k)
	    
     end
	
	Tuya.PostURL("/control",PostData,"SetColor")
	
	dataToSend = {

	   LIGHT_COLOR_CURRENT_X = x1,
	   LIGHT_COLOR_CURRENT_Y = y1,
	   LIGHT_COLOR_CURRENT_COLOR_MODE = mode,

    }

	
	C4:SendToProxy(5001,"LIGHT_COLOR_CHANGED",dataToSend)

end

function Tuya.GetColorMode()
	
	mode = C4:GetDeviceVariable(ProxyID,1201)

	dbg("Getting current mode: "..mode)

	if (mode == "1") then
		return "white"
	elseif (mode == "0") then
		return "color"
	end

end

--URL Handlers

function Tuya.GetURL(uri,source)

	urls = {}
	
	table.insert(urls,Properties["Server Address"]..uri)
	
	for i,url in pairs(urls) do
	
	    dbg ("---Get URL---")
	    dbg ("URL: "..url)
	    C4:urlGet(url, {}, false,
		    function(ticketId, strData, responseCode, tHeaders, strError)
			    if (strError == nil) then
				    strData = strData or ''
				    responseCode = responseCode or 0
				    tHeaders = tHeaders or {}
				    if (responseCode == 0) then
					    print("FAILED retrieving: "..url.." Error: "..strError)
				    end
				    if (strData == "") then
					    print("FAILED -- No Data returned")
				    end
				    if (responseCode == 200) then
					    dbg ("SUCCESS retrieving: "..url.." Response: "..strData)
					    
					    if (source == "GetDeviceInfo") then
						  Tuya.SetDevice(strData)
					    end

                        if (source == "scan") then
                            Tuya.ScanCallback(strData)
                        end
					    
				    end
			    else
				    print("C4:urlGet() failed: "..strError)
			    end
		    end
	    )
	
	end

end

function Tuya.PostURL(uri,data,source)

    baseUrl = Properties["Server Address"]
	url = baseUrl..uri

	newData = {
		id = Properties["Device ID"],
		key = Properties["Device Key"],
		ip = Properties["Device IP"],
		ver = Properties["Device Version"]
	}

	if (uri == "/control") then
		newData["cmd"] = data
	end

	--Convert table to string if needed
	if (type(newData) == "table") then
		newData = JSON:encode(newData)
	end

	dbg ("---Post URL---")
	dbg ("URL: "..url)
	dbg ("Posting data: "..newData)
	C4:urlPost(url, newData, {["Content-Type"] = "application/json"})
	
	function ReceivedAsync(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				strData = strData or ''
				responseCode = responseCode or 0
				tHeaders = tHeaders or {}
				if (responseCode == 0) then
					print("FAILED retrieving: "..url.." Error: "..strError)
				end
				if (strData == "") then
					print("FAILED -- No Data returned")
				end
				if (responseCode == 200) then
					dbg ("SUCCESS retrieving: "..url.." Response: "..strData)
					
					if (source == "GetDeviceInfo") then
					   Tuya.SetDevice(strData)
				     end
					
				end
			else
				print("C4:urlPost() failed: "..strError)
			end
     end

end

--[[--
OTHER FUNCTIONS
--]]--

function rgb_to_hex(r, g, b)
    --%02x: 0 means replace " "s with "0"s, 2 is width, x means hex
	return string.format("%02x%02x%02x", 
		math.floor(r),
		math.floor(g),
		math.floor(b))
end

function __genOrderedIndex(t)
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex, cmp_multitype )
    return orderedIndex
end

function orderedNext(t, state)
    local key = nil
    if state == nil then
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        for i = 1,table.getn(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    t.__orderedIndex = nil
    return
end

function orderedPairs(t)
    return orderedNext, t, nil
end