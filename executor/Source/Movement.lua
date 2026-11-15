local Maid = MaidModule
local runService = PrivateContextModule.runService
local userInputService = PrivateContextModule.userInputService
local getRig = PrivateContextModule.getRig

-- Character movement is local; the game server may correct unsupported modes.
local Movement = {}
Movement.__index = Movement

function Movement.new(hub)
	local self = setmetatable({hub = hub, maid = Maid.new(), modeMaid = Maid.new(),
		flightMaid = Maid.new(), collisions = {}, speedBefore = nil,
		flightCharacter = nil, up = false, down = false}, Movement)
	self.maid:give(hub.localPlayer.CharacterAdded:Connect(function(character)
		self:stopFlight()
		self:restoreCollisions()
		self.speedBefore = nil
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 7)
			if self.hub.localPlayer.Character == character then self:configure() end
		end)
	end))
	return self
end

function Movement:restoreCollisions()
	for part, oldValue in pairs(self.collisions) do
		if part.Parent then part.CanCollide = oldValue end
	end
	self.collisions = {}
end

function Movement:stopFlight()
	self.flightMaid:clean()
	if self.flightHumanoid and self.flightHumanoid.Parent then
		self.flightHumanoid.PlatformStand = self.oldPlatformStand
		self.flightHumanoid.AutoRotate = self.oldAutoRotate
		if self.flightHumanoid.Health > 0 then self.flightHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
	end
	self.flightCharacter, self.flightHumanoid, self.flightVelocity = nil, nil, nil
	self.up, self.down = false, false
end

function Movement:stepFlight()
	local humanoid, velocity = self.flightHumanoid, self.flightVelocity
	if not (humanoid and humanoid.Health > 0 and velocity and velocity.Parent) then self:stopFlight(); return end
	local move = humanoid.MoveDirection
	local camera = workspace.CurrentCamera
	if move.Magnitude < 0.05 and camera and self.controls then
		-- Standard PlayerModule exposes the mobile thumbstick even in PlatformStand.
		local ok, vector = pcall(self.controls.GetMoveVector, self.controls)
		if ok and typeof(vector) == "Vector3" then
			move = camera.CFrame.RightVector * vector.X - camera.CFrame.LookVector * vector.Z
		end
	end
	if move.Magnitude < 0.05 and camera and not userInputService:GetFocusedTextBox() then
		local forward = (userInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (userInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
		local sideways = (userInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (userInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
		move = camera.CFrame.LookVector * forward + camera.CFrame.RightVector * sideways
	end
	local up = Enum.KeyCode[self.hub.config.flightUpKey]
	local down = Enum.KeyCode[self.hub.config.flightDownKey]
	local vertical = ((self.up or userInputService:IsKeyDown(up)) and 1 or 0)
		- ((self.down or userInputService:IsKeyDown(down)) and 1 or 0)
	local direction = Vector3.new(move.X, vertical, move.Z)
	velocity.VectorVelocity = (direction.Magnitude > 1 and direction.Unit or direction) * self.hub.config.flySpeed
end

function Movement:startFlight()
	local character, humanoid, root = getRig(self.hub.localPlayer)
	if not character or self.flightCharacter == character then return end
	self:stopFlight()
	self.flightCharacter, self.flightHumanoid = character, humanoid
	self.oldPlatformStand, self.oldAutoRotate = humanoid.PlatformStand, humanoid.AutoRotate
	local playerScripts = self.hub.localPlayer:FindFirstChild("PlayerScripts")
	local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if playerModule then
		local ok, module = pcall(require, playerModule)
		if ok and type(module) == "table" and type(module.GetControls) == "function" then
			local controlsOk, controls = pcall(module.GetControls, module)
			if controlsOk and controls and type(controls.GetMoveVector) == "function" then
				self.controls = controls
			end
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "amethyst flight"
	attachment.Parent = root
	self.flightMaid:give(attachment)
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = 1000000
	velocity.ForceLimitsEnabled = false
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	self.flightMaid:give(velocity)
	self.flightVelocity = velocity
	humanoid.PlatformStand, humanoid.AutoRotate = true, false
	self.flightMaid:give(runService.Heartbeat:Connect(function() self:stepFlight() end))
end

function Movement:configure()
	self.modeMaid:clean()
	local character, humanoid = getRig(self.hub.localPlayer)
	if self.hub.config.speedEnabled and humanoid then
		self.speedBefore = self.speedBefore or humanoid.WalkSpeed
		local function applySpeed()
			if humanoid.Parent and humanoid.WalkSpeed ~= self.hub.config.movementSpeed then
				humanoid.WalkSpeed = self.hub.config.movementSpeed
			end
		end
		applySpeed()
		self.modeMaid:give(humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(applySpeed))
	elseif self.speedBefore and humanoid then
		humanoid.WalkSpeed = self.speedBefore
		self.speedBefore = nil
	end
	if self.hub.config.noclip and character then
		local function disableCollision(part)
			if not part:IsA("BasePart") then return end
			if self.collisions[part] == nil then self.collisions[part] = part.CanCollide end
			part.CanCollide = false
		end
		for _, part in ipairs(character:GetDescendants()) do disableCollision(part) end
		self.modeMaid:give(character.DescendantAdded:Connect(disableCollision))
		self.modeMaid:give(runService.Stepped:Connect(function()
			for part in pairs(self.collisions) do
				if part:IsDescendantOf(character) then part.CanCollide = false
				else self.collisions[part] = nil end
			end
		end))
	else
		self:restoreCollisions()
	end
	if self.hub.config.infiniteJump then
		self.modeMaid:give(userInputService.JumpRequest:Connect(function()
			local _, rig = getRig(self.hub.localPlayer)
			if rig and not self.hub.config.fly then rig:ChangeState(Enum.HumanoidStateType.Jumping) end
		end))
	end
	if self.hub.config.antiStun and humanoid then
		local function clearStun()
			if humanoid.Parent and not self.hub.config.fly and humanoid.PlatformStand then humanoid.PlatformStand = false end
		end
		self.modeMaid:give(humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(clearStun))
		clearStun()
	end
	if self.hub.config.fly then self:startFlight() else self:stopFlight() end
end

function Movement:destroy()
	self.hub.config.speedEnabled = false
	self.hub.config.fly = false
	self.hub.config.noclip = false
	self.hub.config.infiniteJump = false
	self.hub.config.antiStun = false
	self.maid:clean()
	self:configure()
	self.modeMaid:clean()
	self:stopFlight()
	self:restoreCollisions()
end

return Movement
