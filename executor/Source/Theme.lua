local Theme = {}

-- A single black-and-violet palette keeps every control visually consistent.
Theme.colors = {
	background = Color3.fromRGB(16, 13, 25),
	surface = Color3.fromRGB(28, 23, 41),
	deep = Color3.fromRGB(22, 18, 32),
	raised = Color3.fromRGB(42, 34, 58),
	border = Color3.fromRGB(72, 57, 100),
	violet = Color3.fromRGB(143, 99, 238),
	violetLight = Color3.fromRGB(190, 156, 255),
	violetDark = Color3.fromRGB(90, 56, 165),
	text = Color3.fromRGB(245, 240, 255),
	muted = Color3.fromRGB(167, 154, 192),
	track = Color3.fromRGB(14, 12, 22),
}

-- Services.
local tweenService = game:GetService("TweenService")

---Build a native Roblox GUI object with its parent assigned last.
---@param className string
---@param properties table
---@param parent Instance
---@return Instance
function Theme.create(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

---Give a surface the small rounded corners used in the reference layout.
---@param parent GuiObject
---@param radius number
function Theme.corner(parent, radius)
	Theme.create("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

---Separate adjacent panels without adding another accent color.
---@param parent GuiObject
---@param color Color3?
function Theme.stroke(parent, color)
	Theme.create("UIStroke", {
		Color = color or Theme.colors.border,
		Thickness = 1,
		Transparency = 0.2,
	}, parent)
end

---Use quick, unobtrusive animations for state changes and layout transitions.
---@param object Instance
---@param properties table
---@param duration number?
function Theme.tween(object, properties, duration)
	local tween = tweenService:Create(object, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	tween:Play()
	return tween
end

return Theme
