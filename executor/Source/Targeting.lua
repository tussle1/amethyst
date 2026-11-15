local playersService = PrivateContextModule.playersService
local userInputService = PrivateContextModule.userInputService
local getRig = PrivateContextModule.getRig

-- Targeting uses viewport-space distance and optional team/visibility checks.
local Targeting = {}
Targeting.__index = Targeting

function Targeting.new(hub)
	return setmetatable({hub = hub, selected = nil}, Targeting)
end

function Targeting:part(player)
	if player == self.hub.localPlayer or player.Parent ~= playersService then return nil end
	local character, humanoid, root = getRig(player)
	if not character then return nil end
	if self.hub.config.teamCheck and player.Team ~= nil and player.Team == self.hub.localPlayer.Team then return nil end
	local part = character:FindFirstChild(self.hub.config.aimPart) or root
	if not (part and part:IsA("BasePart")) then return nil end
	if self.hub.config.wallCheck then
		local camera = workspace.CurrentCamera
		if not camera then return nil end
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = {self.hub.localPlayer.Character}
		local result = workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, parameters)
		if result and not result.Instance:IsDescendantOf(character) then return nil end
	end
	return part
end

---Pick the closest visible player within the configurable cursor FOV.
---@return Player?
function Targeting:getClosestPlayer()
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local mousePosition = userInputService.MouseEnabled and userInputService:GetMouseLocation() or camera.ViewportSize / 2
	local closest, closestDistance = nil, self.hub.config.aimFov
	for _, player in ipairs(playersService:GetPlayers()) do
		if player == self.hub.localPlayer then continue end
		local part = self:part(player)
		if not part then continue end
		local screenPosition, onScreen = camera:WorldToViewportPoint(part.Position)
		if not onScreen or screenPosition.Z <= 0 then continue end
		local distance = (Vector2.new(screenPosition.X, screenPosition.Y) - mousePosition).Magnitude
		if distance < closestDistance then closest, closestDistance = player, distance end
	end
	return closest
end

function Targeting:get()
	if self.selected and self:part(self.selected) then return self.selected end
	return self:getClosestPlayer()
end

function Targeting:nearestCriminal(maximum)
	local _, _, ownRoot = getRig(self.hub.localPlayer)
	if not ownRoot then return nil end
	local selected = self.selected
	local function distanceTo(player)
		if not (player and player.Team and player.Team.Name:lower():find("criminal", 1, true)) then return nil end
		local _, _, root = getRig(player)
		if not root then return nil end
		local distance = (root.Position - ownRoot.Position).Magnitude
		return distance <= maximum and self:part(player) and distance or nil
	end
	if distanceTo(selected) then return selected end
	local nearest, best = nil, maximum
	for _, player in ipairs(playersService:GetPlayers()) do
		local distance = distanceTo(player)
		if distance and distance < best then nearest, best = player, distance end
	end
	return nearest
end

return Targeting
