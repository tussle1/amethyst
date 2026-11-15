local getRig = PrivateContextModule.getRig

-- Vehicle controls require the occupant's network ownership for physics edits.
local Vehicles = {}
Vehicles.__index = Vehicles

function Vehicles.new(hub)
	return setmetatable({hub = hub, originalSeats = setmetatable({}, {__mode = "k"})}, Vehicles)
end

function Vehicles:nearestSeat(maximum)
	local _, _, root = getRig(self.hub.localPlayer)
	if not root then return nil end
	local closest, distance = nil, maximum
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("VehicleSeat") and not part.Occupant then
			local difference = (root.Position - part.Position).Magnitude
			if difference < distance then closest, distance = part, difference end
		end
	end
	return closest
end

function Vehicles:quickEntry()
	local seat = self:nearestSeat(60)
	local _, humanoid = getRig(self.hub.localPlayer)
	if not (seat and humanoid) then return false, "no nearby available vehicle seat" end
	local moved, message = self.hub.travel:teleport(seat.CFrame * CFrame.new(0, 3, 0))
	if not moved then return false, message end
	local ok = pcall(seat.Sit, seat, humanoid)
	return ok, ok and "entry attempted; server may reject it" or "could not sit in vehicle"
end

function Vehicles:occupiedSeat()
	local _, humanoid = getRig(self.hub.localPlayer)
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Occupant == humanoid then return seat end
	return nil
end

function Vehicles:tune()
	local seat = self:occupiedSeat()
	if not seat then return false, "enter a vehicle first" end
	if type(isnetworkowner) ~= "function" then return false, "executor cannot confirm vehicle physics ownership" end
	local ok, owned = pcall(isnetworkowner, seat)
	if not ok or not owned then return false, "you do not own this vehicle's physics" end
	local saved, original = pcall(function()
		return {MaxSpeed = seat.MaxSpeed, Torque = seat.Torque, TurnSpeed = seat.TurnSpeed}
	end)
	if not saved then return false, "vehicle seat does not support these properties" end
	self.originalSeats[seat] = self.originalSeats[seat] or original
	local baseline = self.originalSeats[seat]
	local applied = pcall(function()
		seat.MaxSpeed = self.hub.config.vehicleSpeed
		seat.Torque = baseline.Torque * self.hub.config.vehicleHandling
		seat.TurnSpeed = baseline.TurnSpeed * self.hub.config.vehicleHandling
	end)
	if not applied then
		pcall(function()
			for key, value in pairs(self.originalSeats[seat]) do seat[key] = value end
		end)
		return false, "game did not allow local vehicle tuning"
	end
	return true, "local vehicle settings applied; server may override them"
end

function Vehicles:teleportSelected()
	local seat = self:occupiedSeat()
	local destination = self.hub.travel.selected
	if not (seat and destination) then return false, "enter a vehicle and choose a location first" end
	if type(isnetworkowner) ~= "function" then return false, "executor cannot confirm network ownership" end
	local ok, owned = pcall(isnetworkowner, seat)
	if not ok or not owned then return false, "you do not own this vehicle's physics" end
	local model = seat:FindFirstAncestorOfClass("Model")
	if not model then return false, "vehicle model not found" end
	local moved, errorMessage = pcall(model.PivotTo, model, destination.cframe * CFrame.new(0, 4, 0))
	return moved, moved and "vehicle moved locally; server may correct it" or tostring(errorMessage)
end

function Vehicles:triggerSpawn()
	local _, _, root = getRig(self.hub.localPlayer)
	if not root then return false, "character not ready" end
	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("ProximityPrompt") or object:IsA("ClickDetector") then
			local part = object.Parent
			if part and part:IsA("Attachment") then part = part.Parent end
			local label = ((part and part.Name or "") .. " " .. (part and part.Parent and part.Parent.Name or "")
				.. " " .. (object:IsA("ProximityPrompt") and object.ActionText or "")):lower()
			local maxDistance = math.min(16, object.MaxActivationDistance)
			if part and part:IsA("BasePart") and (label:find("vehicle") or label:find("car") or label:find("spawn"))
				and (part.Position - root.Position).Magnitude <= maxDistance then
				if object:IsA("ProximityPrompt") and type(fireproximityprompt) == "function" then
					local ok = pcall(fireproximityprompt, object)
					if ok then return true, "vehicle prompt attempted; check for a spawned car" end
				elseif object:IsA("ClickDetector") and type(fireclickdetector) == "function" then
					local ok = pcall(fireclickdetector, object)
					if ok then return true, "spawn button attempted; check for a vehicle" end
				end
			end
		end
	end
	return false, "no supported nearby spawn control; cannot spawn a vehicle from this client"
end

function Vehicles:restore()
	for seat, values in pairs(self.originalSeats) do
		if seat.Parent then
			pcall(function()
				for key, value in pairs(values) do seat[key] = value end
			end)
		end
	end
	self.originalSeats = setmetatable({}, {__mode = "k"})
end

return Vehicles
