local Maid = MaidModule
local Theme = ThemeModule
local playersService = PrivateContextModule.playersService
local runService = PrivateContextModule.runService
local getRig = PrivateContextModule.getRig

-- ESP uses Roblox GUI objects on both mobile and desktop; Drawing is optional.
local Visuals = {}
Visuals.__index = Visuals

function Visuals.new(hub)
	return setmetatable({hub = hub, maid = Maid.new(), markers = {}, watched = {}}, Visuals)
end

function Visuals:remove(key)
	local marker = self.markers[key]
	if not marker then return end
	marker.highlight:Destroy()
	marker.billboard:Destroy()
	self.markers[key] = nil
end

function Visuals:add(key, model, part, label)
	if self.markers[key] then return end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Theme.colors.violet
	highlight.FillTransparency = 0.84
	highlight.OutlineColor = Theme.colors.violetLight
	highlight.Parent = self.hub.playerGui
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 450
	billboard.Size = UDim2.fromOffset(210, 48)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.Parent = self.hub.playerGui
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Theme.colors.violetLight
	text.TextStrokeTransparency = 0.15
	text.Font = Enum.Font.GothamBold
	text.TextSize = 13
	text.Text = label:lower()
	text.Parent = billboard
	self.markers[key] = {highlight = highlight, billboard = billboard, text = text,
		model = model, part = part, label = label:lower()}
end

function Visuals:watchPlayer(player)
	if player == self.hub.localPlayer or self.watched[player] then return end
	local maid = Maid.new()
	self.watched[player] = maid
	local function onCharacter(character)
		task.spawn(function()
			local head = character:WaitForChild("Head", 5)
			if self.hub.config.playerEsp and player.Character == character and head and head:IsA("BasePart") then
				self:remove(player)
				self:add(player, character, head, player.DisplayName .. " @" .. player.Name)
			end
		end)
	end
	maid:give(player.CharacterAdded:Connect(onCharacter))
	maid:give(player.CharacterRemoving:Connect(function() self:remove(player) end))
	if player.Character then onCharacter(player.Character) end
end

function Visuals:watchSeat(seat)
	if not (seat:IsA("VehicleSeat") and seat:IsDescendantOf(workspace)) then return end
	local model = seat:FindFirstAncestorOfClass("Model") or seat
	self:add(seat, model, seat, "vehicle · " .. model.Name)
end

function Visuals:configure()
	self.maid:clean()
	local oldMarkers, oldWatchers = self.markers, self.watched
	self.markers, self.watched = {}, {}
	for _, marker in pairs(oldMarkers) do
		marker.highlight:Destroy()
		marker.billboard:Destroy()
	end
	for _, maid in pairs(oldWatchers) do maid:clean() end
	if self.hub.config.playerEsp then
		for _, player in ipairs(playersService:GetPlayers()) do self:watchPlayer(player) end
		self.maid:give(playersService.PlayerAdded:Connect(function(player) self:watchPlayer(player) end))
		self.maid:give(playersService.PlayerRemoving:Connect(function(player)
			self:remove(player)
			local maid = self.watched[player]
			if maid then maid:clean(); self.watched[player] = nil end
		end))
	end
	if self.hub.config.vehicleEsp then
		for _, object in ipairs(workspace:GetDescendants()) do
			if object:IsA("VehicleSeat") then self:watchSeat(object) end
		end
		self.maid:give(workspace.DescendantAdded:Connect(function(object)
			if object:IsA("VehicleSeat") then self:watchSeat(object) end
		end))
	end
	if self.hub.config.playerEsp or self.hub.config.vehicleEsp then
		local elapsed = 0
		self.maid:give(runService.Heartbeat:Connect(function(delta)
			elapsed += delta
			if elapsed < 0.2 then return end
			elapsed = 0
			local _, _, root = getRig(self.hub.localPlayer)
			for key, marker in pairs(self.markers) do
				if not marker.part:IsDescendantOf(workspace) or not marker.model:IsDescendantOf(workspace) then
					self:remove(key)
				else
					local distance = root and math.floor((root.Position - marker.part.Position).Magnitude) or 0
					marker.text.Text = marker.label .. " · " .. distance .. " studs"
				end
			end
		end))
	end
end

function Visuals:destroy()
	self.hub.config.playerEsp, self.hub.config.vehicleEsp = false, false
	self:configure()
end

return Visuals
