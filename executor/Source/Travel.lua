local getRig = PrivateContextModule.getRig

-- Travel resolves live map objects; bookmark CFrames are local to this session.
local Travel = {}
Travel.__index = Travel

function Travel.new(hub)
	return setmetatable({hub = hub, bookmarks = {}, selected = nil}, Travel)
end

function Travel:listLocations()
	local result, seen = {}, {}
	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("SpawnLocation") and #result < 12 then
			local name = object.Name == "SpawnLocation" and "spawn · " .. object.TeamColor.Name or object.Name
			if not seen[name] then
				seen[name] = true
				table.insert(result, {name = name, kind = "map spawn", cframe = object.CFrame * CFrame.new(0, 4, 0)})
			end
		end
	end
	for name, destination in pairs(self.bookmarks) do
		table.insert(result, {name = name, kind = "saved location", cframe = destination})
	end
	table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
	return result
end

function Travel:teleport(destination)
	if typeof(destination) ~= "CFrame" then return false, "invalid destination" end
	local character, humanoid, root = getRig(self.hub.localPlayer)
	if not character then return false, "character not ready" end
	local ok, errorMessage = pcall(function()
		humanoid.Sit = false
		character:PivotTo(destination)
		root.AssemblyLinearVelocity = Vector3.zero
	end)
	return ok, ok and "teleported locally; the server may correct this" or tostring(errorMessage)
end

function Travel:toPlayer(player)
	local _, _, root = getRig(player)
	if not root then return false, "player not ready" end
	return self:teleport(root.CFrame * CFrame.new(3, 0, 3))
end

function Travel:save(name)
	local _, _, root = getRig(self.hub.localPlayer)
	if not root then return false, "character not ready" end
	if type(name) ~= "string" then return false, "enter a bookmark name" end
	name = name:lower():match("^%s*(.-)%s*$"):sub(1, 24)
	if name == "" or not name:match("^[%w _%-]+$") then return false, "use letters, numbers, spaces, _ or -" end
	local count = 0
	for _ in pairs(self.bookmarks) do count += 1 end
	if count >= 8 and not self.bookmarks[name] then return false, "eight bookmarks maximum" end
	self.bookmarks[name] = root.CFrame
	return true, "saved " .. name
end

return Travel
