local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local actionRemote = ReplicatedStorage:WaitForChild("AmethystRemotes"):WaitForChild("Action")

local palette = {
    background = Color3.fromRGB(10, 9, 15),
    panel = Color3.fromRGB(19, 17, 27),
    panel2 = Color3.fromRGB(27, 23, 38),
    violet = Color3.fromRGB(151, 91, 255),
    violetDark = Color3.fromRGB(91, 52, 157),
    text = Color3.fromRGB(245, 240, 255),
    muted = Color3.fromRGB(157, 148, 174),
    border = Color3.fromRGB(57, 44, 77),
    success = Color3.fromRGB(126, 226, 170),
    danger = Color3.fromRGB(245, 112, 142),
}

local state = {
    compact = UserInputService.TouchEnabled,
    minimized = false,
    page = "home",
    query = "",
    speed = 16,
    jump = 50,
    vehicleSpeed = 40,
    selectedTarget = nil,
    bookmarks = {},
}

local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    create("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, parent)
end

local function stroke(parent, color, transparency)
    create("UIStroke", {
        Color = color or palette.border,
        Transparency = transparency or 0,
        Thickness = 1,
    }, parent)
end

local function invoke(action, data)
    local ok, success, result = pcall(function()
        return actionRemote:InvokeServer(action, data or {})
    end)
    if not ok then
        return false, "server connection failed"
    end
    return success, result
end

local gui = create("ScreenGui", {
    Name = "Amethyst",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local window = create("Frame", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = state.compact and UDim2.new(0.94, 0, 0.78, 0) or UDim2.fromOffset(760, 520),
    BackgroundColor3 = palette.background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
corner(window, 14)
stroke(window, palette.border)

local sizeConstraint = create("UISizeConstraint", {
    MinSize = Vector2.new(310, 300),
    MaxSize = Vector2.new(900, 680),
}, window)

local header = create("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = palette.panel,
    BorderSizePixel = 0,
}, window)

local brand = create("TextLabel", {
    Position = UDim2.fromOffset(17, 0),
    Size = UDim2.new(1, -130, 1, 0),
    BackgroundTransparency = 1,
    Text = "amethyst  /  developer hub",
    TextColor3 = palette.text,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local collapseButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(34, 30),
    BackgroundColor3 = palette.panel2,
    Text = "—",
    TextColor3 = palette.text,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    AutoButtonColor = true,
}, header)
corner(collapseButton, 8)

local body = create("Frame", {
    Position = UDim2.fromOffset(0, 52),
    Size = UDim2.new(1, 0, 1, -52),
    BackgroundTransparency = 1,
}, window)

local sidebar = create("Frame", {
    Size = UDim2.new(0, state.compact and 88 or 170, 1, 0),
    BackgroundColor3 = palette.panel,
    BorderSizePixel = 0,
}, body)

local search = create("TextBox", {
    Position = UDim2.fromOffset(10, 12),
    Size = UDim2.new(1, -20, 0, 34),
    BackgroundColor3 = palette.panel2,
    PlaceholderText = "search",
    Text = "",
    TextColor3 = palette.text,
    PlaceholderColor3 = palette.muted,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    ClearTextOnFocus = false,
}, sidebar)
corner(search, 8)

local nav = create("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 56),
    Size = UDim2.new(1, -16, 1, -64),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, sidebar)
create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, nav)

local content = create("ScrollingFrame", {
    Position = UDim2.new(0, state.compact and 88 or 170, 0, 0),
    Size = UDim2.new(1, -(state.compact and 88 or 170), 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = palette.violet,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, body)
create("UIPadding", {
    PaddingTop = UDim.new(0, 14),
    PaddingBottom = UDim.new(0, 18),
    PaddingLeft = UDim.new(0, 14),
    PaddingRight = UDim.new(0, 14),
}, content)
create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, content)

local toast = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -16),
    Size = UDim2.new(0.8, 0, 0, 38),
    BackgroundColor3 = palette.panel2,
    TextColor3 = palette.text,
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    Text = "",
    Visible = false,
    ZIndex = 10,
}, window)
corner(toast, 9)
stroke(toast, palette.violet)

local function notify(message, good)
    toast.Text = tostring(message):lower()
    toast.TextColor3 = good == false and palette.danger or palette.text
    toast.Visible = true
    toast.TextTransparency = 0
    task.delay(2.4, function()
        if toast.Parent then
            TweenService:Create(toast, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
            task.wait(0.28)
            toast.Visible = false
        end
    end)
end

local function clearContent()
    for _, child in ipairs(content:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function section(title, description)
    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, description and 58 or 38),
        BackgroundTransparency = 1,
    }, content)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundTransparency = 1,
        Text = title:lower(),
        TextColor3 = palette.text,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)
    if description then
        create("TextLabel", {
            Position = UDim2.fromOffset(0, 27),
            Size = UDim2.new(1, 0, 0, 25),
            BackgroundTransparency = 1,
            Text = description:lower(),
            TextColor3 = palette.muted,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, frame)
    end
end

local function button(label, callback, parent)
    local target = parent or content
    local item = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = palette.panel2,
        Text = label:lower(),
        TextColor3 = palette.text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        AutoButtonColor = true,
    }, target)
    corner(item, 9)
    stroke(item, palette.border)
    item.Activated:Connect(callback)
    return item
end

local function slider(label, minimum, maximum, initial, callback)
    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = palette.panel,
    }, content)
    corner(holder, 9)
    local valueLabel = create("TextLabel", {
        Position = UDim2.fromOffset(12, 5),
        Size = UDim2.new(1, -24, 0, 20),
        BackgroundTransparency = 1,
        Text = label:lower() .. ": " .. tostring(initial),
        TextColor3 = palette.text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, holder)
    local bar = create("Frame", {
        Position = UDim2.new(0, 12, 0, 34),
        Size = UDim2.new(1, -24, 0, 8),
        BackgroundColor3 = palette.border,
    }, holder)
    corner(bar, 5)
    local fill = create("Frame", {
        Size = UDim2.new((initial - minimum) / (maximum - minimum), 0, 1, 0),
        BackgroundColor3 = palette.violet,
    }, bar)
    corner(fill, 5)
    local knob = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((initial - minimum) / (maximum - minimum), 0, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = palette.text,
        Text = "",
    }, bar)
    corner(knob, 9)
    local dragging = false
    local function update(input)
        local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(minimum + (maximum - minimum) * alpha + 0.5)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = label:lower() .. ": " .. tostring(value)
        callback(value)
    end
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function runAction(action, data)
    local success, result = invoke(action, data)
    notify(success and (type(result) == "string" and result or "completed") or result, success)
    return success, result
end

local pages = {
    {id = "home", label = "home"},
    {id = "movement", label = "movement"},
    {id = "teleport", label = "teleport"},
    {id = "vehicles", label = "vehicles"},
    {id = "training", label = "training"},
    {id = "players", label = "players"},
    {id = "server", label = "server"},
    {id = "settings", label = "settings"},
}

local function showPage(page)
    state.page = page
    clearContent()
    if page == "home" then
        section("amethyst", "authorized studio testing environment")
        button("movement controls", function() showPage("movement") end)
        button("teleport tools", function() showPage("teleport") end)
        button("vehicle lab", function() showPage("vehicles") end)
        button("training range", function() showPage("training") end)
        button("refresh server information", function() showPage("server") end)
        section("session", "client-side interface with server-validated actions")
        button("save configuration", function()
            local config = {speed = state.speed, jump = state.jump, vehicleSpeed = state.vehicleSpeed}
            local ok, encoded = pcall(HttpService.JSONEncode, HttpService, config)
            if ok then
                player:SetAttribute("AmethystConfig", encoded)
                notify("configuration saved for this session", true)
            end
        end)
        button("load configuration", function()
            local encoded = player:GetAttribute("AmethystConfig")
            if not encoded then notify("no saved configuration", false) return end
            local ok, config = pcall(HttpService.JSONDecode, HttpService, encoded)
            if ok and type(config) == "table" then
                state.speed = tonumber(config.speed) or 16
                state.jump = tonumber(config.jump) or 50
                state.vehicleSpeed = tonumber(config.vehicleSpeed) or 40
                notify("configuration loaded", true)
            else
                notify("configuration is invalid", false)
            end
        end)
    elseif page == "movement" then
        section("movement lab", "server-authorized test settings for your own experience")
        slider("walk speed", 8, 32, state.speed, function(value) state.speed = value end)
        slider("jump power", 30, 100, state.jump, function(value) state.jump = value end)
        button("apply movement settings", function()
            runAction("setMovement", {speed = state.speed, jump = state.jump})
        end)
        button("reset movement", function() runAction("resetMovement", {}) end)
        section("physics testing", "advanced movement modes are intentionally not enabled")
    elseif page == "teleport" then
        section("teleport lab", "fixed test pads and private bookmarks")
        button("teleport: lobby", function() runAction("teleportLocation", {location = "lobby"}) end)
        button("teleport: test pad", function() runAction("teleportLocation", {location = "test_pad"}) end)
        button("teleport: vehicle pad", function() runAction("teleportLocation", {location = "vehicle_pad"}) end)
        button("save current position as test bookmark", function()
            local name = "bookmark_" .. tostring(#state.bookmarks + 1)
            local ok = runAction("saveBookmark", {name = name})
            if ok then
                table.insert(state.bookmarks, name)
                notify(name .. " saved", true)
            end
        end)
        for _, name in ipairs(state.bookmarks) do
            button("go to " .. name, function() runAction("teleportBookmark", {name = name}) end)
        end
    elseif page == "vehicles" then
        section("vehicle lab", "works with models in serverstorage/amethystvehicles")
        button("spawn test car", function() runAction("spawnVehicle", {vehicle = "TestCar"}) end)
        slider("vehicle max speed", 10, 120, state.vehicleSpeed, function(value) state.vehicleSpeed = value end)
        button("apply vehicle speed", function() runAction("setVehicleSpeed", {speed = state.vehicleSpeed}) end)
        button("enter owned test vehicle", function() runAction("enterVehicle", {}) end)
    elseif page == "training" then
        section("training range", "targeting is limited to tagged npc training dummies")
        button("scan training dummies", function()
            local ok, targets = invoke("trainingTargets", {})
            if not ok then notify(targets, false) return end
            notify(tostring(#targets) .. " training dummies found", true)
            for _, target in ipairs(targets) do
                print("[amethyst] training target:", target.name, target.position)
            end
        end)
        button("show tagged dummy markers", function()
            local count = 0
            for _, model in ipairs(CollectionService:GetTagged("AmethystTrainingDummy")) do
                if model:IsA("Model") then
                    local highlight = model:FindFirstChild("AmethystMarker")
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "AmethystMarker"
                        highlight.FillColor = palette.violet
                        highlight.OutlineColor = palette.text
                        highlight.DepthMode = Enum.HighlightDepthMode.Occluded
                        highlight.Parent = model
                    end
                    count += 1
                end
            end
            notify(tostring(count) .. " dummy markers active", true)
        end)
        button("clear dummy markers", function()
            for _, model in ipairs(CollectionService:GetTagged("AmethystTrainingDummy")) do
                local marker = model:FindFirstChild("AmethystMarker")
                if marker then marker:Destroy() end
            end
            notify("dummy markers cleared", true)
        end)
    elseif page == "players" then
        section("player information", "players in this studio test server")
        for _, target in ipairs(Players:GetPlayers()) do
            local card = create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = palette.panel,
                Text = string.lower(target.DisplayName .. "  @" .. target.Name .. "  /  " .. target.UserId),
                TextColor3 = palette.text,
                Font = Enum.Font.Gotham,
                TextSize = 11,
            }, content)
            corner(card, 8)
        end
    elseif page == "server" then
        section("server information", "live values returned by the server")
        local ok, info = invoke("serverInfo", {})
        if ok then
            for key, value in pairs(info) do
                local row = create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 34),
                    BackgroundColor3 = palette.panel,
                    Text = string.lower(tostring(key) .. "  /  " .. tostring(value)),
                    TextColor3 = palette.text,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                }, content)
                corner(row, 8)
            end
        else
            section("unavailable", tostring(info))
        end
    elseif page == "settings" then
        section("settings", "interface and configuration")
        button(state.compact and "switch to desktop layout" or "switch to compact layout", function()
            state.compact = not state.compact
            local width = state.compact and 88 or 170
            TweenService:Create(sidebar, TweenInfo.new(0.2), {Size = UDim2.new(0, width, 1, 0)}):Play()
            TweenService:Create(content, TweenInfo.new(0.2), {
                Position = UDim2.new(0, width, 0, 0),
                Size = UDim2.new(1, -width, 1, 0),
            }):Play()
            showPage("settings")
        end)
        button("save configuration", function()
            local config = {speed = state.speed, jump = state.jump, vehicleSpeed = state.vehicleSpeed}
            player:SetAttribute("AmethystConfig", HttpService:JSONEncode(config))
            notify("configuration saved", true)
        end)
        button("load configuration", function()
            local encoded = player:GetAttribute("AmethystConfig")
            if not encoded then notify("no saved configuration", false) return end
            local ok, config = pcall(function() return HttpService:JSONDecode(encoded) end)
            if ok and type(config) == "table" then
                state.speed = tonumber(config.speed) or 16
                state.jump = tonumber(config.jump) or 50
                state.vehicleSpeed = tonumber(config.vehicleSpeed) or 40
                notify("configuration loaded", true)
            else
                notify("invalid configuration", false)
            end
        end)
    end
end

local navButtons = {}
for index, page in ipairs(pages) do
    local item = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = page.id == state.page and palette.violetDark or palette.panel,
        Text = state.compact and page.label:sub(1, 3) or page.label,
        TextColor3 = palette.text,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        LayoutOrder = index,
    }, nav)
    corner(item, 8)
    item.Activated:Connect(function() showPage(page.id) end)
    navButtons[page.id] = item
end

search:GetPropertyChangedSignal("Text"):Connect(function()
    local query = string.lower(search.Text)
    for id, item in pairs(navButtons) do
        local label = id
        item.Visible = query == "" or string.find(label, query, 1, true) ~= nil
    end
end)

collapseButton.Activated:Connect(function()
    state.minimized = not state.minimized
    body.Visible = not state.minimized
    window.Size = state.minimized and UDim2.new(window.Size.X.Scale, window.Size.X.Offset, 0, 52)
        or (state.compact and UDim2.new(0.94, 0, 0.78, 0) or UDim2.fromOffset(760, 520))
    collapseButton.Text = state.minimized and "+" or "—"
end)

local dragging = false
local dragStart
local startPosition
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = window.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        window.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

showPage("home")
