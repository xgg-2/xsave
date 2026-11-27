local SCHEMA = {
	{
		group = "Scripts",
		items = {
			{ key = "Decompile", label = "Decompile scripts", kind = "bool", default = EXECUTOR_NAME ~= "Velocity", needs = "decompile",
				desc = "Recover script sources with the executor's decompiler. Largest part of the total time." },
			{ key = "DecompileTimeout", label = "Decompile timeout (s)", kind = "number", default = 10, min = -1, max = 300,
				desc = "Seconds before a single script is skipped. -1 removes the limit." },
			{ key = "SaveBytecode", label = "Save bytecode", kind = "bool", default = false, needs = "getscriptbytecode",
				desc = "Store each script's compiled bytecode (Base64) as a comment." },
			{ key = "BytecodeTimeout", label = "Bytecode timeout (s)", kind = "number", default = 3, min = -1, max = 60, needs = "getscriptbytecode",
				desc = "Seconds to wait for a script's bytecode before skipping it." },
			{ key = "ScriptCache", label = "Script cache", kind = "bool", default = true, needs = "getscriptbytecode",
				desc = "Reuse decompiled output for identical bytecode, also across saves." },
			{ key = "DecompileJobless", label = "Cached scripts only", kind = "bool", default = false,
				desc = "Never decompile; use only what is already in the cache." },
		},
	},
	{
		group = "Scope",
		items = {
			{ key = "Mode", label = "Mode", kind = "choice", default = "optimized", choices = { "optimized", "full", "scripts" },
				desc = "optimized: the usual game services. full: every service. scripts: scripts only." },
			{ key = "NilInstances", label = "Nil instances", kind = "bool", default = false, needs = "getnilinstances",
				desc = "Also save instances that have no parent." },
			{ key = "SaveNotCreatable", label = "Not-creatable classes", kind = "bool", default = false,
				desc = "Save classes Studio cannot create, as placeholders." },
			{ key = "IgnoreNotArchivable", label = "Skip non-archivable", kind = "bool", default = true,
				desc = "Skip instances (and their children) that have Archivable turned off." },
			{ key = "SavePlayerCharacters", label = "Player characters", kind = "bool", default = false,
				desc = "Include the characters of players in the game." },
			{ key = "IsolateLocalPlayer", label = "Only local player", kind = "bool", default = false,
				desc = "Save the local player's data separately from other players." },
			{ key = "IsolatePlayers", label = "Players service", kind = "bool", default = false,
				desc = "Keep the Players service in the output." },
		},
	},
	{
		group = "Properties",
		items = {
			{ key = "IgnoreDefaultProperties", label = "Skip default values", kind = "bool", default = true,
				desc = "Do not write properties that equal the class default. Much smaller files." },
			{ key = "IgnoreSharedStrings", label = "Skip shared strings", kind = "bool", default = EXECUTOR_NAME ~= "Wave",
				desc = "Faster and smaller; disable only if a game needs shared string values." },
			{ key = "TreatUnionsAsParts", label = "Unions as parts", kind = "bool", default = EXECUTOR_NAME == "Solara",
				desc = "Save UnionOperations as plain parts (workaround for some executors)." },
		},
	},
	{
		group = "Session",
		items = {
			{ key = "SafeMode", label = "Safe mode", kind = "bool", default = true,
				desc = "Disconnects you from the server before saving. Recommended." },
			{ key = "KillAllScripts", label = "Stop game scripts", kind = "bool", default = true,
				desc = "Stops the game's scripts while saving so nothing changes mid-save." },
			{ key = "BoostFPS", label = "Disable 3D rendering", kind = "bool", default = false,
				desc = "Turns off rendering during the save to free up resources." },
			{ key = "AntiIdle", label = "Anti idle", kind = "bool", default = true,
				desc = "Prevents the idle kick during long saves." },
			{ key = "ShowStatus", label = "Status overlay", kind = "bool", default = true,
				desc = "Small status text in the corner of the screen. Needed for live details here." },
			{ key = "ShutdownWhenDone", label = "Close game when done", kind = "bool", default = false,
				desc = "Shuts the client down after a successful save." },
		},
	},
	{
		group = "Output",
		items = {
			{ key = "FilePath", label = "File name", kind = "text", default = "",
				desc = "Leave empty for an automatic name based on the place." },
			{ key = "AvoidFileOverwrite", label = "Keep existing files", kind = "bool", default = true,
				desc = "Add a number to the name instead of replacing an existing file." },
			{ key = "ReadMe", label = "Include README script", kind = "bool", default = true,
				desc = "Add a README script with restore tips to the saved place." },
			{ key = "CreditComment", label = "Credit comment", kind = "bool", default = true,
				desc = "Keeps the required credit comment at the top of the saved file." },
			{ key = "SaveCacheInterval", label = "Write interval (bytes)", kind = "number", default = 0x1600 * 10, min = 4096, max = 4194304,
				desc = "How much data is gathered before it is moved to the output buffer." },
		},
	},
}

local PRESETS = {
	{ name = "Fast", values = { Mode = "optimized", Decompile = false, SaveBytecode = false, NilInstances = false } },
	{ name = "Balanced", values = { Mode = "optimized", Decompile = EXECUTOR_NAME ~= "Velocity", SaveBytecode = false, NilInstances = false } },
	{ name = "Complete", values = { Mode = "full", Decompile = true, SaveBytecode = true, NilInstances = true, IgnoreDefaultProperties = true } },
}

local function schemaDefaults()
	local defaults = {}
	for _, group in SCHEMA do
		for _, item in group.items do
			defaults[item.key] = item.default
		end
	end
	return defaults
end

