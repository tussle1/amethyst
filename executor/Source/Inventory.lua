local FREE_WEAPONS = PrivateContextModule.FREE_WEAPONS

-- Item pickup calls are only made for actual game pickup objects in the map.
local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(hub)
	return setmetatable({hub = hub, originals = setmetatable({}, {__mode = "k"}),
		pickupPending = false, lastPickup = -math.huge}, Inventory)
end

function Inventory:catalog()
	local items = workspace:FindFirstChild("Prison_ITEMS")
	local result = {}
	if not items then return result end
	for _, folderName in ipairs({"giver", "single"}) do
		local folder = items:FindFirstChild(folderName)
		if folder then
			for _, entry in ipairs(folder:GetChildren()) do
				local pickup = entry:FindFirstChild("ITEMPICKUP")
				if pickup then
					table.insert(result, {name = entry.Name, pickup = pickup, free = FREE_WEAPONS[entry.Name] == true})
				end
			end
		end
	end
	table.sort(result, function(a, b) return a.name < b.name end)
	return result
end

function Inventory:getWeapon(entry)
	if not (entry and entry.free == true and FREE_WEAPONS[entry.name]) then
		return false, "not on the known free-item candidate list"
	end
	local remotes = workspace:FindFirstChild("Remote")
	local handler = remotes and remotes:FindFirstChild("ItemHandler")
	local folder = workspace:FindFirstChild("Prison_ITEMS")
	if not (handler and handler:IsA("RemoteFunction") and folder and entry
		and typeof(entry.pickup) == "Instance" and entry.pickup:IsDescendantOf(folder)) then
		return false, "compatible pickup remote or item not found"
	end
	if self.pickupPending or os.clock() - self.lastPickup < 0.18 then
		return false, "wait for the previous pickup request"
	end
	self.pickupPending, self.lastPickup = true, os.clock()
	local ok, response = pcall(handler.InvokeServer, handler, entry.pickup)
	self.pickupPending = false
	if not ok then return false, "pickup call failed: " .. tostring(response) end
	if response == false then return false, "pickup rejected by the game server" end
	return true, "pickup requested; check backpack for server acceptance"
end

function Inventory:getFreeWeapons()
	local sent, rejected = 0, 0
	local backpack = self.hub.localPlayer:FindFirstChildOfClass("Backpack")
	local character = self.hub.localPlayer.Character
	for _, item in ipairs(self:catalog()) do
		if item.free and sent + rejected < 5
			and not (backpack and backpack:FindFirstChild(item.name))
			and not (character and character:FindFirstChild(item.name)) then
			local ok = self:getWeapon(item)
			if ok then sent += 1 else rejected += 1 end
			task.wait(0.2)
		end
	end
	if sent == 0 then return false, rejected > 0 and "free pickups unavailable or rejected" or "no unowned free pickups found" end
	return true, sent .. " pickup requests sent; check backpack for actual items"
end

function Inventory:modifyEquippedGun()
	local character = self.hub.localPlayer.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local module = tool and tool:FindFirstChild("GunStates")
	if not (module and module:IsA("ModuleScript")) then return false, "equip a gun with gunstates first" end
	local ok, states = pcall(require, module)
	if not ok and type(getthreadidentity) == "function" and type(setthreadidentity) == "function" then
		local idOk, oldIdentity = pcall(getthreadidentity)
		if idOk and pcall(setthreadidentity, 2) then
			ok, states = pcall(require, module)
			pcall(setthreadidentity, oldIdentity)
		end
	end
	if not ok or type(states) ~= "table" or type(states.Damage) ~= "number"
		or type(states.FireRate) ~= "number" or type(states.Spread) ~= "number" then
		return false, "compatible gunstates unavailable in this executor/game"
	end
	if not self.originals[states] then
		self.originals[states] = {Damage = states.Damage, FireRate = states.FireRate, Spread = states.Spread}
	end
	local modified = pcall(function()
		states.Damage = self.hub.config.gunDamage
		states.FireRate = self.hub.config.gunInterval
		states.Spread = self.hub.config.gunSpread
	end)
	if not modified then
		pcall(function()
			for key, value in pairs(self.originals[states]) do states[key] = value end
		end)
		return false, "gunstates are read-only"
	end
	return true, "local gunstates updated; server may ignore these values"
end

function Inventory:restore()
	for states, original in pairs(self.originals) do
		pcall(function()
			for key, value in pairs(original) do states[key] = value end
		end)
	end
	self.originals = setmetatable({}, {__mode = "k"})
end

return Inventory
