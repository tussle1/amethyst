local Context = {}

-- Services.
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")

local SAVE_PATH = "amethyst_private_settings.json"
local PRISON_LIFE_PLACE_ID = 155615604
local FREE_WEAPONS = {M9 = true, ["AK-47"] = true, ["Remington 870"] = true, ["Crude Knife"] = true, Hammer = true}
local globalState = type(shared) == "table" and shared or {}
if type(getgenv) == "function" then
	local ok, state = pcall(getgenv)
	if ok and type(state) == "table" then globalState = state end
end

-- Keep config data scalar, bounded, and usable on executors without file APIs.
local DEFAULTS = {
	aimbot = false, aimlock = false, silentAim = false, rageBot = false, autoTaze = false,
	playerEsp = false, vehicleEsp = false, speedEnabled = false, fly = false,
	noclip = false, infiniteJump = false, antiStun = false, teamCheck = true,
	wallCheck = true, compact = false, aimPart = "Head", aimFov = 145,
	aimSmooth = 0.22, movementSpeed = 26, flySpeed = 45, gunDamage = 30,
	gunInterval = 0.15, gunSpread = 0, vehicleSpeed = 45, vehicleHandling = 2,
	menuKey = "RightShift", aimKey = "E", fireKey = "G", stopKey = "Z",
	flightUpKey = "Space", flightDownKey = "LeftControl",
}
local BOUNDS = {
	aimFov = {35, 350}, aimSmooth = {0.04, 1}, movementSpeed = {16, 120},
	flySpeed = {12, 100}, gunDamage = {1, 100}, gunInterval = {0.05, 1},
	gunSpread = {0, 8}, vehicleSpeed = {10, 120}, vehicleHandling = {0.5, 4},
}
local KEY_FIELDS = {menuKey = true, aimKey = true, fireKey = true, stopKey = true,
	flightUpKey = true, flightDownKey = true}

local function sanitize(input)
	local result = {}
	for key, default in pairs(DEFAULTS) do
		local value = type(input) == "table" and input[key] or nil
		if type(default) == "boolean" and type(value) == "boolean" then
			result[key] = value
		elseif BOUNDS[key] and type(value) == "number" and value == value and math.abs(value) < math.huge then
			result[key] = math.clamp(value, BOUNDS[key][1], BOUNDS[key][2])
		elseif KEY_FIELDS[key] and type(value) == "string" and #value <= 20 then
			local valid, enum = pcall(function() return Enum.KeyCode[value] end)
			result[key] = valid and enum and enum ~= Enum.KeyCode.None
				and enum ~= Enum.KeyCode.Escape and value or default
		else
			result[key] = default
		end
	end
	if type(input) == "table" and (input.aimPart == "Head" or input.aimPart == "HumanoidRootPart") then
		result.aimPart = input.aimPart
	end
	-- A loaded file must not make emergency stop or any other binding unreachable.
	local used = {}
	for _, key in ipairs({"stopKey", "menuKey", "aimKey", "fireKey", "flightUpKey", "flightDownKey"}) do
		local value = result[key]
		if used[value] then
			value = DEFAULTS[key]
			if used[value] then
				for _, candidate in ipairs({"RightShift", "E", "G", "Z", "Space", "LeftControl", "F", "H", "Q", "X"}) do
					if not used[candidate] then value = candidate; break end
				end
			end
			result[key] = value
		end
		used[value] = true
	end
	return result
end

local function getRig(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then return nil end
	return character, humanoid, root
end

local function inPrivateServer()
	local ok, id, ownerId = pcall(function()
		return game.PrivateServerId, game.PrivateServerOwnerId
	end)
	-- Reserved servers also have an ID; owner > 0 restricts this build to private/VIP servers.
	return ok and type(id) == "string" and id ~= "" and type(ownerId) == "number" and ownerId > 0
end

Context.playersService = playersService
Context.replicatedStorage = replicatedStorage
Context.userInputService = userInputService
Context.runService = runService
Context.httpService = httpService
Context.globalState = globalState
Context.SAVE_PATH = SAVE_PATH
Context.PRISON_LIFE_PLACE_ID = PRISON_LIFE_PLACE_ID
Context.FREE_WEAPONS = FREE_WEAPONS
Context.KEY_FIELDS = KEY_FIELDS
Context.sanitize = sanitize
Context.getRig = getRig
Context.inPrivateServer = inPrivateServer

return Context
