local Library = {}
Library.__index = Library

-- Services.
local userInputService = game:GetService("UserInputService")

-- Both dependencies are injected by the single-file builder.
local Theme = ThemeModule
local Maid = MaidModule

local Colors = Theme.colors
local HEADER_HEIGHT = 44

local function createText(parent, text, position, size, font, textSize, color, alignment)
	return Theme.create("TextLabel", {
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Text = tostring(text):lower(),
		TextColor3 = color or Colors.text,
		Font = font or Enum.Font.Gotham,
		TextSize = textSize or 13,
		TextXAlignment = alignment or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function onCallbackError(errorMessage)
	warn("[amethyst] gui action failed:", errorMessage)
	if debug and type(debug.traceback) == "function" then warn(debug.traceback()) end
end

---Create a native, responsive window inspired by the supplied compact layout.
---@param playerGui PlayerGui
---@param config table
---@param labels table?
---@return table
function Library.new(playerGui, config, labels)
	labels = labels or {}
	local self = setmetatable({
		config = config,
		labels = labels,
		maid = Maid.new(),
		pageMaid = Maid.new(),
		pages = {},
		navButtons = {},
		currentPage = nil,
		visible = true,
		minimized = false,
		detailsOpen = true,
		userWidth = 650,
		userHeight = 750,
		toastToken = 0,
		order = 0,
		capturingKey = false,
		flightActive = false,
	}, Library)

	-- A separate top-right launcher remains accessible when the mobile panel closes.
	self.gui = Theme.create("ScreenGui", {
		Name = labels.guiName or "amethyst private hub",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
	}, playerGui)
	self.launcher = Theme.create("TextButton", {
		Name = "mobile menu",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(52, 44),
		BackgroundColor3 = Colors.violetDark,
		BorderSizePixel = 0,
		Text = "hide",
		TextColor3 = Colors.text,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		ZIndex = 50,
	}, self.gui)
	Theme.corner(self.launcher, 11)
	Theme.stroke(self.launcher, Colors.violetLight)

	-- Keep the screenshot's narrow header, patterned hero, metrics, tabs and sticky actions.
	self.window = Theme.create("CanvasGroup", {
		Name = "hub window",
		AnchorPoint = Vector2.new(0, 0),
		Size = UDim2.fromOffset(650, 750),
		BackgroundColor3 = Colors.background,
		BorderSizePixel = 0,
		GroupTransparency = 0,
		ClipsDescendants = true,
	}, self.gui)
	Theme.corner(self.window, 12)
	Theme.stroke(self.window)
	self.header = Theme.create("Frame", {
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundColor3 = Colors.deep,
		BorderSizePixel = 0,
	}, self.window)
	local emblem = Theme.create("TextLabel", {
		Position = UDim2.fromOffset(11, 11),
		Size = UDim2.fromOffset(23, 23),
		BackgroundColor3 = Colors.violet,
		BorderSizePixel = 0,
		Text = "a",
		TextColor3 = Colors.text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, self.header)
	Theme.corner(emblem, 12)
	createText(self.header, labels.brand or "amethyst  /  private hub", UDim2.fromOffset(42, 0),
		UDim2.new(1, -137, 1, 0), Enum.Font.GothamMedium, 13)
	self.collapseButton = Theme.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -52, 0.5, 0),
		Size = UDim2.fromOffset(35, 32),
		BackgroundTransparency = 1,
		Text = "−",
		TextColor3 = Colors.text,
		Font = Enum.Font.GothamBold,
		TextSize = 19,
	}, self.header)
	self.closeButton = Theme.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(35, 32),
		BackgroundTransparency = 1,
		Text = "×",
		TextColor3 = Colors.text,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
	}, self.header)

	-- Geometric panels replace external images so the interface loads without HTTP or assets.
	self.hero = Theme.create("Frame", {
		BackgroundColor3 = Colors.violetDark,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.window)
	Theme.corner(self.hero, 7)
	Theme.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Colors.raised),
			ColorSequenceKeypoint.new(0.55, Colors.violetDark),
			ColorSequenceKeypoint.new(1, Colors.deep),
		}),
		Rotation = 18,
	}, self.hero)
	for index = 1, 17 do
		Theme.create("Frame", {
			Position = UDim2.new((index - 1) / 16, -18, 0, -55),
			Size = UDim2.fromOffset(index % 3 == 0 and 28 or 14, 260),
			Rotation = (index % 2 == 0) and 33 or -35,
			BackgroundColor3 = index % 3 == 0 and Colors.violetLight or Colors.violet,
			BackgroundTransparency = index % 3 == 0 and 0.81 or 0.89,
			BorderSizePixel = 0,
		}, self.hero)
	end
	createText(self.hero, labels.heroTag or "amethyst  /  prison life private", UDim2.fromOffset(13, 10),
		UDim2.new(1, -100, 0, 19), Enum.Font.GothamBold, 10, Colors.violetLight)
	self.heroTitle = createText(self.hero, labels.heroTitle or "precision, on your terms.", UDim2.fromOffset(13, 35),
		UDim2.new(1, -26, 0, 31), Enum.Font.GothamBold, 21)
	self.heroSummary = createText(self.hero, labels.initialSummary or "0 others  ·  1 player  ·  private server", UDim2.fromOffset(13, 70),
		UDim2.new(1, -26, 0, 24), Enum.Font.GothamMedium, 12, Colors.text)
	local status = Theme.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(83, 26),
		BackgroundColor3 = Colors.deep,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}, self.hero)
	Theme.corner(status, 14)
	createText(status, labels.badge or "private only", UDim2.new(), UDim2.fromScale(1, 1),
		Enum.Font.GothamBold, 10, Colors.text, Enum.TextXAlignment.Center)

	-- Search filters navigation by both page title and feature keywords.
	self.searchBox = Theme.create("TextBox", {
		BackgroundColor3 = Colors.surface,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		PlaceholderText = "search features...",
		PlaceholderColor3 = Colors.muted,
		Text = "",
		TextColor3 = Colors.text,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.window)
	Theme.corner(self.searchBox, 8)
	Theme.stroke(self.searchBox)
	Theme.create("UIPadding", {PaddingLeft = UDim.new(0, 14)}, self.searchBox)
	self.metrics = Theme.create("Frame", {
		BackgroundColor3 = Colors.surface,
		BorderSizePixel = 0,
	}, self.window)
	Theme.corner(self.metrics, 7)
	self.targetMetric = createText(self.metrics, "other players    0", UDim2.fromOffset(12, 2),
		UDim2.new(0.5, -12, 0, 25), Enum.Font.GothamMedium, 12, Colors.violetLight)
	self.serverMetric = createText(self.metrics, "server    client only", UDim2.new(0.5, 0, 0, 2),
		UDim2.new(0.5, -12, 0, 25), Enum.Font.GothamMedium, 12, Colors.violetLight)
	createText(self.metrics, labels.metricsNote or "local controls · game server decides results", UDim2.fromOffset(12, 25),
		UDim2.new(1, -24, 0, 23), Enum.Font.Gotham, 11, Colors.muted)

	self.nav = Theme.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		ScrollingEnabled = true,
	}, self.window)
	Theme.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.nav)
	self.moreBar = Theme.create("Frame", {
		BackgroundColor3 = Colors.deep,
		BorderSizePixel = 0,
	}, self.window)
	self.moreButton = Theme.create("TextButton", {
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "▾ less",
		TextColor3 = Colors.violetLight,
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
	}, self.moreBar)
	self.moreHint = createText(self.moreBar, "touch menu · open / close", UDim2.new(0.5, 0, 0, 0),
		UDim2.new(0.5, -11, 1, 0), Enum.Font.Gotham, 10, Colors.muted, Enum.TextXAlignment.Right)

	-- The detailed section scrolls independently of the persistent bottom controls.
	self.content = Theme.create("ScrollingFrame", {
		BackgroundColor3 = Colors.surface,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Colors.violet,
	}, self.window)
	Theme.create("UIPadding", {
		PaddingTop = UDim.new(0, 13),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 11),
		PaddingRight = UDim.new(0, 11),
	}, self.content)
	Theme.create("UIListLayout", {
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.content)
	self.footer = Theme.create("Frame", {
		BackgroundColor3 = Colors.background,
		BorderSizePixel = 0,
	}, self.window)
	self.stopButton = self:createFooterButton("stop all", "release modes", Colors.violetDark, 0)
	self.fireButton = self:createFooterButton(labels.fireTitle or "fire equipped tool", "tap · bound key", Colors.violet, 1)
	self.toast = Theme.create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0.82, 0, 0, 40),
		BackgroundColor3 = Colors.raised,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Colors.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextWrapped = true,
		Visible = false,
		ZIndex = 20,
	}, self.window)
	Theme.corner(self.toast, 8)
	Theme.stroke(self.toast, Colors.violetLight)
	-- Notifications remain visible when the menu is hidden or collapsed.
	self.sideToast = Theme.create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 63),
		Size = UDim2.fromOffset(220, 52),
		BackgroundColor3 = Colors.raised,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Colors.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextWrapped = true,
		Visible = false,
		ZIndex = 52,
	}, self.gui)
	Theme.corner(self.sideToast, 8)
	Theme.stroke(self.sideToast, Colors.violetLight)

	-- The resize grip is hidden in compact mode; touch devices use the launcher.
	self.resizeGrip = Theme.create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -3, 1, -3),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Text = "◢",
		TextColor3 = Colors.violetLight,
		TextSize = 18,
		Font = Enum.Font.Gotham,
		ZIndex = 6,
	}, self.window)

	self:buildFlightControls()
	self:connectInputs()
	self:updateViewport()
	return self
end

---Make sticky footer cards echo the screenshot's patterned action blocks.
---@param title string
---@param subtitle string
---@param color Color3
---@param side number
---@return TextButton
function Library:createFooterButton(title, subtitle, color, side)
	local button = Theme.create("TextButton", {
		Position = UDim2.new(side * 0.5, side == 0 and 10 or 4, 0, 8),
		Size = UDim2.new(0.5, -14, 1, -16),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ClipsDescendants = true,
	}, self.footer)
	Theme.corner(button, 5)
	for index = 1, 8 do
		Theme.create("Frame", {
			Position = UDim2.new((index - 1) / 7, 0, 0, -18),
			Size = UDim2.fromOffset(12, 140),
			Rotation = index % 2 == 0 and -35 or 35,
			BackgroundColor3 = Colors.violetLight,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
		}, button)
	end
	createText(button, title, UDim2.new(0, 0, 0.19, 0), UDim2.new(1, 0, 0, 25),
		Enum.Font.GothamMedium, 17, Colors.text, Enum.TextXAlignment.Center)
	createText(button, subtitle, UDim2.new(0, 0, 0.61, 0), UDim2.new(1, 0, 0, 17),
		Enum.Font.Gotham, 10, Colors.text, Enum.TextXAlignment.Center)
	return button
end

---Build hold-to-ascend/descend buttons that appear when the mobile panel is hidden.
function Library:buildFlightControls()
	self.flightControls = Theme.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 63),
		Size = UDim2.fromOffset(52, 114),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 44,
	}, self.gui)
	local up = Theme.create("TextButton", {
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = Colors.violetDark,
		Text = "↑",
		TextColor3 = Colors.text,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		ZIndex = 45,
	}, self.flightControls)
	local down = Theme.create("TextButton", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = Colors.violetDark,
		Text = "↓",
		TextColor3 = Colors.text,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		ZIndex = 45,
	}, self.flightControls)
	Theme.corner(up, 10)
	Theme.corner(down, 10)
	local upInput, downInput = nil, nil
	local function update()
		if self.flightCallback then self.flightCallback(upInput ~= nil, downInput ~= nil) end
	end
	self.releaseFlightTouches = function()
		upInput, downInput = nil, nil
		update()
	end
	self.maid:give(up.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			upInput = input
			update()
		end
	end))
	self.maid:give(down.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			downInput = input
			update()
		end
	end))
	-- Track each touch separately so releasing the joystick does not cancel ascent.
	self.maid:give(userInputService.InputEnded:Connect(function(input)
		if upInput and (input == upInput or (upInput.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseButton1)) then upInput = nil end
		if downInput and (input == downInput or (downInput.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseButton1)) then downInput = nil end
		update()
	end))
end

---Toggle touch flight controls when the user opens or minimizes the panel.
---@param enabled boolean
---@param callback function
function Library:setFlightControls(enabled, callback)
	self.flightActive = enabled
	self.flightCallback = callback
	self:updateFlightVisibility()
end

function Library:updateFlightVisibility()
	local shouldShow = self.flightActive and userInputService.TouchEnabled
		and (not self.visible or self.minimized)
	if self.flightControls.Visible and not shouldShow then self.releaseFlightTouches() end
	self.flightControls.Visible = shouldShow
	self.sideToast.Position = UDim2.new(1, -12, 0, shouldShow and 185 or 63)
end

---Protect GUI callbacks without suppressing useful error details in the executor console.
---@param callback function
---@return any
function Library:call(callback, ...)
	local args = table.pack(...)
	local ok, result = xpcall(function()
		return callback(table.unpack(args, 1, args.n))
	end, onCallbackError)
	if not ok then
		self:notify("action failed; check executor console", false)
		return false
	end
	return result
end

---Wire dragging, resizing, launcher visibility, and responsive screen changes.
function Library:connectInputs()
	self.maid:give(self.launcher.Activated:Connect(function()
		self:setVisible(not self.visible)
	end))
	self.maid:give(self.closeButton.Activated:Connect(function()
		self:setVisible(false)
	end))
	self.maid:give(self.collapseButton.Activated:Connect(function()
		self.minimized = not self.minimized
		self.collapseButton.Text = self.minimized and "+" or "−"
		self:updateViewport(true)
		self:updateFlightVisibility()
	end))
	self.maid:give(self.moreButton.Activated:Connect(function()
		self.detailsOpen = not self.detailsOpen
		self.moreButton.Text = self.detailsOpen and "▾ less" or "▸ more"
		self:updateViewport(true)
	end))
	self.maid:give(self.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self:filterPages()
	end))
	self.maid:give(self.stopButton.Activated:Connect(function()
		if self.onStop then self:call(self.onStop) end
	end))
	self.maid:give(self.fireButton.Activated:Connect(function()
		if self.onFire then self:call(self.onFire) end
	end))
	self.maid:give(self.header.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if input.Position.X > self.window.AbsolutePosition.X + self.window.AbsoluteSize.X - 90 then return end
		self.dragInput = input
		self.dragStart = input.Position
		self.dragPosition = Vector2.new(self.window.Position.X.Offset, self.window.Position.Y.Offset)
	end))
	self.maid:give(self.resizeGrip.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		self.resizeInput = input
		self.resizeStart = input.Position
		self.resizeSize = self.window.AbsoluteSize
	end))
	self.maid:give(userInputService.InputChanged:Connect(function(input)
		if self.dragInput and (input == self.dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local delta = input.Position - self.dragStart
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
			local width, height = self.window.AbsoluteSize.X, self.window.AbsoluteSize.Y
			local left = math.clamp(self.dragPosition.X + delta.X, 0, math.max(0, viewport.X - width))
			local top = math.clamp(self.dragPosition.Y + delta.Y, 0, math.max(0, viewport.Y - height - 12))
			self.window.Position = UDim2.fromOffset(left, top)
			self.dragged = true
		elseif self.resizeInput and (input == self.resizeInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local delta = input.Position - self.resizeStart
			self.userWidth = self.resizeSize.X + delta.X
			self.userHeight = self.resizeSize.Y + delta.Y
			self:updateViewport()
		end
	end))
	self.maid:give(userInputService.InputEnded:Connect(function(input)
		if self.dragInput and (input == self.dragInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
			self.dragInput = nil
		end
		if self.resizeInput and (input == self.resizeInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
			self.resizeInput = nil
		end
	end))
	local function connectCamera()
		if self.cameraConnection then self.cameraConnection:Disconnect() end
		local camera = workspace.CurrentCamera
		if camera then
			self.cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:updateViewport()
			end)
		end
		self:updateViewport()
	end
	self.maid:give(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera))
	self.maid:give(function()
		if self.cameraConnection then self.cameraConnection:Disconnect() end
	end)
	connectCamera()
end

---Reflow the same page for portrait phones, landscape phones, tablets, and desktops.
---@param animate boolean?
function Library:updateViewport(animate)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
	if viewport.X < 100 or viewport.Y < 100 then return end
	self.compact = self.config.compact or viewport.X < 620
		or (userInputService.TouchEnabled and viewport.Y < 520)
	local short = viewport.Y < 520
	local medium = not short and viewport.Y < 690
	local heroHeight = short and 0 or (medium and 94 or 126)
	local statsHeight = (short or medium) and 0 or 55
	local searchHeight = short and 40 or 48
	local navHeight = short and 54 or (medium and 64 or 72)
	local moreHeight = short and 20 or 24
	local footerHeight = short and 58 or (medium and 68 or 76)
	local top = HEADER_HEIGHT
	self.hero.Visible = heroHeight > 0 and not self.minimized
	self.hero.Position = UDim2.fromOffset(10, top + 4)
	self.hero.Size = UDim2.new(1, -20, 0, math.max(0, heroHeight - 8))
	self.heroTitle.Visible = not medium
	self.heroSummary.Position = UDim2.fromOffset(13, medium and 36 or 70)
	top += heroHeight
	self.searchBox.Position = UDim2.fromOffset(10, top + 4)
	self.searchBox.Size = UDim2.new(1, -20, 0, searchHeight - 8)
	top += searchHeight
	self.metrics.Visible = statsHeight > 0 and not self.minimized
	self.metrics.Position = UDim2.fromOffset(10, top)
	self.metrics.Size = UDim2.new(1, -20, 0, math.max(0, statsHeight - 3))
	top += statsHeight
	self.nav.Position = UDim2.fromOffset(10, top + 3)
	self.nav.Size = UDim2.new(1, -20, 0, navHeight - 6)
	top += navHeight
	self.moreBar.Position = UDim2.fromOffset(0, top)
	self.moreBar.Size = UDim2.new(1, 0, 0, moreHeight)
	top += moreHeight
	local availableHeight = math.max(280, viewport.Y - (self.compact and 70 or 38))
	local fullHeight = self.compact and availableHeight or math.min(self.userHeight, availableHeight)
	local width = self.compact and math.min(450, viewport.X - 12)
		or math.clamp(self.userWidth, math.min(440, viewport.X - 16), viewport.X - 16)
	fullHeight = math.max(math.min(availableHeight, top + footerHeight + 72), fullHeight)
	local height = self.minimized and HEADER_HEIGHT or (self.detailsOpen and fullHeight or top + footerHeight)
	local targetSize = UDim2.fromOffset(width, height)
	if animate then Theme.tween(self.window, {Size = targetSize}, 0.22)
	else self.window.Size = targetSize end
	local left = self.dragged and self.window.Position.X.Offset or (viewport.X - width) / 2
	local topPosition = self.dragged and self.window.Position.Y.Offset
		or (self.compact and 56 or (viewport.Y - height) / 2 - 16)
	left = math.clamp(left, 0, math.max(0, viewport.X - width))
	topPosition = math.clamp(topPosition, 0, math.max(0, viewport.Y - height - 12))
	local targetPosition = UDim2.fromOffset(left, topPosition)
	if animate then Theme.tween(self.window, {Position = targetPosition}, 0.22)
	else self.window.Position = targetPosition end
	self.footer.Position = UDim2.new(0, 0, 1, -footerHeight)
	self.footer.Size = UDim2.new(1, 0, 0, footerHeight)
	self.content.Position = UDim2.fromOffset(0, top)
	self.content.Size = UDim2.new(1, 0, 1, -(top + footerHeight))
	self.toast.Position = UDim2.new(0.5, 0, 1, -footerHeight - 8)
	self.searchBox.Visible = not self.minimized
	self.nav.Visible = not self.minimized
	self.moreBar.Visible = not self.minimized
	self.content.Visible = not self.minimized and self.detailsOpen
	self.footer.Visible = not self.minimized
	self.closeButton.Visible = not userInputService.TouchEnabled
	self.collapseButton.Position = UDim2.new(1, userInputService.TouchEnabled and -10 or -52, 0.5, 0)
	self.resizeGrip.Visible = not self.compact and not self.minimized
	self.moreHint.Text = userInputService.TouchEnabled and "touch menu · open / close" or "drag corner · resize"
	self.launcher.Visible = userInputService.TouchEnabled or not self.visible
	self.launcher.Text = self.visible and "hide" or "open"
	self:updateFlightVisibility()
end

---Animate closing without losing the always-available mobile launcher.
---@param visible boolean
function Library:setVisible(visible)
	if self.visible == visible then return end
	self.visible = visible
	self.visibilityToken = (self.visibilityToken or 0) + 1
	local token = self.visibilityToken
	if visible then
		self.window.Visible = true
		self.window.GroupTransparency = 1
		self:updateViewport()
		Theme.tween(self.window, {GroupTransparency = 0}, 0.2)
	else
		Theme.tween(self.window, {GroupTransparency = 1}, 0.16)
		task.delay(0.17, function()
			if self.visibilityToken == token and self.window.Parent then
				self.window.Visible = false
				self:updateFlightVisibility()
			end
		end)
	end
	self.launcher.Visible = userInputService.TouchEnabled or not visible
	self.launcher.Text = visible and "hide" or "open"
	self:updateFlightVisibility()
end

---Show brief, lowercase status feedback without piling up notification loops.
---@param message string
---@param success boolean?
function Library:notify(message, success)
	if not self.gui.Parent then return end
	self.toastToken += 1
	local token = self.toastToken
	local toast = self.visible and not self.minimized and self.toast or self.sideToast
	self.toast.Visible = false
	self.sideToast.Visible = false
	toast.Text = tostring(message):lower()
	toast.TextColor3 = success == false and Colors.violetLight or Colors.text
	toast.Visible = true
	toast.TextTransparency = 0
	task.delay(2.7, function()
		if self.toastToken == token and toast.Parent then
			Theme.tween(toast, {TextTransparency = 1}, 0.2)
			task.delay(0.22, function()
				if self.toastToken == token and toast.Parent then toast.Visible = false end
			end)
		end
	end)
end

---Update the hero and metric readout without rebuilding active controls.
---@param targets number
---@param players number
function Library:setSummary(targets, players)
	self.heroSummary.Text = tostring(targets) .. " others  ·  " .. tostring(players) .. " players  ·  "
		.. (self.labels.summarySuffix or "private server")
	self.targetMetric.Text = "other players    " .. tostring(targets)
	self.serverMetric.Text = "server    " .. (self.labels.serverState or "client only")
end

---Install searchable page tiles and choose an initial category.
---@param pages table
function Library:setPages(pages)
	self.pages = pages
	for _, button in pairs(self.navButtons) do button:Destroy() end
	self.navButtons = {}
	for index, page in ipairs(pages) do
		local button = Theme.create("TextButton", {
			Name = page.id,
			Size = UDim2.fromOffset(101, 46),
			BackgroundColor3 = Colors.violetDark,
			BorderSizePixel = 0,
			Text = "",
			LayoutOrder = index,
			AutoButtonColor = false,
			ClipsDescendants = true,
		}, self.nav)
		Theme.corner(button, 6)
		Theme.create("Frame", {
			Position = UDim2.new(0.75, 0, 0, -12),
			Size = UDim2.fromOffset(15, 85),
			Rotation = 38,
			BackgroundColor3 = Colors.violetLight,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
		}, button)
		createText(button, page.label, UDim2.fromOffset(6, 6), UDim2.new(1, -12, 0, 21),
			Enum.Font.GothamMedium, 12, Colors.text, Enum.TextXAlignment.Center)
		createText(button, page.subtitle or "", UDim2.fromOffset(4, 27), UDim2.new(1, -8, 0, 15),
			Enum.Font.Gotham, 9, Colors.text, Enum.TextXAlignment.Center)
		self.maid:give(button.Activated:Connect(function() self:selectPage(page.id) end))
		self.navButtons[page.id] = button
	end
	self:filterPages()
end

---Search titles and feature keywords instead of hiding only exact tab names.
function Library:filterPages()
	local query = self.searchBox.Text:lower():match("^%s*(.-)%s*$")
	local firstMatch, currentVisible = nil, false
	for _, page in ipairs(self.pages) do
		local haystack = (page.label .. " " .. (page.subtitle or "") .. " " .. (page.keywords or "")):lower()
		local matches = query == "" or haystack:find(query, 1, true) ~= nil
		self.navButtons[page.id].Visible = matches
		if matches then
			firstMatch = firstMatch or page.id
			if self.currentPage == page.id then currentVisible = true end
		end
	end
	if not currentVisible and firstMatch then self:selectPage(firstMatch) end
end

---Destroy page-scoped controls and connections before rendering another category.
---@param id string
function Library:selectPage(id)
	local selected
	for _, page in ipairs(self.pages) do
		if page.id == id then selected = page; break end
	end
	if not selected then return end
	self.currentPage = id
	self:refreshPage()
	for pageId, button in pairs(self.navButtons) do
		Theme.tween(button, {BackgroundColor3 = pageId == id and Colors.violet or Colors.violetDark}, 0.16)
	end
end

---Render current controls while isolating errors to the affected page.
function Library:refreshPage()
	self.pageMaid:clean()
	self.capturingKey = false
	for _, child in ipairs(self.content:GetChildren()) do
		if not child:IsA("UIPadding") and not child:IsA("UIListLayout") then child:Destroy() end
	end
	self.order = 0
	self.content.CanvasPosition = Vector2.zero
	for _, page in ipairs(self.pages) do
		if page.id == self.currentPage then
			self:call(page.render, self)
			return
		end
	end
end

function Library:nextOrder()
	self.order += 1
	return self.order
end

---Separate feature groups with the screenshot's understated heading hierarchy.
---@param title string
---@param subtitle string?
function Library:section(title, subtitle)
	local height = subtitle and 51 or 29
	local holder = Theme.create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = self:nextOrder(),
	}, self.content)
	createText(holder, title, UDim2.fromOffset(6, 0), UDim2.new(1, -12, 0, 26),
		Enum.Font.GothamBold, 12, Colors.violetLight)
	if subtitle then
		createText(holder, subtitle, UDim2.fromOffset(6, 23), UDim2.new(1, -12, 0, 26),
			Enum.Font.Gotham, 11, Colors.muted)
	end
end

---Show a compact toggle with a large hit target and animated thumb.
---@param title string
---@param enabled boolean
---@param onChange function
---@param hint string?
function Library:toggle(title, enabled, onChange, hint)
	local height = hint and 61 or 48
	local row = Theme.create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Colors.surface,
		BorderSizePixel = 0,
		LayoutOrder = self:nextOrder(),
	}, self.content)
	Theme.corner(row, 7)
	createText(row, title, UDim2.fromOffset(12, 4), UDim2.new(1, -86, 0, 28),
		Enum.Font.GothamMedium, 13)
	if hint then
		createText(row, hint, UDim2.fromOffset(12, 29), UDim2.new(1, -86, 0, 24),
			Enum.Font.Gotham, 10, Colors.muted)
	end
	local pill = Theme.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(46, 25),
		BackgroundColor3 = enabled and Colors.violet or Colors.deep,
		BorderSizePixel = 0,
	}, row)
	Theme.corner(pill, 13)
	Theme.stroke(pill, Colors.violet)
	local thumb = Theme.create("Frame", {
		Position = UDim2.fromOffset(enabled and 24 or 3, 3),
		Size = UDim2.fromOffset(19, 19),
		BackgroundColor3 = enabled and Colors.text or Colors.violet,
		BorderSizePixel = 0,
	}, pill)
	Theme.corner(thumb, 10)
	local hitArea = Theme.create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
	}, row)
	local pending = false
	hitArea.Activated:Connect(function()
		if pending then return end
		pending = true
		local accepted = self:call(onChange, not enabled)
		pending = false
		if accepted == false or not row.Parent then return end
		enabled = not enabled
		Theme.tween(pill, {BackgroundColor3 = enabled and Colors.violet or Colors.deep})
		Theme.tween(thumb, {
			Position = UDim2.fromOffset(enabled and 24 or 3, 3),
			BackgroundColor3 = enabled and Colors.text or Colors.violet,
		})
	end)
end

---Allow both touch dragging and mouse dragging with one page-scoped listener.
---@param title string
---@param minimum number
---@param maximum number
---@param value number
---@param onChange function
---@param format function?
---@param step number?
---@param resetValue number?
function Library:slider(title, minimum, maximum, value, onChange, format, step, resetValue)
	local holder = Theme.create("Frame", {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Colors.surface,
		BorderSizePixel = 0,
		LayoutOrder = self:nextOrder(),
	}, self.content)
	Theme.corner(holder, 7)
	local display = format or function(number) return tostring(number) end
	createText(holder, title, UDim2.fromOffset(12, 1), UDim2.new(0.55, -12, 0, 27),
		Enum.Font.GothamMedium, 13)
	local valueLabel = createText(holder, display(value), UDim2.new(0.55, 0, 0, 1),
		UDim2.new(0.45, -12, 0, 27), Enum.Font.Gotham, 12, Colors.violetLight, Enum.TextXAlignment.Right)
	local bar = Theme.create("Frame", {
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.new(1, -63, 0, 5),
		BackgroundColor3 = Colors.track,
		BorderSizePixel = 0,
	}, holder)
	Theme.corner(bar, 3)
	local fill = Theme.create("Frame", {
		Size = UDim2.new(math.clamp((value - minimum) / (maximum - minimum), 0, 1), 0, 1, 0),
		BackgroundColor3 = Colors.violet,
		BorderSizePixel = 0,
	}, bar)
	Theme.corner(fill, 3)
	local knob = Theme.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(math.clamp((value - minimum) / (maximum - minimum), 0, 1), 0, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Colors.deep,
		BorderSizePixel = 0,
	}, bar)
	Theme.corner(knob, 10)
	Theme.stroke(knob, Colors.violetLight)
	local hitArea = Theme.create("Frame", {
		Position = UDim2.fromOffset(6, 27),
		Size = UDim2.new(1, -48, 0, 36),
		BackgroundTransparency = 1,
		Active = true,
	}, holder)
	local reset = Theme.create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -4),
		Size = UDim2.fromOffset(38, 37),
		BackgroundTransparency = 1,
		Text = "↺",
		TextColor3 = Colors.muted,
		TextSize = 19,
		Font = Enum.Font.Gotham,
	}, holder)
	local dragging = nil
	local function update(newValue)
		local increments = step or 1
		newValue = math.clamp(math.floor((newValue - minimum) / increments + 0.5) * increments + minimum, minimum, maximum)
		if value == newValue then return end
		value = newValue
		local alpha = (value - minimum) / (maximum - minimum)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = tostring(display(value)):lower()
		self:call(onChange, value)
	end
	local function updateFromInput(input)
		if bar.AbsoluteSize.X <= 0 then return end
		local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		update(minimum + (maximum - minimum) * alpha)
	end
	hitArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = input
			updateFromInput(input)
		end
	end)
	self.pageMaid:give(userInputService.InputChanged:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement) then
			updateFromInput(input)
		end
	end))
	self.pageMaid:give(userInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
		end
	end))
	reset.Activated:Connect(function() update(resetValue or minimum) end)
end

---Provide large action rows for catalogs, quick teleports, and manual drills.
---@param title string
---@param subtitle string?
---@param callback function
---@param emphasized boolean?
function Library:action(title, subtitle, callback, emphasized)
	local button = Theme.create("TextButton", {
		Size = UDim2.new(1, 0, 0, subtitle and 56 or 44),
		BackgroundColor3 = emphasized and Colors.violetDark or Colors.surface,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = self:nextOrder(),
	}, self.content)
	Theme.corner(button, 7)
	createText(button, title, UDim2.fromOffset(12, subtitle and 5 or 9),
		UDim2.new(1, -43, 0, 25), Enum.Font.GothamMedium, 13)
	if subtitle then
		createText(button, subtitle, UDim2.fromOffset(12, 29), UDim2.new(1, -43, 0, 18),
			Enum.Font.Gotham, 10, Colors.muted)
	end
	createText(button, "›", UDim2.new(1, -31, 0, 0), UDim2.fromOffset(23, button.Size.Y.Offset),
		Enum.Font.GothamBold, 18, Colors.violetLight, Enum.TextXAlignment.Center)
	button.Activated:Connect(function() self:call(callback) end)
end

---Show read-only player and server details without interactive side effects.
---@param title string
---@param value any
function Library:info(title, value)
	local row = Theme.create("Frame", {
		Size = UDim2.new(1, 0, 0, 37),
		BackgroundColor3 = Colors.surface,
		BorderSizePixel = 0,
		LayoutOrder = self:nextOrder(),
	}, self.content)
	Theme.corner(row, 6)
	createText(row, title, UDim2.fromOffset(12, 0), UDim2.new(0.5, -12, 1, 0),
		Enum.Font.Gotham, 12, Colors.muted)
	createText(row, tostring(value), UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -12, 1, 0),
		Enum.Font.GothamMedium, 12, Colors.text, Enum.TextXAlignment.Right)
end

---Capture a short label or bookmark name without expanding the page layout.
---@param title string
---@param placeholder string
---@param onCommit function
function Library:textInput(title, placeholder, onCommit)
	local holder = Theme.create("Frame", {
		Size = UDim2.new(1, 0, 0, 47),
		BackgroundColor3 = Colors.surface,
		BorderSizePixel = 0,
		LayoutOrder = self:nextOrder(),
	}, self.content)
	Theme.corner(holder, 7)
	createText(holder, title, UDim2.fromOffset(12, 0), UDim2.new(0.36, -12, 1, 0),
		Enum.Font.GothamMedium, 12)
	local input = Theme.create("TextBox", {
		Position = UDim2.new(0.36, 0, 0, 6),
		Size = UDim2.new(0.64, -9, 1, -12),
		BackgroundColor3 = Colors.deep,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		PlaceholderText = placeholder:lower(),
		PlaceholderColor3 = Colors.muted,
		Text = "",
		TextColor3 = Colors.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 12,
	}, holder)
	Theme.corner(input, 5)
	Theme.create("UIPadding", {PaddingLeft = UDim.new(0, 9)}, input)
	input:GetPropertyChangedSignal("Text"):Connect(function()
		self:call(onCommit, input.Text)
	end)
	input.FocusLost:Connect(function()
		input.Text = input.Text:lower():sub(1, 32)
		self:call(onCommit, input.Text)
	end)
	return input
end

---Let users remap a keyboard action with escape-to-cancel behavior.
---@param title string
---@param current string
---@param onBind function
function Library:keybind(title, current, onBind)
	local button = Theme.create("TextButton", {
		Size = UDim2.new(1, 0, 0, 45),
		BackgroundColor3 = Colors.surface,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = self:nextOrder(),
	}, self.content)
	Theme.corner(button, 7)
	createText(button, title, UDim2.fromOffset(12, 0), UDim2.new(0.62, -12, 1, 0),
		Enum.Font.GothamMedium, 12)
	local keyLabel = createText(button, current, UDim2.new(0.62, 0, 0, 0),
		UDim2.new(0.38, -13, 1, 0), Enum.Font.GothamBold, 12, Colors.violetLight, Enum.TextXAlignment.Right)
	button.Activated:Connect(function()
		if self.capturingKey then return end
		self.capturingKey = true
		keyLabel.Text = "press key..."
		local connection
		connection = userInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			connection:Disconnect()
			self.capturingKey = false
			if input.KeyCode == Enum.KeyCode.Escape then
				keyLabel.Text = current:lower()
				return
			end
			local accepted = self:call(onBind, input.KeyCode.Name)
			if accepted ~= false then current = input.KeyCode.Name end
			if keyLabel.Parent then keyLabel.Text = current:lower() end
		end)
		self.pageMaid:give(connection)
	end)
end

---Allow the entry point to provide persistent footer actions.
---@param onStop function
---@param onFire function
function Library:setFooterActions(onStop, onFire)
	self.onStop = onStop
	self.onFire = onFire
end

---Disconnect viewport, input, and page listeners before destroying the GUI.
function Library:destroy()
	self.pageMaid:clean()
	self.maid:clean()
	self.gui:Destroy()
end

return Library
