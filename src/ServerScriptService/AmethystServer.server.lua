local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local AUTHORIZED_USER_IDS = {
    [0] = true,
}

local REMOTE_FOLDER_NAME = "AmethystRemotes"
local ACTION_LIMIT = 12
local ACTION_WINDOW = 3
local MAX_WALK_SPEED = 32
local MAX_JUMP_POWER = 100
local MAX_VEHICLE_SPEED = 120

local remoteFolder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
if not remoteFolder then
    remoteFolder = Instance.new("Folder")
    remoteFolder.Name = REMOTE_FOLDER_NAME
    remoteFolder.Parent = ReplicatedStorage
end

local actionRemote = remoteFolder:FindFirstChild("Action")
if not actionRemote then
    actionRemote = Instance.new("RemoteFunction")
    actionRemote.Name = "Action"
    actionRemote.Parent = remoteFolder
end

local rateState = {}
local spawnedVehicles = {}
local bookmarks = {}

local function isAuthorized(player)
    return AUTHORIZED_USER_IDS[player.UserId] == true
end

local function allowRequest(player)
    local now = os.clock()
    local state = rateState[player]
    if not state or now - state.startedAt >= ACTION_WINDOW then
        rateState[player] = {startedAt = now, count = 1}
        return true
    end
    if state.count >= ACTION_LIMIT then
        return false
    end
    state.count += 1
    return true
end

local function getCharacter(player)
    local character = player.Character
    if not character then
        return nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then
        return nil
    end
    return character, humanoid, root
end

local function getOwnedVehicle(player)
    local vehicle = spawnedVehicles[player]
    if vehicle and vehicle.Parent then
        return vehicle
    end
    return nil
end

local function findVehicleSeat(vehicle)
    for _, item in ipairs(vehicle:GetDescendants()) do
        if item:IsA("VehicleSeat") then
            return item
        end
    end
    return nil
end

local function performAction(player, action, data)
    if not isAuthorized(player) then
        return false, "not authorized for this test environment"
    end
    if type(action) ~= "string" or type(data) ~= "table" then
        return false, "invalid request"
    end

    local character, humanoid, root = getCharacter(player)
    if action ~= "serverInfo" and not character then
        return false, "character is not ready"
    end

    if action == "setMovement" then
        local speed = math.clamp(tonumber(data.speed) or 16, 8, MAX_WALK_SPEED)
        local jump = math.clamp(tonumber(data.jump) or 50, 30, MAX_JUMP_POWER)
        humanoid.WalkSpeed = speed
        humanoid.UseJumpPower = true
        humanoid.JumpPower = jump
        return true, {speed = speed, jump = jump}
    elseif action == "resetMovement" then
        humanoid.WalkSpeed = 16
        humanoid.UseJumpPower = true
        humanoid.JumpPower = 50
        return true, "movement reset"
    elseif action == "teleportLocation" then
        local locations = {
            lobby = CFrame.new(0, 8, 0),
            test_pad = CFrame.new(0, 8, 80),
            vehicle_pad = CFrame.new(80, 8, 0),
        }
        local destination = locations[data.location]
        if not destination then
            return false, "unknown test location"
        end
        root.CFrame = destination
        return true, "teleported to " .. data.location
    elseif action == "saveBookmark" then
        local name = tostring(data.name or ""):sub(1, 24)
        if name == "" then
            return false, "bookmark name required"
        end
        bookmarks[player] = bookmarks[player] or {}
        bookmarks[player][name] = root.CFrame
        return true, "bookmark saved"
    elseif action == "teleportBookmark" then
        local saved = bookmarks[player] and bookmarks[player][tostring(data.name or "")]
        if not saved then
            return false, "bookmark not found"
        end
        root.CFrame = saved
        return true, "bookmark reached"
    elseif action == "spawnVehicle" then
        local templates = ServerStorage:FindFirstChild("AmethystVehicles")
        local templateName = tostring(data.vehicle or "TestCar")
        local template = templates and templates:FindFirstChild(templateName)
        if not template or not template:IsA("Model") then
            return false, "add the requested model to ServerStorage/AmethystVehicles"
        end
        local old = getOwnedVehicle(player)
        if old then
            old:Destroy()
        end
        local vehicle = template:Clone()
        vehicle.Name = "Amethyst_" .. player.UserId
        vehicle:SetAttribute("AmethystOwner", player.UserId)
        vehicle.Parent = workspace
        vehicle:PivotTo(root.CFrame * CFrame.new(0, 0, -14))
        spawnedVehicles[player] = vehicle
        return true, "test vehicle spawned"
    elseif action == "setVehicleSpeed" then
        local vehicle = getOwnedVehicle(player)
        if not vehicle then
            return false, "spawn a test vehicle first"
        end
        local seat = findVehicleSeat(vehicle)
        if not seat then
            return false, "vehicle needs a VehicleSeat"
        end
        seat.MaxSpeed = math.clamp(tonumber(data.speed) or 40, 10, MAX_VEHICLE_SPEED)
        return true, {speed = seat.MaxSpeed}
    elseif action == "enterVehicle" then
        local vehicle = getOwnedVehicle(player)
        local seat = vehicle and findVehicleSeat(vehicle)
        if not seat then
            return false, "no owned test vehicle available"
        end
        seat:Sit(humanoid)
        return true, "entered test vehicle"
    elseif action == "trainingTargets" then
        local targets = {}
        for _, model in ipairs(CollectionService:GetTagged("AmethystTrainingDummy")) do
            if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
                local targetRoot = model:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    table.insert(targets, {name = model.Name, position = targetRoot.Position})
                end
            end
        end
        return true, targets
    elseif action == "serverInfo" then
        return true, {
            placeId = game.PlaceId,
            jobId = game.JobId,
            playerCount = #Players:GetPlayers(),
            maxPlayers = Players.MaxPlayers,
            serverTime = workspace:GetServerTimeNow(),
        }
    end

    return false, "unknown action"
end

actionRemote.OnServerInvoke = function(player, action, data)
    if not allowRequest(player) then
        return false, "too many requests"
    end
    local ok, success, result = pcall(performAction, player, action, data)
    if not ok then
        warn("[amethyst] action failed:", success)
        return false, "server action failed"
    end
    return success, result
end

Players.PlayerRemoving:Connect(function(player)
    rateState[player] = nil
    bookmarks[player] = nil
    local vehicle = getOwnedVehicle(player)
    if vehicle then
        vehicle:Destroy()
    end
    spawnedVehicles[player] = nil
end)
