local PrivateCore = {}

local playersService = PrivateContextModule.playersService
local userInputService = PrivateContextModule.userInputService
local httpService = PrivateContextModule.httpService
local globalState = PrivateContextModule.globalState
local SAVE_PATH = PrivateContextModule.SAVE_PATH
local PRISON_LIFE_PLACE_ID = PrivateContextModule.PRISON_LIFE_PLACE_ID
local KEY_FIELDS = PrivateContextModule.KEY_FIELDS
local sanitize = PrivateContextModule.sanitize
local inPrivateServer = PrivateContextModule.inPrivateServer
local Maid = MaidModule
local Library = LibraryModule
local PrivateMenu = PrivateMenuModule
local Targeting = TargetingModule
local Movement = MovementModule
local Visuals = VisualsModule
local Combat = CombatModule
local Travel = TravelModule
local Inventory = InventoryModule
local Vehicles = VehiclesModule

local Hub = {}
Hub.__index = Hub

function Hub.new()
	local self = setmetatable({
		localPlayer = playersService.LocalPlayer, playersService = playersService,
		config = sanitize(nil), maid = Maid.new(), bookmarkName = "",
		destroyed = false,
	}, Hub)
	self.playerGui = self.localPlayer:WaitForChild("PlayerGui", 12)
	if not self.playerGui then error("player gui did not load; re-run after spawning") end
	self.targeting = Targeting.new(self)
	self.movement = Movement.new(self)
	self.visuals = Visuals.new(self)
	self.combat = Combat.new(self)
	self.travel = Travel.new(self)
	self.inventory = Inventory.new(self)
	self.vehicles = Vehicles.new(self)
	return self
end

function Hub:notify(message, success)
	message = message or "no status returned"
	if self.ui then self.ui:notify(message, success) else warn("[amethyst]", message) end
end

function Hub:report(success, message)
	self:notify(message, success)
	return success
end

function Hub:refreshSummary()
	if self.ui then self.ui:setSummary(math.max(0, #playersService:GetPlayers() - 1), #playersService:GetPlayers()) end
end

function Hub:onSettingChanged(key)
	if key == "movementSpeed" and self.config.speedEnabled then self.movement:configure() end
end

function Hub:setFlag(key, value)
	if type(value) ~= "boolean" or type(self.config[key]) ~= "boolean" then return false end
	if key == "silentAim" and value then
		local ok, message = self.combat:enableSilentAim()
		if not ok then self:notify(message, false); return false end
		self:notify(message, true)
	end
	if key == "autoTaze" and value then
		local remotes = workspace:FindFirstChild("Remote")
		local arrest = remotes and remotes:FindFirstChild("arrest")
		if not (arrest and arrest:IsA("RemoteFunction")) then
			self:notify("compatible arrest remote not found; taze/arrest unavailable", false)
			return false
		end
	end
	self.config[key] = value
	if key == "silentAim" and not value then self.combat.shotStatus = "disabled" end
	if key == "compact" then self.ui:updateViewport() end
	if key == "aimbot" or key == "aimlock" or key == "rageBot" or key == "autoTaze" then self.combat:configure() end
	if key == "playerEsp" or key == "vehicleEsp" then self.visuals:configure() end
	if key == "speedEnabled" or key == "fly" or key == "noclip"
		or key == "infiniteJump" or key == "antiStun" then self.movement:configure() end
	if key == "fly" then
		self.ui:setFlightControls(value, function(up, down) self.movement.up, self.movement.down = up, down end)
	end
	if key == "silentAim" and self.ui.currentPage == "combat" then
		task.defer(function()
			if not self.destroyed and self.ui.currentPage == "combat" then self.ui:refreshPage() end
		end)
	end
	return true
end

function Hub:setKeybind(key, value)
	if not KEY_FIELDS[key] or type(value) ~= "string" then return false end
	local valid, code = pcall(function() return Enum.KeyCode[value] end)
	if not valid or not code or code == Enum.KeyCode.None or code == Enum.KeyCode.Escape then
		self:notify("unsupported key", false)
		return false
	end
	for other in pairs(KEY_FIELDS) do
		if other ~= key and self.config[other] == value then
			self:notify("key already bound", false)
			return false
		end
	end
	self.config[key] = value
	if key == "aimKey" then self.combat.aimHeld = false end
	return true
end

function Hub:stopAll(quiet)
	for _, key in ipairs({"aimbot", "aimlock", "silentAim", "rageBot", "autoTaze",
		"playerEsp", "vehicleEsp", "speedEnabled", "fly", "noclip", "infiniteJump", "antiStun"}) do
		self.config[key] = false
	end
	self.combat.aimHeld = false
	self.combat.shotStatus = "disabled"
	self.combat:configure()
	self.movement:configure()
	self.visuals:configure()
	self.inventory:restore()
	self.vehicles:restore()
	if self.ui then
		self.ui:setFlightControls(false, function(up, down) self.movement.up, self.movement.down = up, down end)
		if not quiet then self.ui:refreshPage() end
	end
	if not quiet then self:notify("all modes stopped; local settings restored", true) end
end

function Hub:restoreDefaults()
	self:stopAll(true)
	for key, value in pairs(sanitize(nil)) do self.config[key] = value end
	self.targeting.selected = nil
	self.ui:updateViewport()
	self.ui:refreshPage()
	self:notify("default settings restored", true)
end

function Hub:saveConfig()
	local ok, body = pcall(httpService.JSONEncode, httpService, sanitize(self.config))
	if not ok then return false, "could not encode configuration" end
	globalState.AmethystPrivateSettings = body
	if type(writefile) == "function" then
		local saved = pcall(writefile, SAVE_PATH, body)
		if saved then return true, "configuration saved to executor file" end
	end
	return true, "configuration stored in memory; persistence depends on executor"
end

function Hub:loadConfig()
	local body = globalState.AmethystPrivateSettings
	if type(readfile) == "function" then
		local ok, stored = pcall(readfile, SAVE_PATH)
		if ok then body = stored end
	end
	if type(body) ~= "string" then return false, "no saved configuration" end
	local ok, decoded = pcall(httpService.JSONDecode, httpService, body)
	if not ok or type(decoded) ~= "table" then return false, "invalid saved configuration" end
	local incoming = sanitize(decoded)
	local skipped = 0
	self:stopAll(true)
	for key, value in pairs(incoming) do self.config[key] = value end
	if self.config.autoTaze then
		local remotes = workspace:FindFirstChild("Remote")
		local arrest = remotes and remotes:FindFirstChild("arrest")
		if not (arrest and arrest:IsA("RemoteFunction")) then
			self.config.autoTaze = false
			skipped += 1
			self:notify("arrest remote missing; auto taze stayed off", false)
		end
	end
	if self.config.silentAim then
		local supported, message = self.combat:enableSilentAim()
		if not supported then
			self.config.silentAim = false
			skipped += 1
			self:notify(message, false)
		end
	end
	self.movement:configure()
	self.visuals:configure()
	self.combat:configure()
	self.ui:setFlightControls(self.config.fly, function(up, down) self.movement.up, self.movement.down = up, down end)
	self.ui:updateViewport()
	return true, skipped > 0 and "loaded; unsupported game modes stayed off" or "configuration loaded"
end

function Hub:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.maid:clean()
	self.combat:destroy()
	self.movement:destroy()
	self.visuals:destroy()
	self.inventory:restore()
	self.vehicles:restore()
	if self.ui then self.ui:destroy() end
	if globalState.AmethystPrivate == self then globalState.AmethystPrivate = nil end
end

function Hub:initialize()
	local labels = {guiName = "amethyst private hub", brand = "amethyst  /  private hub",
		heroTag = "amethyst  /  prison life private", heroTitle = "precision, on your terms.",
		initialSummary = "private session", badge = "private only",
		metricsNote = "local controls · game server decides results",
		summarySuffix = "private server", serverState = "client only"}
	self.ui = Library.new(self.playerGui, self.config, labels)
	self.ui:setFooterActions(function() self:stopAll() end, function() self:report(self.combat:activate()) end)
	self.ui:setFlightControls(false, function(up, down) self.movement.up, self.movement.down = up, down end)
	self.ui:setPages(PrivateMenu.pages(self))
	self:refreshSummary()
	self.maid:give(playersService.PlayerAdded:Connect(function() self:refreshSummary() end))
	self.maid:give(playersService.PlayerRemoving:Connect(function() self:refreshSummary() end))
	self.maid:give(userInputService.InputBegan:Connect(function(input, processed)
		if processed or self.ui.capturingKey or userInputService:GetFocusedTextBox()
			or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local name = input.KeyCode.Name
		if name == self.config.stopKey then self:stopAll()
		elseif name == self.config.menuKey then self.ui:setVisible(not self.ui.visible)
		elseif name == self.config.aimKey then self.combat.aimHeld = true
		elseif name == self.config.fireKey then self:report(self.combat:activate()) end
	end))
	self.maid:give(userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == self.config.aimKey then
			self.combat.aimHeld = false
		end
	end))
	local function onContextChanged()
		if game.PlaceId == PRISON_LIFE_PLACE_ID and inPrivateServer() then return end
		self:stopAll(true)
		self:destroy()
		warn("[amethyst] left the intended private server; hub unloaded")
	end
	self.maid:give(game:GetPropertyChangedSignal("PrivateServerId"):Connect(onContextChanged))
	self.maid:give(game:GetPropertyChangedSignal("PrivateServerOwnerId"):Connect(onContextChanged))
	self.maid:give(game:GetPropertyChangedSignal("PlaceId"):Connect(onContextChanged))
end

---Launch only in an official Prison Life private server, never a public server.
function PrivateCore.start()
	if not game:IsLoaded() then game.Loaded:Wait() end
	if game.PlaceId ~= PRISON_LIFE_PLACE_ID then return warn("[amethyst] this build is for prison life only") end
	if not inPrivateServer() then return warn("[amethyst] official private server required; public/reserved servers disabled") end
	if not playersService.LocalPlayer then return warn("[amethyst] client player not ready; rerun after spawning") end
	local previous = globalState.AmethystPrivate
	if type(previous) == "table" and type(previous.destroy) == "function" then
		local cleared, message = pcall(previous.destroy, previous)
		if not cleared then warn("[amethyst] old instance cleanup failed:", message) end
	end
	local hub = Hub.new()
	globalState.AmethystPrivate = hub
	local ok, message = pcall(function() hub:initialize() end)
	if not ok then
		pcall(hub.destroy, hub)
		local leftover = hub.playerGui:FindFirstChild("amethyst private hub")
		if leftover then leftover:Destroy() end
		error(message)
	end
	return hub
end

return PrivateCore
