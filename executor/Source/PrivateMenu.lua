local PrivateMenu = {}

---Keep every category in one menu module while feature controllers stay separate.
---@param hub table
---@return table
function PrivateMenu.pages(hub)
	local config = hub.config
	local ui = hub.ui
	local function toggle(name, title, hint)
		ui:toggle(title, config[name], function(value) return hub:setFlag(name, value) end, hint)
	end
	local function slider(name, title, low, high, step, suffix, default)
		ui:slider(title, low, high, config[name], function(value)
			config[name] = value
			hub:onSettingChanged(name)
		end, function(value)
			return string.format(step < 1 and "%.2f" or "%d", value) .. (suffix or "")
		end, step, default)
	end
	return {
		{
			id = "home", label = "home", subtitle = "overview", keywords = "private server quick controls",
			render = function()
				ui:section("private session", "client-only tools · game-owned actions may be rejected")
				ui:info("place", game.PlaceId)
				ui:info("players", #hub.playersService:GetPlayers())
				slider("aimFov", "aim fov", 35, 350, 1, " px", 145)
				slider("movementSpeed", "movement speed", 16, 120, 1, " studs/s", 26)
				toggle("aimlock", "aimlock", "camera follows a selected player")
				toggle("playerEsp", "player esp")
				ui:section("quick actions", "stop all below disables every active mode")
				ui:action("request free pickups", "known candidate items; game decides access", function()
					hub:report(hub.inventory:getFreeWeapons())
				end, true)
				ui:action("open combat", nil, function() ui:selectPage("combat") end)
				ui:action("open teleport", nil, function() ui:selectPage("teleport") end)
			end,
		},
		{
			id = "combat", label = "combat", subtitle = "targeting", keywords = "aimbot aimlock silent aim rage bot taze arrest gun",
			render = function()
				ui:section("targeting", "camera assistance · shot-packet support is unverified")
				toggle("aimbot", "aimbot", "hold the aim key or use the touch switch")
				toggle("aimlock", "aimlock")
				toggle("silentAim", "silent aim", "only a recognized gun shot packet is changed")
				ui:info("shot status", hub.combat.shotStatus)
				ui:info("packets seen", hub.combat.shotsSeen)
				ui:info("packets changed", hub.combat.shotsChanged)
				ui:action("refresh shot status", nil, function() ui:refreshPage() end)
				toggle("rageBot", "rage bot", "aims camera and activates an equipped gun at a capped rate")
				toggle("autoTaze", "auto taze & arrest", "game taser / arrest remote; criminals only")
				toggle("teamCheck", "team check")
				toggle("wallCheck", "visibility check")
				ui:toggle("touch / manual aim", hub.combat.aimHeld, function(value)
					hub.combat.aimHeld = value
					return true
				end)
				slider("aimFov", "aim fov", 35, 350, 1, " px", 145)
				slider("aimSmooth", "aim smoothing", 0.04, 1, 0.01, "", 0.22)
				ui:action("aim part · " .. config.aimPart, "head / root part", function()
					config.aimPart = config.aimPart == "Head" and "HumanoidRootPart" or "Head"
					ui:refreshPage()
				end)
				ui:action("fire equipped tool", nil, function() hub:report(hub.combat:activate()) end, true)
				ui:section("target selection", "tap a player to track them explicitly")
				ui:action("closest to cursor", nil, function()
					hub.targeting.selected = nil
					ui:refreshPage()
				end)
				for _, player in ipairs(hub.playersService:GetPlayers()) do
					if player ~= hub.localPlayer then
						ui:action((hub.targeting.selected == player and "• " or "") .. player.DisplayName,
							"@" .. player.Name, function()
								hub.targeting.selected = player
								ui:refreshPage()
							end)
					end
				end
				ui:section("gun modification", "local gunstates only; server may reject stat changes")
				slider("gunDamage", "damage", 1, 100, 1, "", 30)
				slider("gunInterval", "fire interval", 0.05, 1, 0.01, "s", 0.15)
				slider("gunSpread", "spread", 0, 8, 0.1, "", 0)
				ui:action("apply to equipped gun", nil, function()
					hub:report(hub.inventory:modifyEquippedGun())
				end)
			end,
		},
		{
			id = "visuals", label = "visuals", subtitle = "esp", keywords = "player esp vehicle esp labels distance",
			render = function()
				ui:section("local visuals", "highlights and distance labels; no drawing api required")
				toggle("playerEsp", "player esp", "outline other players")
				toggle("vehicleEsp", "vehicle esp", "outline models containing a vehicle seat")
				ui:action("refresh visible objects", nil, function()
					hub.visuals:configure()
					hub:notify("esp refreshed", true)
				end)
			end,
		},
		{
			id = "movement", label = "movement", subtitle = "physics", keywords = "speed fly noclip infinite jump anti stun",
			render = function()
				ui:section("movement", "client-side movement may be corrected by the server")
				toggle("speedEnabled", "speed", "holds a configured walkspeed")
				slider("movementSpeed", "movement speed", 16, 120, 1, " studs/s", 26)
				toggle("fly", "fly", "movement keys or joystick; up/down buttons on mobile")
				slider("flySpeed", "flight speed", 12, 100, 1, " studs/s", 45)
				toggle("noclip", "noclip")
				toggle("infiniteJump", "infinite jump")
				toggle("antiStun", "anti-stun", "locally clears platformstand if this game uses it")
				ui:action("stop all modes", nil, function() hub:stopAll() end)
			end,
		},
		{
			id = "teleport", label = "teleport", subtitle = "travel", keywords = "players locations bookmark quick menu",
			render = function()
				ui:section("quick teleport", "local character teleports may be corrected by the server")
				local locations = hub.travel:listLocations()
				if #locations == 0 then ui:info("locations", "none detected; save a bookmark") end
				for _, entry in ipairs(locations) do
					ui:action(entry.name, entry.kind, function()
						hub.travel.selected = entry
						hub:report(hub.travel:teleport(entry.cframe))
					end)
				end
				ui:section("custom locations", "bookmarks last until this hub is reinjected")
				ui:textInput("name", "bookmark name", function(text) hub.bookmarkName = text end)
				ui:action("save current position", nil, function()
					local success, message = hub.travel:save(hub.bookmarkName)
					hub:notify(message, success)
					if success then ui:refreshPage() end
				end, true)
				ui:section("players", "teleport near another player in this private server")
				for _, player in ipairs(hub.playersService:GetPlayers()) do
					if player ~= hub.localPlayer then
						ui:action(player.DisplayName, "@" .. player.Name, function()
							hub:report(hub.travel:toPlayer(player))
						end)
					end
				end
			end,
		},
		{
			id = "vehicles", label = "vehicles", subtitle = "garage", keywords = "vehicle esp spawn speed handling entry teleport",
			render = function()
				ui:section("vehicle lab", "only occupied / network-owned seats can be tuned")
				toggle("vehicleEsp", "vehicle esp")
				ui:action("quick vehicle entry", "use the nearest unoccupied seat", function()
					hub:report(hub.vehicles:quickEntry())
				end)
				ui:action("try nearby spawn control", "only if the map has a supported prompt", function()
					hub:report(hub.vehicles:triggerSpawn())
				end)
				slider("vehicleSpeed", "vehicle speed", 10, 120, 1, " studs/s", 45)
				slider("vehicleHandling", "handling", 0.5, 4, 0.1, "", 2)
				ui:action("apply speed & handling", nil, function()
					hub:report(hub.vehicles:tune())
				end, true)
				ui:action("teleport occupied vehicle", "choose a location in the teleport tab first", function()
					hub:report(hub.vehicles:teleportSelected())
				end)
			end,
		},
		{
			id = "tools", label = "tools", subtitle = "armory", keywords = "weapons free gun player server information",
			render = function()
				ui:section("weapon pickups", "game remotes are resolved only if the current map has them")
				ui:action("request known free pickups", "candidate list; game decides whether to grant", function()
					hub:report(hub.inventory:getFreeWeapons())
				end, true)
				local catalog = hub.inventory:catalog()
				local available, restricted = 0, 0
				for _, entry in ipairs(catalog) do
					if entry.free then
						available += 1
						ui:action("request · " .. entry.name, "free candidate; server decides", function()
							hub:report(hub.inventory:getWeapon(entry))
						end)
					else restricted += 1 end
				end
				if available == 0 then ui:info("free candidates", "none found in the current map") end
				if restricted > 0 then ui:info("other pickups", restricted .. " omitted; may require access") end
				ui:section("players", "read-only information")
				for _, player in ipairs(hub.playersService:GetPlayers()) do
					ui:info(player.DisplayName, "@" .. player.Name .. " · " .. player.UserId)
				end
				ui:section("server", "official private server information")
				ui:info("place id", game.PlaceId)
				ui:info("players", #hub.playersService:GetPlayers())
				ui:info("private id", game.PrivateServerId:sub(1, 12) .. "…")
			end,
		},
		{
			id = "settings", label = "settings", subtitle = "profile", keywords = "keybind save load defaults compact emergency",
			render = function()
				ui:section("interface", "native ui works on mobile and desktop")
			toggle("compact", "compact mode")
				ui:section("keybinds", "escape cancels · mobile uses on-screen controls")
				for _, pair in ipairs({{"toggle window", "menuKey"}, {"hold aim", "aimKey"}, {"fire tool", "fireKey"},
					{"emergency stop", "stopKey"}, {"flight up", "flightUpKey"}, {"flight down", "flightDownKey"}}) do
					local label, key = pair[1], pair[2]
					ui:keybind(label, config[key], function(value)
						return hub:setKeybind(key, value)
					end)
				end
				ui:section("configuration", "executor file storage when available; in-memory otherwise")
				ui:action("save configuration", nil, function() hub:report(hub:saveConfig()) end, true)
				ui:action("load configuration", nil, function()
					hub:report(hub:loadConfig())
					ui:refreshPage()
				end)
				ui:action("restore defaults", "reset controls and all keybinds", function() hub:restoreDefaults() end)
				ui:action("stop all modes", config.stopKey:lower() .. " · emergency stop", function() hub:stopAll() end)
				ui:action("unload hub", "remove ui, modes, esp, and shot handler", function() hub:destroy() end)
				ui:info("scope", "official prison life private server only")
			end,
		},
	}
end

return PrivateMenu
