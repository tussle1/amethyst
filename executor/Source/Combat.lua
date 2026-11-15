local Maid = MaidModule
local replicatedStorage = PrivateContextModule.replicatedStorage
local runService = PrivateContextModule.runService
local globalState = PrivateContextModule.globalState
local getRig = PrivateContextModule.getRig
local inPrivateServer = PrivateContextModule.inPrivateServer

-- Combat only observes a known shot packet shape; unrecognized calls pass through.
local Combat = {}
Combat.__index = Combat

function Combat.new(hub)
	return setmetatable({hub = hub, maid = Maid.new(), aimHeld = false,
		autoElapsed = 0, tazeElapsed = 0, pendingArrest = false,
		shotStatus = "not installed", shotsSeen = 0, shotsChanged = 0,
		warnedPacket = false, warnedArrest = false}, Combat)
end

function Combat:aim(delta)
	local config = self.hub.config
	if not (config.aimlock or (config.aimbot and self.aimHeld)) then return end
	local camera = workspace.CurrentCamera
	local player = self.hub.targeting:get()
	local part = player and self.hub.targeting:part(player)
	if not (camera and part) then return end
	local target = CFrame.lookAt(camera.CFrame.Position, part.Position)
	camera.CFrame = camera.CFrame:Lerp(target, math.clamp(config.aimSmooth * delta * 60, 0, 1))
end

function Combat:activate()
	local character = self.hub.localPlayer.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool then return false, "equip a tool first" end
	local ok, errorMessage = pcall(tool.Activate, tool)
	return ok, ok and "tool activated locally; server result unconfirmed" or tostring(errorMessage)
end

function Combat:redirectShot(args)
	if not (self.hub.config.silentAim and inPrivateServer()) then return nil end
	self.shotsSeen += 1
	local packet, tool = args[1], args[2]
	local character = self.hub.localPlayer.Character
	local compatible = type(packet) == "table" and type(packet[1]) == "table"
		and typeof(tool) == "Instance" and tool:IsA("Tool")
		and tool:FindFirstChild("GunStates") and character and tool:IsDescendantOf(character)
	if compatible then
		for _, shot in ipairs(packet) do
			if type(shot) ~= "table" or typeof(shot.Cframe) ~= "CFrame"
				or typeof(shot.RayObject) ~= "Ray" or type(shot.Distance) ~= "number"
				or (shot.Hit ~= nil and typeof(shot.Hit) ~= "Instance") then
				compatible = false
				break
			end
		end
	end
	if not compatible then
		self.shotStatus = "unrecognized shot packet; passing through"
		if not self.warnedPacket then
			self.warnedPacket = true
			self.hub:notify("silent aim: shot packet is not compatible", false)
		end
		return nil
	end
	local player = self.hub.targeting:get()
	local part = player and self.hub.targeting:part(player)
	if not part then self.shotStatus = "compatible packet; no eligible target"; return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	local handle = tool:FindFirstChild("Handle")
	local replacement = {}
	for index, shot in ipairs(packet) do
		local origin = shot.RayObject.Origin
		if not root then return nil end
		if (origin - root.Position).Magnitude > 100 then
			origin = handle and handle:IsA("BasePart") and handle.Position or root.Position
		end
		local direction = part.Position - origin
		if direction.Magnitude < 0.01 or direction.Magnitude > 800 then
			self.shotStatus = "target outside supported range"
			return nil
		end
		local copy = table.clone(shot)
		copy.Hit = part
		copy.Distance = direction.Magnitude
		copy.Cframe = CFrame.lookAt(origin, part.Position)
		copy.RayObject = Ray.new(origin, direction)
		replacement[index] = copy
	end
	local copied = table.pack(table.unpack(args, 1, args.n))
	copied[1] = replacement
	self.shotsChanged += 1
	self.shotStatus = "packet redirected; server hit unconfirmed"
	return copied
end

function Combat:enableSilentAim()
	if not (type(hookmetamethod) == "function" and type(getnamecallmethod) == "function") then
		return false, "executor does not support a namecall hook"
	end
	local remote = replicatedStorage:FindFirstChild("ShootEvent")
	if not (remote and remote:IsA("RemoteEvent")) then return false, "compatible shot event not found" end
	local state = globalState.AmethystPrivateShotHook
	if type(state) ~= "table" or state.dataModel ~= game then
		state = {dataModel = game}
		local original
		local callback = function(self, ...)
			local methodOk, method = pcall(getnamecallmethod)
			local callerOk, fromExecutor = true, false
			if type(checkcaller) == "function" then callerOk, fromExecutor = pcall(checkcaller) end
			if methodOk and method == "FireServer" and self == state.remote and state.handler
				and callerOk and not fromExecutor then
				local ok, changed = pcall(state.handler, table.pack(...))
				if ok and changed then return original(self, table.unpack(changed, 1, changed.n)) end
			end
			return original(self, ...)
		end
		local ok, result = pcall(hookmetamethod, game, "__namecall",
			type(newcclosure) == "function" and newcclosure(callback) or callback)
		if not ok or type(result) ~= "function" then
			return false, "executor did not supply a usable namecall hook"
		end
		original = result
		globalState.AmethystPrivateShotHook = state
	end
	state.remote = remote
	state.handler = function(args) return self:redirectShot(args) end
	self.shotState = state
	self.shotStatus = "hook installed; waiting for a gun shot"
	return true, "shot hook installed; current game compatibility unverified"
end

function Combat:automate(delta)
	self.autoElapsed += delta
	self.tazeElapsed += delta
	if self.hub.config.rageBot and self.autoElapsed >= 0.5 then
		self.autoElapsed = 0
		local player = self.hub.targeting:get()
		local part = player and self.hub.targeting:part(player)
		local character = self.hub.localPlayer.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		local gunStates = tool and tool:FindFirstChild("GunStates")
		local camera = workspace.CurrentCamera
		if part and tool and gunStates and gunStates:IsA("ModuleScript") and camera then
			camera.CFrame = CFrame.lookAt(camera.CFrame.Position, part.Position)
			pcall(tool.Activate, tool)
		end
	end
	if not self.hub.config.autoTaze or self.tazeElapsed < 1.2 or self.pendingArrest then return end
	self.tazeElapsed = 0
	local target = self.hub.targeting:nearestCriminal(45)
	local character, _, root = target and getRig(target)
	if not (character and root) then return end
	local _, _, ownRoot = getRig(self.hub.localPlayer)
	if not ownRoot then return end
	local distance = (ownRoot.Position - root.Position).Magnitude
	if distance <= 10 then
		local remotes = workspace:FindFirstChild("Remote")
		local arrest = remotes and remotes:FindFirstChild("arrest")
		local head = character:FindFirstChild("Head")
		if not (arrest and arrest:IsA("RemoteFunction") and head) then return end
		self.pendingArrest = true
		task.spawn(function()
			local ok, accepted = pcall(arrest.InvokeServer, arrest, head)
			self.pendingArrest = false
			if self.hub.destroyed or not self.hub.config.autoTaze then return end
			if ok and accepted == true then
				self.hub:notify("arrest confirmed by remote", true)
			elseif not self.warnedArrest then
				self.warnedArrest = true
				self.hub:notify("arrest request not confirmed by server", false)
			end
		end)
	else
		local ownCharacter = self.hub.localPlayer.Character
		local tool = ownCharacter and ownCharacter:FindFirstChild("Taser")
		local camera = workspace.CurrentCamera
		local part = character:FindFirstChild("Head") or root
		if tool and tool:IsA("Tool") and camera then
			camera.CFrame = CFrame.lookAt(camera.CFrame.Position, part.Position)
			pcall(tool.Activate, tool)
		end
	end
end

function Combat:configure()
	self.maid:clean()
	local config = self.hub.config
	if config.aimbot or config.aimlock then
		local name = "amethyst private aim"
		runService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function(delta) self:aim(delta) end)
		self.maid:give(function() runService:UnbindFromRenderStep(name) end)
	end
	if config.rageBot or config.autoTaze then
		self.autoElapsed, self.tazeElapsed = 0, 0
		self.maid:give(runService.Heartbeat:Connect(function(delta) self:automate(delta) end))
	end
end

function Combat:destroy()
	self.maid:clean()
	if self.shotState and self.shotState.handler then self.shotState.handler = nil end
end

return Combat
