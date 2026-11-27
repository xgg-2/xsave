-- xsave diagnostics: read-only checks. Press Start, then Copy and send the report.

local XSAVE_URL = "https://raw.githubusercontent.com/xgg-2/xsave/main/saveinstance.luau"

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Stats = game:GetService("Stats")

local env = (getgenv and getgenv()) or _G

local function get(name)
	if env[name] ~= nil then
		return env[name]
	end
	local ok, value = pcall(function()
		return getfenv()[name]
	end)
	return ok and value or nil
end

local function has(name)
	return get(name) ~= nil
end

local plain, rich, failures = {}, {}, {}
local counts = { PASS = 0, WARN = 0, FAIL = 0 }
local COLORS = { PASS = "#52c484", WARN = "#ebac42", FAIL = "#e25858", INFO = "#a0a5b2", HEAD = "#6384ff" }
local ui = {}

local function escape(text)
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	return text
end

local function refresh()
	if ui.log then
		ui.log.Text = table.concat(rich, "\n")
		task.defer(function()
			if ui.scroll then
				ui.scroll.CanvasPosition = Vector2.new(0, 1e6)
			end
		end)
	end
end

local function add(kind, text)
	local line = kind == "HEAD" and ("\n== " .. text .. " ==") or ("[" .. kind .. "] " .. text)
	table.insert(plain, line)
	table.insert(rich, string.format('<font color="%s">%s</font>', COLORS[kind], escape(line)))
	if counts[kind] then
		counts[kind] += 1
	end
	if kind == "FAIL" then
		table.insert(failures, text)
	end
	refresh()
end

local function setStatus(text)
	if ui.status then
		ui.status.Text = text
	end
end

local function runTest(name, fn)
	add("HEAD", name)
	setStatus("Running: " .. name)
	local ok, err = pcall(fn)
	if not ok then
		add("FAIL", "test crashed: " .. tostring(err))
	end
	task.wait()
end

local function ms(seconds)
	return math.floor(seconds * 1000)
end

local function withTimeout(seconds, fn, ...)
	local args = table.pack(...)
	local done, ok, result = false, nil, nil
	task.spawn(function()
		ok, result = pcall(fn, table.unpack(args, 1, args.n))
		done = true
	end)
	local started = os.clock()
	while not done and os.clock() - started < seconds do
		task.wait()
	end
	return done, ok, result, os.clock() - started
end

local function testSystem()
	if has("identifyexecutor") then
		local ok, name, version = pcall(get("identifyexecutor"))
		add("INFO", "executor: " .. tostring(ok and name or "?") .. " " .. tostring(ok and version or ""))
	else
		add("WARN", "identifyexecutor is missing")
	end
	local okVersion, robloxVersion = pcall(version)
	add("INFO", "roblox client: " .. tostring(okVersion and robloxVersion or "?"))
	add("INFO", string.format("place %d, universe %d", game.PlaceId, game.GameId))

	local okPlatform, platform = pcall(function()
		return UserInputService:GetPlatform().Name
	end)
	add("INFO", "platform: " .. tostring(okPlatform and platform or "?"))
	add("INFO", string.format("touch=%s keyboard=%s gamepad=%s", tostring(UserInputService.TouchEnabled), tostring(UserInputService.KeyboardEnabled), tostring(UserInputService.GamepadEnabled)))

	local camera = workspace.CurrentCamera
	if camera then
		add("INFO", string.format("viewport: %dx%d (%s)", camera.ViewportSize.X, camera.ViewportSize.Y, camera.ViewportSize.X > camera.ViewportSize.Y and "landscape" or "portrait"))
	end
	local okInset, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if okInset then
		add("INFO", string.format("top inset: %d px", inset.Y))
	end
	local okMemory, memory = pcall(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	if okMemory then
		add("INFO", string.format("client memory: %d MB", math.floor(memory)))
	end

	local frames, started = 0, os.clock()
	local connection = RunService.Heartbeat:Connect(function()
		frames += 1
	end)
	task.wait(1)
	connection:Disconnect()
	local fps = math.floor(frames / math.max(os.clock() - started, 0.001))
	add(fps >= 20 and "PASS" or "WARN", "fps: " .. fps)
end

local function resolveRequest()
	local syn, http = get("syn"), get("http")
	return get("request")
		or get("http_request")
		or (type(syn) == "table" and syn.request)
		or (type(http) == "table" and http.request)
		or nil
end

local function testFunctions()
	local list = {
		{ "loadstring", true }, { "writefile", true }, { "readfile", true }, { "isfile", true },
		{ "decompile", false }, { "getscriptbytecode", false }, { "getnilinstances", false }, { "gethiddenproperty", false },
		{ "gethui", false }, { "protectgui", false }, { "setclipboard", false }, { "makefolder", false },
		{ "isfolder", false }, { "appendfile", false }, { "delfile", false }, { "listfiles", false },
	}
	for _, entry in ipairs(list) do
		if has(entry[1]) then
			add("PASS", entry[1])
		else
			add(entry[2] and "FAIL" or "WARN", entry[1] .. " is missing" .. (entry[2] and " (required)" or ""))
		end
	end
	add(resolveRequest() and "PASS" or "WARN", "http request function " .. (resolveRequest() and "found" or "missing"))

	local crypt = get("crypt")
	local encoder = get("base64encode")
		or get("base64_encode")
		or (type(crypt) == "table" and (crypt.base64encode or (type(crypt.base64) == "table" and crypt.base64.encode) or crypt.encode))
	if encoder then
		local ok, out = pcall(encoder, "hello")
		if ok and out == "aGVsbG8=" then
			add("PASS", "native base64 works")
		else
			add("WARN", "native base64 gave an unexpected result: " .. tostring(out))
		end
	else
		add("INFO", "no native base64 (xsave uses its built-in version)")
	end
end

local function testFiles()
	if not (has("writefile") and has("readfile")) then
		add("FAIL", "cannot test: writefile/readfile missing")
		return
	end
	local writefile, readfile = get("writefile"), get("readfile")
	local isfile, makefolder, isfolder, delfile = get("isfile"), get("makefolder"), get("isfolder"), get("delfile")

	if makefolder and isfolder and not isfolder("xsave_diag") then
		pcall(makefolder, "xsave_diag")
	end

	local payload = HttpService:JSONEncode({ ok = true, n = 123 })
	local okWrite, errWrite = pcall(writefile, "xsave_diag/roundtrip.json", payload)
	if not okWrite then
		add("FAIL", "writefile failed: " .. tostring(errWrite))
		return
	end
	local okRead, back = pcall(readfile, "xsave_diag/roundtrip.json")
	add(okRead and back == payload and "PASS" or "FAIL", "write/read round trip")
	if isfile then
		local okIs, exists = pcall(isfile, "xsave_diag/roundtrip.json")
		add(okIs and exists and "PASS" or "FAIL", "isfile sees the written file")
	end

	local big = string.rep(string.rep("x", 1024 * 1024), 8)
	local started = os.clock()
	local okBig, errBig = pcall(writefile, "xsave_diag/big.bin", big)
	local seconds = math.max(os.clock() - started, 0.001)
	if okBig then
		add("PASS", string.format("wrote 8 MB in %.2f s (%.1f MB/s)", seconds, 8 / seconds))
	else
		add("FAIL", "8 MB write failed: " .. tostring(errBig))
	end

	if delfile then
		pcall(delfile, "xsave_diag/big.bin")
		pcall(delfile, "xsave_diag/roundtrip.json")
	else
		add("WARN", "delfile missing: test files stay in workspace/xsave_diag")
	end
end

local function testNetwork()
	local started = os.clock()
	local ok, body = pcall(function()
		return game:HttpGet("https://clientsettingscdn.roblox.com/v2/client-version/WindowsPlayer")
	end)
	if not ok then
		add("FAIL", "HttpGet failed: " .. tostring(body))
		return
	end
	add("PASS", string.format("HttpGet works (%d ms)", ms(os.clock() - started)))

	local okJson, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	local hash = okJson and type(data) == "table" and data.clientVersionUpload
	if not hash then
		add("WARN", "could not read the latest version hash")
		return
	end
	add("INFO", "latest version: " .. tostring(hash))

	local request = resolveRequest()
	if not request then
		add("WARN", "no request function, API dump mirrors not checked")
		return
	end
	for _, base in ipairs({
		"https://setup.rbxcdn.com/",
		"https://setup-cfly.rbxcdn.com/",
		"https://setup-ak.rbxcdn.com/",
		"https://s3.amazonaws.com/setup.roblox.com/",
	}) do
		local t0 = os.clock()
		-- HEAD is not supported by every executor, so ask for just the first bytes instead
		local okRequest, response = pcall(request, { Url = base .. hash .. "-Full-API-Dump.json", Method = "GET", Headers = { Range = "bytes=0-1" } })
		if okRequest and type(response) == "table" and response.StatusCode then
			local code = response.StatusCode
			add((code == 200 or code == 206) and "PASS" or "WARN", string.format("%s -> %d (%d ms)", base, code, ms(os.clock() - t0)))
		else
			add("WARN", base .. " -> request failed: " .. tostring(response))
		end
	end
end

local function testScanSpeed()
	local worst, last = 0, os.clock()
	local connection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		worst = math.max(worst, now - last)
		last = now
	end)

	local started = os.clock()
	local list = workspace:GetDescendants()
	local scripts, visited = 0, 0
	for _, inst in ipairs(list) do
		local _ = inst.ClassName
		if inst:IsA("LuaSourceContainer") then
			scripts += 1
		end
		visited += 1
		if visited % 5000 == 0 then
			task.wait()
		end
	end
	connection:Disconnect()

	local seconds = math.max(os.clock() - started, 0.001)
	add("INFO", string.format("workspace: %d instances, %d scripts, %.2f s (%d instances/s)", visited, scripts, seconds, math.floor(visited / seconds)))
	add(worst < 0.25 and "PASS" or "WARN", string.format("longest frame stall while scanning: %d ms", ms(worst)))
end

local function findSampleScript()
	local roots = {}
	local player = Players.LocalPlayer
	local playerScripts = player and player:FindFirstChildOfClass("PlayerScripts")
	if playerScripts then
		table.insert(roots, playerScripts)
	end
	for _, name in ipairs({ "ReplicatedFirst", "ReplicatedStorage", "StarterPlayer", "StarterGui", "Workspace" }) do
		local service = game:FindService(name)
		if service then
			table.insert(roots, service)
		end
	end
	for _, root in ipairs(roots) do
		for _, inst in ipairs(root:GetDescendants()) do
			if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
				return inst
			end
		end
	end
end

local function testScripts()
	local sample = findSampleScript()
	if not sample then
		add("WARN", "no LocalScript or ModuleScript found to test with")
		return
	end
	add("INFO", "sample script class: " .. sample.ClassName)

	if has("decompile") then
		local done, ok, result, seconds = withTimeout(15, get("decompile"), sample)
		if not done then
			add("FAIL", "decompile did not finish within 15 s")
		elseif not ok then
			add("FAIL", "decompile error: " .. tostring(result))
		elseif type(result) ~= "string" or #result == 0 then
			add("WARN", "decompile returned an empty result")
		else
			add("PASS", string.format("decompile ok: %d chars in %d ms", #result, ms(seconds)))
		end
	else
		add("WARN", "decompile missing: scripts would be saved empty")
	end

	if has("getscriptbytecode") then
		local done, ok, result, seconds = withTimeout(10, get("getscriptbytecode"), sample)
		if done and ok and type(result) == "string" and #result > 0 then
			add("PASS", string.format("bytecode ok: %d bytes in %d ms", #result, ms(seconds)))
		else
			add("WARN", "getscriptbytecode unusable: " .. tostring(done and result or "timeout"))
		end
	end

	local okHash, hash = pcall(function()
		return sample:GetHash()
	end)
	add(okHash and "PASS" or "WARN", "script:GetHash " .. (okHash and "works" or "unavailable"))
end

local function testNilAndHidden()
	if has("getnilinstances") then
		local ok, list = pcall(get("getnilinstances"))
		if ok and type(list) == "table" then
			add("PASS", "nil instances: " .. #list)
		else
			add("WARN", "getnilinstances failed: " .. tostring(list))
		end
	else
		add("INFO", "getnilinstances missing, skipped")
	end

	local player = Players.LocalPlayer
	if has("gethiddenproperty") and player then
		local ok, value, isHidden = pcall(get("gethiddenproperty"), player, "SimulationRadius")
		if ok then
			add("PASS", string.format("gethiddenproperty ok (value=%s, hidden=%s)", tostring(value), tostring(isHidden)))
		else
			add("WARN", "gethiddenproperty failed: " .. tostring(value))
		end
	else
		add("INFO", "gethiddenproperty missing, skipped")
	end
end

local function testGuiFeatures()
	local checks = {
		{ "UIListLayout.Wraps", function() Instance.new("UIListLayout").Wraps = true end },
		{ "ScreenGui.ScreenInsets", function() Instance.new("ScreenGui").ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end },
		{ "ScreenGui.OnTopOfCoreBlur", function() Instance.new("ScreenGui").OnTopOfCoreBlur = true end },
		{ "ScrollingFrame.AutomaticCanvasSize", function() Instance.new("ScrollingFrame").AutomaticCanvasSize = Enum.AutomaticSize.Y end },
		{ "Frame.AutomaticSize", function() Instance.new("Frame").AutomaticSize = Enum.AutomaticSize.Y end },
		{ "TextLabel.RichText", function() Instance.new("TextLabel").RichText = true end },
		{ "UIStroke.ApplyStrokeMode", function() Instance.new("UIStroke").ApplyStrokeMode = Enum.ApplyStrokeMode.Border end },
		{ "UIScale", function() Instance.new("UIScale").Scale = 0.9 end },
	}
	for _, check in ipairs(checks) do
		local ok = pcall(check[2])
		add(ok and "PASS" or "WARN", check[1] .. (ok and "" or " is not supported"))
	end

	local targets = {}
	if has("gethui") then
		table.insert(targets, { "gethui()", function() return get("gethui")() end })
	end
	table.insert(targets, { "CoreGui", function() return game:GetService("CoreGui") end })
	if Players.LocalPlayer then
		table.insert(targets, { "PlayerGui", function() return Players.LocalPlayer:WaitForChild("PlayerGui", 3) end })
	end
	for _, target in ipairs(targets) do
		local ok, parent = pcall(target[2])
		local worked = false
		if ok and parent then
			local gui = Instance.new("ScreenGui")
			worked = pcall(function()
				gui.Parent = parent
			end) and gui.Parent == parent
			gui:Destroy()
		end
		add(worked and "PASS" or "WARN", "can parent a ScreenGui to " .. target[1])
	end
	add("INFO", "check the window header: do the symbols render? (x  -  .  ...)")
end

local function testXsave()
	local started = os.clock()
	local ok, source = pcall(function()
		return game:HttpGet(XSAVE_URL, true)
	end)
	if not ok or type(source) ~= "string" or #source < 1000 then
		add("FAIL", "could not download xsave: " .. string.sub(tostring(source), 1, 80))
		return
	end
	add("PASS", string.format("downloaded %d KB in %d ms", math.floor(#source / 1024), ms(os.clock() - started)))

	local chunk, compileError = loadstring(source, "xsave")
	if not chunk then
		add("FAIL", "compile error: " .. tostring(compileError))
		return
	end
	add("PASS", "compiled")

	local okRun, module = pcall(chunk)
	if not okRun then
		add("FAIL", "module failed to run: " .. tostring(module))
		return
	end
	add("PASS", "module loaded")
	for _, name in ipairs({ "Gui", "Run", "Stop", "Kill", "Reset" }) do
		add(type(module[name]) == "function" and "PASS" or "FAIL", "xsave." .. name)
	end
	add("INFO", "xsave version: " .. tostring(module.Version))
end

local function runAll()
	plain, rich, failures = {}, {}, {}
	counts.PASS, counts.WARN, counts.FAIL = 0, 0, 0
	refresh()
	add("INFO", "xsave diagnostics, " .. os.date("!%Y-%m-%d %H:%M:%S") .. " UTC")

	runTest("System", testSystem)
	runTest("Executor functions", testFunctions)
	runTest("File system", testFiles)
	runTest("Network", testNetwork)
	runTest("Scan speed", testScanSpeed)
	runTest("Scripts", testScripts)
	runTest("Nil instances and hidden properties", testNilAndHidden)
	runTest("GUI features", testGuiFeatures)
	runTest("xsave module", testXsave)

	add("HEAD", "Summary")
	add("INFO", string.format("%d passed, %d warnings, %d failed", counts.PASS, counts.WARN, counts.FAIL))
	for _, text in ipairs(failures) do
		add("INFO", "FAIL: " .. text)
	end
	if has("writefile") then
		local okSave = pcall(get("writefile"), "xsave_diag_report.txt", table.concat(plain, "\n"))
		if okSave then
			add("INFO", "report also saved to workspace/xsave_diag_report.txt")
		end
	end
	setStatus("Done. Press Copy and send the report.")
end

local function build()
	local existing = env.XSAVE_DIAG
	if existing then
		pcall(function()
			existing:Destroy()
		end)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "xsave_diag"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2e9
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	local parented = false
	if has("gethui") then
		parented = pcall(function()
			gui.Parent = get("gethui")()
		end)
	end
	if not parented then
		if has("protectgui") then
			pcall(get("protectgui"), gui)
		end
		parented = pcall(function()
			gui.Parent = game:GetService("CoreGui")
		end)
	end
	if not parented then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	env.XSAVE_DIAG = gui

	local area = gui.AbsoluteSize
	if area.X < 100 and workspace.CurrentCamera then
		area = workspace.CurrentCamera.ViewportSize
	end

	local BG, SURFACE, RAISED = Color3.fromRGB(15, 16, 20), Color3.fromRGB(23, 25, 31), Color3.fromRGB(38, 41, 52)
	local TEXT, SUB, ACCENT = Color3.fromRGB(237, 238, 243), Color3.fromRGB(160, 165, 178), Color3.fromRGB(99, 132, 255)

	local function make(className, props, parent)
		local inst = Instance.new(className)
		for key, value in pairs(props) do
			inst[key] = value
		end
		inst.Parent = parent
		return inst
	end
	local function round(parent, radius)
		make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
	end

	local window = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(math.min(area.X - 24, 440), math.min(area.Y - 24, 560)),
		BackgroundColor3 = BG, BorderSizePixel = 0,
	}, gui)
	round(window, 14)

	make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -64, 0, 44), Font = Enum.Font.GothamBold,
		Text = "xsave diagnostics   ×  –  ·  …", TextColor3 = TEXT, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
	}, window)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = SURFACE,
		BorderSizePixel = 0, Font = Enum.Font.GothamBold, Text = "×", TextColor3 = SUB, TextSize = 18, AutoButtonColor = false,
	}, window)
	round(close, 10)
	close.Activated:Connect(function()
		gui:Destroy()
	end)

	ui.status = make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -32, 0, 20), Font = Enum.Font.Gotham,
		Text = "Press Start to run the checks.", TextColor3 = SUB, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, window)

	local panel = make("Frame", {
		Position = UDim2.fromOffset(12, 70), Size = UDim2.new(1, -24, 1, -142), BackgroundColor3 = SURFACE, BorderSizePixel = 0,
	}, window)
	round(panel, 12)
	ui.scroll = make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
	}, panel)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, ui.scroll)
	ui.log = make("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Code,
		RichText = true, Text = "", TextColor3 = TEXT, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, ui.scroll)
	ui.fallback = make("TextBox", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.Code, MultiLine = true, ClearTextOnFocus = false,
		Text = "", TextColor3 = TEXT, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Visible = false,
	}, panel)

	local function button(text, color, xScale)
		local btn = make("TextButton", {
			Position = UDim2.new(xScale, xScale == 0 and 12 or 6, 1, -60), Size = UDim2.new(0.5, -18, 0, 48), BackgroundColor3 = color,
			BorderSizePixel = 0, Font = Enum.Font.GothamBold, Text = text, TextColor3 = Color3.new(1, 1, 1), TextSize = 15, AutoButtonColor = false,
		}, window)
		round(btn, 10)
		return btn
	end
	local startButton = button("Start", ACCENT, 0)
	local copyButton = button("Copy report", RAISED, 0.5)

	local running = false
	startButton.Activated:Connect(function()
		if running then
			return
		end
		running = true
		startButton.Text = "Running…"
		startButton.BackgroundTransparency = 0.6
		ui.fallback.Visible, ui.scroll.Visible = false, true
		task.spawn(function()
			local ok, err = pcall(runAll)
			if not ok then
				add("FAIL", "runner crashed: " .. tostring(err))
			end
			running = false
			startButton.Text = "Start again"
			startButton.BackgroundTransparency = 0
		end)
	end)

	copyButton.Activated:Connect(function()
		if #plain == 0 then
			setStatus("Nothing to copy yet. Press Start first.")
			return
		end
		local text = table.concat(plain, "\n")
		if has("setclipboard") then
			local ok = pcall(get("setclipboard"), text)
			setStatus(ok and string.format("Copied %d lines to the clipboard.", #plain) or "Copy failed, select the text manually.")
			if ok then
				return
			end
		end
		ui.fallback.Text = text
		ui.scroll.Visible, ui.fallback.Visible = false, true
		setStatus("No clipboard access: long-press the text, select all, copy.")
	end)
end

build()
