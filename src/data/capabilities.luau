local BASE_CAPABILITIES
pcall(function()
	BASE_CAPABILITIES = SecurityCapabilities.new()
end)
local CAPABILITY_BITS = {
	Plugin = 2 ^ 0, ------------------- 0
	LocalUser = 2 ^ 1, ---------------- 1
	WritePlayer = 2 ^ 2, -------------- 2
	RobloxScript = 2 ^ 3, ------------- 3
	RobloxEngine = 2 ^ 4, ------------- 4
	NotAccessible = 2 ^ 5, ------------ 5
	----------------------------------- 6
	----------------------------------- 7
	RunClientScript = 2 ^ 8, ---------- 8
	RunServerScript = 2 ^ 9, ---------- 9
	Unknown = 2 ^ 10, ----------------- 10 (0xa)
	AccessOutsideWrite = 2 ^ 11, ------ 11 (0xb)
	----------------------------------- 12
	----------------------------------- 13
	----------------------------------- 14
	Unassigned = 2 ^ 15, -------------- 15 (0xf)
	LoadUnownedAsset = 2 ^ 16, -------- 16 (0x10)
	LoadString = 2 ^ 17, -------------- 17 (0x11)
	ScriptGlobals = 2 ^ 18, ----------- 18 (0x12)
	CreateInstances = 2 ^ 19, --------- 19 (0x13)
	Basic = 2 ^ 20, ------------------- 20 (0x14)
	Audio = 2 ^ 21, ------------------- 21 (0x15)
	DataStore = 2 ^ 22, --------------- 22 (0x16)
	Network = 2 ^ 23, ----------------- 23 (0x17)
	Physics = 2 ^ 24, ----------------- 24 (0x18)
	UI = 2 ^ 25, ---------------------- 25 (0x19)
	CSG = 2 ^ 26, --------------------- 26 (0x1a)
	Chat = 2 ^ 27, -------------------- 27 (0x1b)
	Animation = 2 ^ 28, --------------- 28 (0x1c)
	AvatarAppearance = 2 ^ 29, -------- 29 (0x1d)
	Input = 2 ^ 30, ------------------- 30 (0x1e)
	Environment = 2 ^ 31, ------------- 31 (0x1f)
	RemoteEvent = 2 ^ 32, ------------- 32 (0x20)
	LegacySound = 2 ^ 33, ------------- 33 (0x21)
	Players = 2 ^ 34, ----------------- 34 (0x22)
	CapabilityControl = 2 ^ 35, ------- 35 (0x23)
	AssetRead = 2 ^ 36, --------------- 36 (0x24)
	AssetManagement = 2 ^ 37, --------- 37 (0x25)
	DynamicGeneration = 2 ^ 38, ------- 38 (0x26)
	PlatformAvatarEditing = 2 ^ 39, --- 39 (0x27)
	AssetCreateUpdate = 2 ^ 40, ------- 40 (0x28)
	Capture = 2 ^ 41, ----------------- 41 (0x29)
	SensitiveInput = 2 ^ 42, ---------- 42 (0x2a)
	Monetization = 2 ^ 43, ------------ 43 (0x2b)
	LoadOwnedAsset = 2 ^ 44, ---------- 44 (0x2c)
	Social = 2 ^ 45, ------------------ 45 (0x2d)
	ServerCommunication = 2 ^ 46, ----- 46 (0x2e)
	Logging = 2 ^ 47, ----------------- 47 (0x2f)
	PromptExternalPurchase = 2 ^ 48, -- 48 (0x30)
	Groups = 2 ^ 49, ------------------ 49 (0x31)
	Teleport = 2 ^ 50, ---------------- 50 (0x32)
	Consequences = 2 ^ 51, ------------ 51 (0x33)
	Material = 2 ^ 52, ---------------- 52 (0x34)
	AvatarBehavior = 2 ^ 53, ---------- 53 (0x35)
	----------------------------------- 54
	----------------------------------- 55
	----------------------------------- 56
	----------------------------------- 57
	----------------------------------- 58
	RemoteCommand = 2 ^ 59, ----------- 59 (0x3b)
	InternalTest = 2 ^ 60, ------------ 60 (0x3c), Related to TestingGameScript
	PluginOrOpenCloud = 2 ^ 61, ------- 61 (0x3d)
	Assistant = 2 ^ 62, --------------- 62 (0x3e)
	Restricted = 2 ^ 63, ----------- 63 (0x3f) - special case for negative values (highest bit for i64)
}

local function __COUNT_CAPABILITY_BITS(raw)
	-- TODO tostring & string.split aren't ideal but this is the only way until the feature is out of the experimental phase (SecurityCapabilities.Contains exists but the Enums that it accepts lacks some hidden bits) - NotAccessible, Unknown, Restricted
	-- ! Seems like both tostring & .Contains ignore high / internal bits (anything above CapabilityControl): RemoteCommand, InternalTest, PluginOrOpenCloud, Assistant. They're present when created & saved by Studio but can't be read through current means

	local result = 0
	for _, flag in string.split(tostring(raw), " | ") do
		local bit = CAPABILITY_BITS[flag]
		if bit then
			result += bit
		end
	end
	return result
end

local function __COUNT_BITS(...) -- * Credits to Friend (you know yourself)
	local Value = 0

	for i, bit in { ... } do
		if bit then
			Value += 2 ^ (i - 1)
		end
	end

	return Value
end

