local function xsave_gui(defaults)
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")

	local caps = getCapabilities()
	local options = schemaDefaults()
	local profile = Storage.read("profile.json")
	if type(profile) == "table" then
		for key, value in profile do
			if options[key] ~= nil and type(value) == type(options[key]) then
				options[key] = value
			end
		end
	end
	if type(defaults) == "table" then
		for key, value in defaults do
			options[key] = value
		end
	end

	local state = {
		scan = nil, scanning = false, scanToken = 0, plan = nil, alive = true, saveToken = 0,
		minimized = false, compact = false, dragged = false, drag = nil, closeArmed = false,
		footerHeight = 80, result = nil, wasRunning = false, rail = false,
	}
	local ui, controls, groupEntries = {}, {}, {}
	local orders = setmetatable({}, { __mode = "k" })

	local C = {
		bg = Color3.fromRGB(15, 16, 20),
		surface = Color3.fromRGB(23, 25, 31),
		raised = Color3.fromRGB(34, 37, 46),
		raised2 = Color3.fromRGB(54, 58, 72),
		line = Color3.fromRGB(40, 43, 53),
		text = Color3.fromRGB(237, 238, 243),
		sub = Color3.fromRGB(160, 165, 178),
		faint = Color3.fromRGB(128, 133, 148),
		muted = Color3.fromRGB(86, 92, 108),
		accent = Color3.fromRGB(99, 132, 255),
		good = Color3.fromRGB(82, 196, 132),
		warn = Color3.fromRGB(235, 172, 66),
		bad = Color3.fromRGB(226, 88, 88),
	}
	local FONT, MEDIUM, BOLD = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold
	local HEADER, TABS, RAIL = 52, 48, 196

	local existing = GLOBAL_ENV.XSAVE_GUI
	if existing then
		pcall(function()
			existing:Destroy()
		end)
	end

	local function make(className, props, parent)
		local inst = Instance.new(className)
		for key, value in props do
			inst[key] = value
		end
		if parent then
			if props.LayoutOrder == nil and inst:IsA("GuiObject") and parent:FindFirstChildOfClass("UIListLayout") then
				local n = (orders[parent] or 0) + 1
				orders[parent] = n
				inst.LayoutOrder = n
			end
			inst.Parent = parent
		end
		return inst
	end

	local function round(parent, radius)
		return make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
	end

	local function outline(parent, color)
		return make("UIStroke", { Color = color or C.line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
	end

	local function pad(parent, left, top, right, bottom)
		return make("UIPadding", {
			PaddingLeft = UDim.new(0, left), PaddingTop = UDim.new(0, top),
			PaddingRight = UDim.new(0, right), PaddingBottom = UDim.new(0, bottom),
		}, parent)
	end

	local function stack(parent, gap)
		return make("UIListLayout", { Padding = UDim.new(0, gap or 8), SortOrder = Enum.SortOrder.LayoutOrder }, parent)
	end

	local function tween(inst, props, seconds)
		TweenService:Create(inst, TweenInfo.new(seconds or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	end

	local function text(parent, content, size, color, weight, props)
		local label = make("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, size + 4), AutomaticSize = Enum.AutomaticSize.Y,
			Font = weight or FONT, Text = content, TextColor3 = color or C.text, TextSize = size, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		}, parent)
		if props then
			for key, value in props do
				label[key] = value
			end
		end
		return label
	end

	local function hex(color)
		return string.format("#%02x%02x%02x", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
	end

	local function button(parent, content, color, size, textColor)
		local base = color
		local btn = make("TextButton", {
			AutoButtonColor = false, BackgroundColor3 = color, BorderSizePixel = 0, Size = size, Font = BOLD, Text = content,
			TextColor3 = textColor or Color3.new(1, 1, 1), TextSize = 14,
		}, parent)
		round(btn, 10)
		btn.MouseEnter:Connect(function()
			tween(btn, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.1) }, 0.1)
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, { BackgroundColor3 = base }, 0.1)
		end)
		return btn
	end

	local function setEnabled(btn, enabled)
		btn.BackgroundTransparency = enabled and 0 or 0.7
		btn.TextTransparency = enabled and 0 or 0.5
		btn.Active = enabled
	end

	local function segmented(parent, items, height, selectedColor, onSelect)
		local holder = make("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.raised, BorderSizePixel = 0 }, parent)
		round(holder, 10)
		local count = #items
		local pill = make("Frame", { Size = UDim2.new(1 / count, -6, 1, -6), Position = UDim2.new(0, 3, 0, 3), BackgroundColor3 = selectedColor, BorderSizePixel = 0 }, holder)
		round(pill, 8)
		local buttons = {}
		for i, name in items do
			local btn = make("TextButton", {
				BackgroundTransparency = 1, AutoButtonColor = false, Position = UDim2.fromScale((i - 1) / count, 0),
				Size = UDim2.fromScale(1 / count, 1), Font = BOLD, Text = name, TextColor3 = C.sub, TextSize = 13, ZIndex = 2,
			}, holder)
			btn.Activated:Connect(function()
				onSelect(i)
			end)
			buttons[i] = btn
		end
		local api = { holder = holder }
		function api.set(index, instant)
			pill.Visible = index ~= nil
			if index then
				local goal = UDim2.new((index - 1) / count, 3, 0, 3)
				if instant then
					pill.Position = goal
				else
					tween(pill, { Position = goal }, 0.18)
				end
			end
			for i, btn in buttons do
				btn.TextColor3 = i == index and Color3.new(1, 1, 1) or C.sub
			end
		end
		return api
	end

	local function effective()
		local result = table.clone(options)
		for _, group in SCHEMA do
			for _, item in group.items do
				if item.needs and not caps[item.needs] then
					result[item.key] = false
				end
			end
		end
		result.Mode = string.lower(tostring(result.Mode))
		return result
	end

	local function isLocked(item)
		return item.needs ~= nil and not caps[item.needs]
	end

	local gui = make("ScreenGui", { Name = "xsave_gui", ResetOnSpawn = false, DisplayOrder = 2e9 })
	pcall(function()
		gui.OnTopOfCoreBlur = true
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	local parented = false
	if global_container.gethui then
		parented = pcall(function()
			gui.Parent = global_container.gethui()
		end)
	end
	if not parented then
		if global_container.protectgui then
			pcall(global_container.protectgui, gui)
		end
		parented = pcall(function()
			gui.Parent = game:GetService("CoreGui")
		end)
	end
	if not parented then
		gui.Parent = service.Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	GLOBAL_ENV.XSAVE_GUI = gui

	local window = make("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 560), BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true,
	}, gui)
	round(window, 16)
	outline(window)
	local windowScale = make("UIScale", { Scale = 0.96 }, window)

	local pill = make("Frame", {
		Name = "Pill", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.surface, BorderSizePixel = 0, Visible = false, Active = true,
	}, gui)
	round(pill, 20)
	outline(pill)
	pad(pill, 14, 0, 16, 0)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, pill)
	local pillMark = make("Frame", { Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.faint, BorderSizePixel = 0 }, pill)
	round(pillMark, 4)
	ui.pillText = make("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Font = BOLD,
		Text = "xsave", TextColor3 = C.text, TextSize = 13,
	}, pill)
	local pillScale = make("UIScale", { Scale = 1 }, pill)

	local header = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, HEADER), Active = true }, window)
	ui.titleFull = string.format('xsave  <font color="%s" size="12">%s</font>', hex(C.faint), "1.1.0")
	ui.title = make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -120, 1, 0), Font = BOLD, RichText = true,
		Text = ui.titleFull,
		TextColor3 = C.text, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
	}, header)

	local function iconButton(content, xOffset)
		local btn = make("TextButton", {
			AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.surface, BorderSizePixel = 0, Font = BOLD, Text = content,
			TextColor3 = C.sub, TextSize = 18,
		}, header)
		round(btn, 10)
		btn.MouseEnter:Connect(function()
			tween(btn, { BackgroundColor3 = C.raised, TextColor3 = C.text }, 0.1)
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, { BackgroundColor3 = C.surface, TextColor3 = C.sub }, 0.1)
		end)
		return btn
	end
	local closeButton = iconButton("×", -10)
	local minimizeButton = iconButton("–", -54)

	local tabsHolder = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, HEADER), Size = UDim2.new(1, 0, 0, TABS) }, window)
	pad(tabsHolder, 16, 4, 16, 8)

	local body = make("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, HEADER + TABS),
		Size = UDim2.new(1, 0, 1, -(HEADER + TABS + state.footerHeight)), ClipsDescendants = true,
	}, window)

	local footer = make("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, state.footerHeight),
		BackgroundColor3 = C.surface, BorderSizePixel = 0, ZIndex = 5,
	}, window)
	make("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.line, BorderSizePixel = 0, ZIndex = 5 }, footer)
	ui.railLine = make("Frame", { Position = UDim2.fromOffset(RAIL, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.line, BorderSizePixel = 0, ZIndex = 6, Visible = false }, window)

	local function setFooterHeight(height)
		state.footerHeight = height
		if state.rail then
			return -- the rail layout has a fixed footer
		end
		tween(footer, { Size = UDim2.new(1, 0, 0, height) }, 0.2)
		tween(body, { Size = UDim2.new(1, 0, 1, -(HEADER + TABS + height)) }, 0.2)
	end

	local pages = {}
	local function showTab(index)
		for i, page in pages do
			page.Visible = i == index
		end
		ui.tabs.set(index, false)
	end
	ui.tabs = segmented(tabsHolder, { "Overview", "Settings" }, 36, C.raised2, showTab)

	for i = 1, 2 do
		local page = make("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = C.raised2, Visible = false,
		}, body)
		pad(page, 16, 8, 16, 20)
		stack(page, 16)
		pages[i] = page
	end
	local overview, settings = pages[1], pages[2]
	settings:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 8)

	local hero = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56) }, overview)
	local iconHolder = make("Frame", { Size = UDim2.fromOffset(56, 56), BackgroundColor3 = C.raised, BorderSizePixel = 0, ClipsDescendants = true }, hero)
	round(iconHolder, 14)
	ui.initial = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = BOLD, Text = "?", TextColor3 = C.faint, TextSize = 22 }, iconHolder)
	if game.GameId ~= 0 then
		make("ImageLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop,
			Image = string.format("rbxthumb://type=GameIcon&id=%d&w=150&h=150", game.GameId),
		}, iconHolder)
	end
	local function heroLine(y, size, color, weight)
		return make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(70, y), Size = UDim2.new(1, -70, 0, size + 3), Font = weight or FONT,
			Text = "", TextColor3 = color, TextSize = size, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, hero)
	end
	ui.gameName = heroLine(2, 17, C.text, BOLD)
	ui.gameName.Text = game.PlaceId == 0 and "Local place" or "Loading…"
	ui.gameIds = heroLine(25, 12, C.sub)
	ui.gameIds.Text = string.format("Place %d  ·  Universe %d", game.PlaceId, game.GameId)
	ui.gameMeta = heroLine(41, 12, C.faint)

	task.spawn(function()
		local info = getGameInfo()
		if not state.alive then
			return
		end
		ui.gameName.Text = info.name
		ui.initial.Text = string.upper(string.sub(info.name, 1, 1))
		ui.gameMeta.Text = (info.creator ~= "" and (info.creator .. "  ·  ") or "")
			.. string.format("%d/%d players", info.players, info.maxPlayers)
	end)

	local presetBlock = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, overview)
	stack(presetBlock, 8)
	text(presetBlock, "Preset", 12, C.sub, MEDIUM)

	local function matchedPreset()
		for i, preset in PRESETS do
			local same = true
			for key, value in preset.values do
				if options[key] ~= value then
					same = false
					break
				end
			end
			if same then
				return i
			end
		end
		return nil
	end

	local refreshEstimate, persistSoon, refreshControls

	local function applyValues(values)
		if Control.Running then
			return
		end
		for key, value in values do
			options[key] = value
		end
		refreshControls(false)
		persistSoon()
		refreshEstimate()
	end

	ui.presets = segmented(presetBlock, { "Fast", "Balanced", "Complete", "Custom" }, 40, C.accent, function(index)
		if index == #PRESETS + 1 then
			showTab(2)
		else
			applyValues(PRESETS[index].values)
		end
	end)

	local function refreshPresetUI(instant)
		ui.presets.set(matchedPreset() or (#PRESETS + 1), instant)
	end

	local estimate = make("Frame", { BackgroundColor3 = C.surface, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, overview)
	round(estimate, 14)
	pad(estimate, 16, 16, 16, 16)
	stack(estimate, 14)

	local bigRow = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56) }, estimate)
	local function big(index, caption)
		local holder = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale((index - 1) / 2, 0), Size = UDim2.fromScale(0.5, 1) }, bigRow)
		local value = make("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Font = BOLD, Text = "-", TextColor3 = C.text, TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, holder)
		make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 16), Font = FONT, Text = caption,
			TextColor3 = C.sub, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
		}, holder)
		return value
	end
	ui.estTime = big(1, "Estimated time")
	ui.estSize = big(2, "Estimated size")

	ui.barHolder = make("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = C.raised, BorderSizePixel = 0, ClipsDescendants = true }, estimate)
	round(ui.barHolder, 4)
	ui.barA = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, ui.barHolder)
	ui.barB = make("Frame", { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.muted, BorderSizePixel = 0 }, ui.barHolder)

	ui.legend = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16) }, estimate)
	local function legendItem(index, color)
		local dot = make("Frame", { Position = UDim2.new((index - 1) / 2, 0, 0.5, -4), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = color, BorderSizePixel = 0 }, ui.legend)
		round(dot, 4)
		return make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new((index - 1) / 2, 14, 0, 0), Size = UDim2.new(0.5, -14, 1, 0), Font = FONT,
			Text = "", TextColor3 = C.sub, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, ui.legend)
	end
	ui.legendA = legendItem(1, C.accent)
	ui.legendB = legendItem(2, C.muted)

	ui.estNote = text(estimate, "", 12, C.faint)
	ui.banners = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, estimate)
	stack(ui.banners, 8)

	local function setBanners(list)
		for _, child in ui.banners:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		orders[ui.banners] = 0
		for _, entry in list do
			local box = make("Frame", {
				BackgroundColor3 = entry.color:Lerp(C.surface, 0.84), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, ui.banners)
			round(box, 10)
			pad(box, 12, 9, 12, 9)
			text(box, entry.text, 12, entry.color)
		end
	end

	local scanRow = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, overview)
	local scanLeft = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -84, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, scanRow)
	stack(scanLeft, 3)
	ui.scanLine = text(scanLeft, "Waiting to scan…", 14, C.text, MEDIUM)
	ui.scanClasses = text(scanLeft, "", 12, C.faint)
	ui.rescan = make("TextButton", {
		BackgroundTransparency = 1, AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(80, 32), Font = BOLD, Text = "Rescan", TextColor3 = C.text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right,
	}, scanRow)

	local envBlock = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, overview)
	stack(envBlock, 8)
	text(envBlock, "Executor  ·  " .. (EXECUTOR_NAME ~= "" and EXECUTOR_NAME or "Unknown"), 12, C.sub, MEDIUM)
	local chips = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, envBlock)
	local chipLayout = make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, chips)
	pcall(function()
		chipLayout.Wraps = true
	end)
	for _, entry in {
		{ "Decompiler", "decompile" }, { "Bytecode", "getscriptbytecode" }, { "Nil instances", "getnilinstances" },
		{ "Hidden properties", "gethiddenproperty" }, { "File writing", "writefile" },
	} do
		local chip = make("Frame", { Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.surface, BorderSizePixel = 0 }, chips)
		round(chip, 14)
		pad(chip, 10, 0, 12, 0)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, chip)
		local dot = make("Frame", { Size = UDim2.fromOffset(7, 7), BackgroundColor3 = caps[entry[2]] and C.good or C.bad, BorderSizePixel = 0 }, chip)
		round(dot, 4)
		make("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Font = MEDIUM, Text = entry[1],
			TextColor3 = caps[entry[2]] and C.sub or C.text, TextSize = 12,
		}, chip)
	end

	ui.status = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 44), Visible = false, ZIndex = 5 }, footer)
	local track = make("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = C.raised, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5 }, ui.status)
	round(track, 2)
	ui.fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 5 }, track)
	round(ui.fill, 2)
	ui.line1 = make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 11), Size = UDim2.new(1, 0, 0, 18), Font = BOLD, Text = "", TextColor3 = C.text,
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
	}, ui.status)
	ui.line2 = make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, 0, 0, 15), Font = FONT, Text = "", TextColor3 = C.sub,
		TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
	}, ui.status)

	local actions = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.new(1, -32, 0, 48), ZIndex = 5 }, footer)
	local startButton = button(actions, "Start saving", C.accent, UDim2.fromScale(1, 1))
	local stopButton = button(actions, "Stop", C.raised2, UDim2.new(1, -108, 1, 0))
	local killButton = button(actions, "Kill", Color3.fromRGB(190, 62, 62), UDim2.fromOffset(100, 48))
	killButton.AnchorPoint = Vector2.new(1, 0)
	killButton.Position = UDim2.fromScale(1, 0)
	for _, btn in { startButton, stopButton, killButton } do
		btn.TextSize = 15
		btn.ZIndex = 6
	end

	local function setStatus(line1, line2, color, fraction, fillColor)
		ui.line1.Text = line1
		ui.line1.TextColor3 = color or C.text
		ui.line2.Text = line2 or ""
		if fraction then
			ui.fill.BackgroundTransparency = 0
			tween(ui.fill, { Size = UDim2.fromScale(fraction, 1), BackgroundColor3 = fillColor or C.accent }, 0.2)
		else
			ui.fill.BackgroundTransparency = 0.55
			tween(ui.fill, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = fillColor or C.accent }, 0.2)
		end
	end

	local function renderFooter()
		local running = Control.Running
		local showStatus = running or state.result ~= nil
		local target = showStatus and 132 or 80
		if state.footerHeight ~= target then
			setFooterHeight(target)
		end
		ui.status.Visible = showStatus
		startButton.Visible = not running
		stopButton.Visible = running
		killButton.Visible = running
		setEnabled(stopButton, running and not Control.Stop and not Control.Kill)
		setEnabled(killButton, running and not Control.Kill)
		ui.rescan.TextTransparency = (running or state.scanning) and 0.6 or 0
	end

	function refreshEstimate()
		refreshPresetUI(false)
		local opts = effective()
		local scan = state.scan

		if not (scan and scan.done) then
			ui.estTime.Text, ui.estSize.Text = "-", "-"
			ui.barHolder.Visible, ui.legend.Visible = false, false
			ui.estNote.Text = state.scanning and "Waiting for the scan to finish." or "Run a scan to get an estimate."
			setBanners({})
			return
		end

		local result = Estimator.compute(scan, opts)
		ui.estTime.Text = "~ " .. Format.time(result.total)
		ui.estSize.Text = "~ " .. Format.bytes(result.bytes)

		ui.barHolder.Visible, ui.legend.Visible = true, true
		local total = math.max(result.total, 1e-6)
		local share = result.serialize / total
		tween(ui.barA, { Size = UDim2.fromScale(share, 1) }, 0.25)
		ui.barB.Position = UDim2.fromScale(share, 0)
		tween(ui.barB, { Size = UDim2.fromScale(1 - share, 1) }, 0.25)
		ui.legendA.Text = "Serialize  " .. Format.time(result.serialize)
		ui.legendB.Text = opts.Decompile and ("Decompile  " .. Format.time(result.decompile)) or "Decompile off"

		local rates = result.rates
		local note
		if rates.fromHistory then
			note = string.format(
				"Based on %d previous save%s%s.",
				rates.samples,
				rates.samples == 1 and "" or "s",
				rates.matched and " with similar settings" or " with different settings"
			)
		else
			note = "Rough estimate. It gets accurate after your first completed save on this device."
		end
		if result.worst then
			note ..= string.format("\nWorst case %s if every script reaches its timeout.", Format.time(result.worst))
		end
		ui.estNote.Text = note

		local banners = {}
		if options.Decompile and not caps.decompile then
			table.insert(banners, { color = C.warn, text = "This executor has no decompiler, so scripts will be saved empty." })
		end
		if scan.opts.IgnoreNotArchivable ~= opts.IgnoreNotArchivable or scan.opts.SavePlayerCharacters ~= opts.SavePlayerCharacters then
			table.insert(banners, { color = C.warn, text = "Scope settings changed since the scan. Rescan for a precise estimate." })
		end
		if result.bytes > 800 * 1024 * 1024 then
			table.insert(banners, { color = C.bad, text = "Very large output. The file is built in memory, so low-RAM devices may crash." })
		end
		setBanners(banners)
	end

	local function showScan(scan, final)
		if final then
			ui.scanLine.Text = string.format("%s instances  ·  %s scripts", Format.int(scan.total), Format.int(scan.scripts))
		else
			ui.scanLine.Text = string.format("Scanning…  %s instances", Format.int(scan.total))
		end
	end

	local function startScan()
		if state.scanning or Control.Running then
			return
		end
		state.scanToken += 1
		local token = state.scanToken
		state.scanning = true
		state.scan = nil
		ui.scanLine.Text = "Scanning…"
		ui.scanClasses.Text = ""
		refreshEstimate()
		renderFooter()

		task.spawn(function()
			local result = Scanner.run(effective(), function(partial)
				if state.alive and token == state.scanToken then
					showScan(partial, false)
				end
			end, function()
				return not state.alive or token ~= state.scanToken
			end)

			if not state.alive or token ~= state.scanToken then
				return
			end
			state.scanning = false
			showScan(result, true)

			local sorted = {}
			for className, count in result.classes do
				table.insert(sorted, { className, count })
			end
			table.sort(sorted, function(a, b)
				return a[2] > b[2]
			end)
			local parts = {}
			for i = 1, math.min(3, #sorted) do
				parts[i] = string.format("%s %s", sorted[i][1], Format.int(sorted[i][2]))
			end
			ui.scanClasses.Text = string.format("Scanned in %s  ·  %s", Format.time(result.seconds), table.concat(parts, "  ·  "))
			state.scan = result
			refreshEstimate()
			renderFooter()
		end)
	end
	ui.rescan.Activated:Connect(startScan)

	function persistSoon()
		state.saveToken += 1
		local token = state.saveToken
		task.delay(0.8, function()
			if token == state.saveToken then
				Storage.write("profile.json", options)
			end
		end)
	end

	local function changed()
		persistSoon()
		refreshEstimate()
	end

	local searchRow = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42) }, settings)
	local searchBox = make("TextBox", {
		Size = UDim2.new(1, -84, 1, 0), BackgroundColor3 = C.surface, BorderSizePixel = 0, Font = FONT, TextColor3 = C.text, TextSize = 14,
		ClearTextOnFocus = false, Text = "", PlaceholderText = "Search settings", PlaceholderColor3 = C.faint,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, searchRow)
	round(searchBox, 10)
	pad(searchBox, 14, 0, 14, 0)
	local resetButton = button(searchRow, "Reset", C.surface, UDim2.fromOffset(76, 42), C.sub)
	resetButton.AnchorPoint = Vector2.new(1, 0)
	resetButton.Position = UDim2.fromScale(1, 0)
	resetButton.Activated:Connect(function()
		applyValues(schemaDefaults())
	end)

	local function applyFilter()
		local query = string.lower(searchBox.Text)
		for _, group in groupEntries do
			local lastVisible, anyVisible = nil, false
			for _, entry in group.rows do
				local visible = query == "" or string.find(entry.haystack, query, 1, true) ~= nil
				entry.row.Visible = visible
				entry.divider.Visible = visible
				if visible then
					anyVisible = true
					lastVisible = entry
				end
			end
			if lastVisible then
				lastVisible.divider.Visible = false
			end
			group.header.Visible = anyVisible
			group.box.Visible = anyVisible
		end
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)

	local function paintToggle(trackFrame, knob, item, instant)
		local on = effective()[item.key] == true
		local color = on and C.accent or C.raised2
		local position = UDim2.new(0, on and 22 or 3, 0.5, 0)
		if instant then
			trackFrame.BackgroundColor3 = color
			knob.Position = position
		else
			tween(trackFrame, { BackgroundColor3 = color }, 0.14)
			tween(knob, { Position = position }, 0.14)
		end
		trackFrame.BackgroundTransparency = isLocked(item) and 0.6 or 0
	end

	local function buildControl(parent, item)
		local key = item.key
		if item.kind == "bool" then
			local trackFrame = make("TextButton", {
				AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(48, 28), BackgroundColor3 = C.raised2, BorderSizePixel = 0,
			}, parent)
			round(trackFrame, 14)
			local knob = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, trackFrame)
			round(knob, 11)
			trackFrame.Activated:Connect(function()
				if Control.Running or isLocked(item) then
					return
				end
				options[key] = not options[key]
				paintToggle(trackFrame, knob, item, false)
				changed()
			end)
			controls[key] = function(instant)
				paintToggle(trackFrame, knob, item, instant)
			end
		elseif item.kind == "number" then
			local box = make("TextBox", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(80, 36),
				BackgroundColor3 = C.raised, BorderSizePixel = 0, Font = MEDIUM, TextColor3 = C.text, TextSize = 14,
				ClearTextOnFocus = false, Text = tostring(options[key]),
			}, parent)
			round(box, 10)
			box.FocusLost:Connect(function()
				if Control.Running or isLocked(item) then
					box.Text = tostring(options[key])
					return
				end
				local value = tonumber(box.Text)
				if value then
					options[key] = math.clamp(math.floor(value), item.min or -math.huge, item.max or math.huge)
					changed()
				end
				box.Text = tostring(options[key])
			end)
			controls[key] = function()
				box.Text = tostring(options[key])
				box.TextTransparency = isLocked(item) and 0.5 or 0
			end
		elseif item.kind == "choice" then
			local api
			api = segmented(parent, item.choices, 38, C.accent, function(index)
				if Control.Running then
					return
				end
				options[key] = item.choices[index]
				api.set(index, false)
				changed()
			end)
			controls[key] = function(instant)
				api.set(table.find(item.choices, options[key]) or 1, instant)
			end
		elseif item.kind == "text" then
			local box = make("TextBox", {
				Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.raised, BorderSizePixel = 0, Font = FONT, TextColor3 = C.text,
				TextSize = 14, ClearTextOnFocus = false, Text = tostring(options[key] or ""), PlaceholderText = "Automatic",
				PlaceholderColor3 = C.faint, TextXAlignment = Enum.TextXAlignment.Left,
			}, parent)
			round(box, 10)
			pad(box, 12, 0, 12, 0)
			box.FocusLost:Connect(function()
				if Control.Running then
					box.Text = tostring(options[key] or "")
					return
				end
				options[key] = box.Text
				changed()
			end)
			controls[key] = function()
				box.Text = tostring(options[key] or "")
			end
		end
	end

	local function buildRow(parent, item)
		local stacked = item.kind == "choice" or item.kind == "text"
		local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, parent)
		local rowLayout = stack(row, 0)
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

		local inner = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, row)
		pad(inner, 16, 12, 16, 12)
		if stacked then
			stack(inner, 10)
		end
		local left = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(stacked and 1 or 0.64, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, inner)
		stack(left, 3)
		text(left, item.label, 14, C.text, MEDIUM)
		local description = item.desc
		if isLocked(item) then
			description ..= " Not available in this executor."
		end
		text(left, description, 12, C.sub)
		buildControl(inner, item)

		local divider = make("Frame", { Size = UDim2.new(1, -32, 0, 1), BackgroundColor3 = C.line, BorderSizePixel = 0 }, row)
		return row, divider
	end

	for _, group in SCHEMA do
		local headerLabel = text(settings, string.upper(group.group), 11, C.faint, BOLD, {
			Size = UDim2.new(1, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Bottom,
		})
		local box = make("Frame", { BackgroundColor3 = C.surface, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, settings)
		round(box, 14)
		stack(box, 0)
		local entry = { header = headerLabel, box = box, rows = {} }
		for index, item in group.items do
			local row, divider = buildRow(box, item)
			table.insert(entry.rows, { row = row, divider = divider, haystack = string.lower(item.label .. " " .. item.desc) })
			if index == #group.items then
				divider.Visible = false
			end
		end
		table.insert(groupEntries, entry)
	end

	function refreshControls(instant)
		for _, paint in controls do
			paint(instant)
		end
	end
	refreshControls(true)

	startButton.Activated:Connect(function()
		if Control.Running then
			return
		end
		local final = effective()
		if final.FilePath == nil or final.FilePath == "" then
			final.FilePath = nil
		end
		Storage.write("profile.json", options)

		state.scanToken += 1 -- cancel a scan that is still running
		state.scanning = false
		state.plan = state.scan and state.scan.done and Estimator.compute(state.scan, final) or nil
		state.result = nil
		setStatus("Starting…", "", C.text, nil)
		task.spawn(xsave_run, final)
		renderFooter()
	end)

	stopButton.Activated:Connect(function()
		if Control.Running and not Control.Stop and not Control.Kill then
			Control.Stop = true
		end
	end)

	killButton.Activated:Connect(function()
		if Control.Running and not Control.Kill then
			Control.Kill = true
		end
	end)

	local function applyMode()
		if state.rail then
			header.Size = UDim2.new(0, RAIL, 0, HEADER)
			tabsHolder.Position = UDim2.fromOffset(0, HEADER)
			tabsHolder.Size = UDim2.new(0, RAIL, 0, TABS)
			body.Position = UDim2.fromOffset(RAIL, 0)
			body.Size = UDim2.new(1, -RAIL, 1, 0)
			footer.AnchorPoint = Vector2.new(0, 0)
			footer.Position = UDim2.fromOffset(0, HEADER + TABS)
			footer.Size = UDim2.new(0, RAIL, 1, -(HEADER + TABS))
			ui.status.Size = UDim2.new(1, -32, 0, 62)
			ui.line2.Size = UDim2.new(1, 0, 0, 30)
			ui.line2.TextWrapped = true
			ui.line2.TextTruncate = Enum.TextTruncate.None
			stopButton.Size = UDim2.new(0.5, -4, 1, 0)
			killButton.Size = UDim2.new(0.5, -4, 1, 0)
			ui.title.Text = "xsave"
		else
			header.Size = UDim2.new(1, 0, 0, HEADER)
			tabsHolder.Position = UDim2.fromOffset(0, HEADER)
			tabsHolder.Size = UDim2.new(1, 0, 0, TABS)
			body.Position = UDim2.fromOffset(0, HEADER + TABS)
			body.Size = UDim2.new(1, 0, 1, -(HEADER + TABS + state.footerHeight))
			footer.AnchorPoint = Vector2.new(0, 1)
			footer.Position = UDim2.fromScale(0, 1)
			footer.Size = UDim2.new(1, 0, 0, state.footerHeight)
			ui.status.Size = UDim2.new(1, -32, 0, 44)
			ui.line2.Size = UDim2.new(1, 0, 0, 15)
			ui.line2.TextWrapped = false
			ui.line2.TextTruncate = Enum.TextTruncate.AtEnd
			stopButton.Size = UDim2.new(1, -108, 1, 0)
			killButton.Size = UDim2.fromOffset(100, 48)
			ui.title.Text = ui.titleFull
		end
		ui.railLine.Visible = state.rail
	end

	local function layout()
		local area = gui.AbsoluteSize
		if area.X < 100 or area.Y < 100 then
			area = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		end
		state.compact = area.X < 560
		state.rail = not state.compact and area.Y < 520
		if state.compact then
			window.AnchorPoint = Vector2.new(0.5, 1)
			window.Position = UDim2.new(0.5, 0, 1, -8)
			window.Size = UDim2.fromOffset(math.min(area.X - 16, 480), math.max(area.Y - 16, 320))
		else
			window.AnchorPoint = Vector2.new(0.5, 0.5)
			if not state.dragged then
				window.Position = UDim2.fromScale(0.5, 0.5)
			end
			if state.rail then
				window.Size = UDim2.fromOffset(math.min(area.X - 24, 720), math.max(area.Y - 16, 240))
			else
				window.Size = UDim2.fromOffset(420, math.clamp(area.Y - 32, 320, 620))
			end
		end
		applyMode()
	end
	layout()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	local function setMinimized(value)
		if state.minimized == value or not state.alive then
			return
		end
		state.minimized = value
		if value then
			tween(windowScale, { Scale = 0.94 }, 0.12)
			task.delay(0.12, function()
				if state.alive and state.minimized then
					window.Visible = false
					pill.Visible = true
					pillScale.Scale = 0.85
					tween(pillScale, { Scale = 1 }, 0.16)
				end
			end)
		else
			pill.Visible = false
			window.Visible = true
			windowScale.Scale = 0.94
			tween(windowScale, { Scale = 1 }, 0.18)
		end
	end
	minimizeButton.Activated:Connect(function()
		setMinimized(true)
	end)

	local function beginDrag(target, input, onTap)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state.drag = { target = target, start = input.Position, origin = target.Position, moved = false, onTap = onTap }
		end
	end
	header.InputBegan:Connect(function(input)
		beginDrag(window, input, nil)
	end)
	pill.InputBegan:Connect(function(input)
		beginDrag(pill, input, function()
			setMinimized(false)
		end)
	end)

	local moveConnection = UserInputService.InputChanged:Connect(function(input)
		local drag = state.drag
		if not drag then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - drag.start
			if not drag.moved and math.abs(delta.X) + math.abs(delta.Y) > 8 then
				drag.moved = true
			end
			if drag.moved and not (drag.target == window and state.compact) then
				drag.target.Position = UDim2.new(drag.origin.X.Scale, drag.origin.X.Offset + delta.X, drag.origin.Y.Scale, drag.origin.Y.Offset + delta.Y)
				if drag.target == window then
					state.dragged = true
				end
			end
		end
	end)
	local endConnection = UserInputService.InputEnded:Connect(function(input)
		local drag = state.drag
		if drag and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			state.drag = nil
			if not drag.moved and drag.onTap then
				drag.onTap()
			end
		end
	end)

	local function destroy()
		if not state.alive then
			return
		end
		state.alive = false
		state.scanToken += 1
		moveConnection:Disconnect()
		endConnection:Disconnect()
		Storage.write("profile.json", options)
		if GLOBAL_ENV.XSAVE_GUI == gui then
			GLOBAL_ENV.XSAVE_GUI = nil
		end
		gui:Destroy()
	end

	closeButton.Activated:Connect(function()
		if Control.Running and not state.closeArmed then
			-- Closing mid-run aborts it, so ask once instead of killing the save by accident
			state.closeArmed = true
			closeButton.Text = "?"
			closeButton.TextColor3 = C.bad
			ui.line2.Text = "Press again to abort the save and close."
			task.delay(3, function()
				if state.alive then
					state.closeArmed = false
					closeButton.Text = "×"
					closeButton.TextColor3 = C.sub
				end
			end)
			return
		end
		if Control.Running then
			Control.Kill = true
		end
		destroy()
	end)

	task.spawn(function()
		while state.alive do
			if Control.Running then
				state.wasRunning = true
				pillMark.BackgroundColor3 = C.accent
				local processed = Control.Processed
				local total = state.plan and state.plan.instances or 0
				local elapsed = os.clock() - (Control.StartedAt or os.clock())
				local statusText = Control.StatusText
				local live = statusText and statusText.Parent and statusText.Text or ""

				local phase = "Serializing"
				if string.find(live, "Decompiling", 1, true) then
					phase = live
				end
				if Control.Kill then
					phase = "Aborting…"
				elseif Control.Stop then
					phase = "Stopping…"
				end

				if total > 0 then
					local fraction = math.min(processed / total, 0.99)
					local eta = "estimating…"
					if processed >= math.max(50, total * 0.02) then
						eta = processed >= total and "finishing" or Format.time(elapsed * (total - processed) / processed)
					end
					setStatus(
						string.format("%s  ·  %d%%", phase, math.floor(fraction * 100)),
						string.format("%s of %s  ·  %s elapsed  ·  ETA %s", Format.int(processed), Format.int(total), Format.time(elapsed), eta),
						C.text,
						fraction
					)
					ui.pillText.Text = string.format("%d%%  ·  ETA %s", math.floor(fraction * 100), eta)
				else
					setStatus(phase, string.format("%s instances  ·  %s elapsed", Format.int(processed), Format.time(elapsed)), C.text, nil)
					ui.pillText.Text = string.format("%s  ·  %s", Format.int(processed), Format.time(elapsed))
				end
			elseif state.wasRunning then
				state.wasRunning = false
				local duration = (Control.FinishedAt or os.clock()) - (Control.StartedAt or os.clock())
				if Control.Succeeded then
					state.result = true
					setStatus(
						Control.Stop and "Saved (stopped early)" or "Saved",
						string.format("%s  ·  %s  ·  %s", Control.FileName or "output", Format.bytes(Control.Size or 0), Format.time(duration)),
						C.good, 1, C.good
					)
					ui.pillText.Text = "Saved"
					pillMark.BackgroundColor3 = C.good
				elseif Control.Kill then
					state.result = true
					setStatus("Aborted", "Nothing was written.", C.warn, 0, C.warn)
					ui.pillText.Text = "Aborted"
					pillMark.BackgroundColor3 = C.warn
				elseif Control.Succeeded == false then
					state.result = true
					setStatus("Failed", "See the F9 console for details.", C.bad, 1, C.bad)
					ui.pillText.Text = "Failed"
					pillMark.BackgroundColor3 = C.bad
				else
					state.result = true
					setStatus("Did not start", "Another save is running, or a required executor function is missing.", C.warn, 0, C.warn)
					ui.pillText.Text = "Did not start"
					pillMark.BackgroundColor3 = C.warn
				end
				refreshEstimate()
			end
			renderFooter()
			task.wait(0.2)
		end
	end)

	showTab(1)
	refreshPresetUI(true)
	refreshEstimate()
	renderFooter()
	windowScale.Scale = 0.96
	tween(windowScale, { Scale = 1 }, 0.2)
	task.delay(0.35, startScan)

	return {
		Destroy = destroy,
		Options = options,
		Rescan = startScan,
		Minimize = function()
			setMinimized(true)
		end,
		Restore = function()
			setMinimized(false)
		end,
	}
end

