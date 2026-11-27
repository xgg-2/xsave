--!native
--!optimize 2
--!divine-intellect
-- xsave by xgg-2 | based on UniversalSynSaveInstance https://discord.gg/wx4ThpAsmw

local function string_find(s, pattern, init)
	return string.find(s, pattern, init, true)
end

local function ArrayToDict(t, hydridMode, valueOverride, typeStrict)
	local tmp = {}

	if hydridMode then
		for any1, any2 in t do
			if type(any1) == "number" then
				tmp[any2] = valueOverride or true
			elseif type(any2) == "table" then
				tmp[any1] = ArrayToDict(any2, hydridMode) -- any1 is Class, any2 is Name
			else
				tmp[any1] = any2
			end
		end
	else
		for _, key in t do
			if not typeStrict or typeStrict and type(key) == typeStrict then
				tmp[key] = true
			end
		end
	end

	return tmp
end

local global_container = {}
do
	local env = (getgenv and getgenv()) or _G

	local function b64encode_fallback(data)
		local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
		local out, n = {}, 0
		for i = 1, #data, 3 do
			local a, b, c = string.byte(data, i, i + 2)
			local v = a * 65536 + (b or 0) * 256 + (c or 0)
			local c1, c2, c3, c4 = bit32.extract(v, 18, 6), bit32.extract(v, 12, 6), bit32.extract(v, 6, 6), bit32.extract(v, 0, 6)
			n += 1
			out[n] = string.sub(chars, c1 + 1, c1 + 1)
				.. string.sub(chars, c2 + 1, c2 + 1)
				.. (b and string.sub(chars, c3 + 1, c3 + 1) or "=")
				.. (c and string.sub(chars, c4 + 1, c4 + 1) or "=")
		end
		return table.concat(out)
	end

	local direct = {
		gethiddenproperty = { "gethiddenproperty", "get_hidden_property", "get_hidden_prop" },
		gethui = { "gethui", "get_hidden_gui", "gethiddenui" },
		getnilinstances = { "getnilinstances", "get_nil_instances" },
		getscriptbytecode = { "getscriptbytecode", "dumpstring", "get_script_bytecode" },
		protectgui = { "protectgui", "protect_gui" },
		base64encode = { "base64encode", "base64_encode" },
	}

	local matchers = {
		-- readbinarystring = 'string.find(...,"bin",nil,true)', -- ! Could match some unwanted stuff (getbinaryindex)
		-- request = 'string.find(...,"request",nil,true) and not string.find(...,"internal",nil,true)',
		base64encode = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"encode")and(c(b,"base64")or c(string.lower(tostring(a[2])),"base64"))',
		-- cloneref = 'string.find(...,"clone",nil,true) and string.find(...,"ref",nil,true)',
		-- decompile = '(string.find(...,"decomp",nil,true) and string.sub(...,#...) ~= "s")',
		gethiddenproperty = 'string.find(...,"get",nil,true) and string.find(...,"h",nil,true) and string.find(...,"prop",nil,true) and string.sub(...,#...) ~= "s"',
		gethui = 'string.find(...,"get",nil,true) and string.find(...,"h",nil,true) and string.find(...,"ui",nil,true)',
		-- getcon = 'string.find(...,"get",nil,true) and (string.find(...,"conn",nil,true) or string.find(...,"sig",nil,true)) and string.sub(...,#(...))=="s"',
		getnilinstances = 'string.find(...,"nil",nil,true) and string.find(...,"get",nil,true) and string.sub(...,#...) == "s"', -- ! Could match some unwanted stuff
		getscriptbytecode = 'string.find(...,"get",nil,true) and string.find(...,"script",nil,true) and string.find(...,"bytecode",nil,true)', --  or string.find(...,"dump",nil,true) and string.find(...,"string",nil,true) due to Fluxus (dumpstring returns a function)
		-- hash = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"hash")and c(string.lower(tostring(a[2])),"crypt")',
		protectgui = 'string.find(...,"protect",nil,true) and string.find(...,"ui",nil,true) and not string.find(...,"un",nil,true)',
		-- setthreadidentity = 'string.find(...,"identity",nil,true) and string.find(...,"set",nil,true)',
	}

	local function lookup(name)
		for _, alias in direct[name] or { name } do
			local f = env[alias]
			if type(f) == "function" then
				return f
			end
		end

		if name == "base64encode" then
			for _, tbl in { env.crypt, env.base64, env.syn and env.syn.crypt } do
				if type(tbl) == "table" then
					local f = tbl.base64encode or tbl.encode or (type(tbl.base64) == "table" and (tbl.base64.encode or tbl.base64.base64encode))
					if type(f) == "function" then
						return f
					end
				end
			end
		end

		local src = matchers[name]
		local ok, matcher = pcall(function()
			return src and loadstring(src)
		end)
		if ok and matcher then
			for key, value in next, env do
				if type(key) == "string" and type(value) == "function" then
					local good, res = pcall(matcher, string.lower(key), "")
					if good and res then
						return value
					end
				elseif type(key) == "string" and type(value) == "table" and name == "base64encode" then
					for key2, value2 in next, value do
						if type(key2) == "string" and type(value2) == "function" then
							local good, res = pcall(matcher, string.lower(key2), key)
							if good and res then
								return value2
							end
						end
					end
				end
			end
		end

		if name == "base64encode" then
			return b64encode_fallback
		end
		return nil
	end

	setmetatable(global_container, {
		__index = function(self, name)
			local f = lookup(name)
			rawset(self, name, f)
			return f
		end,
	})
end

local identify_executor = identifyexecutor or getexecutorname or whatexecutor

local EXECUTOR_NAME = identify_executor and identify_executor() or ""

-- local cloneref = global_container.cloneref
local gethiddenproperty = global_container.gethiddenproperty

-- These should be universal enough
local appendfile = appendfile
local isfile = isfile
local readfile = readfile
local writefile = writefile

local getscriptbytecode = global_container.getscriptbytecode -- * A lot of assumptions are made based on whether this function is defined or not. So in certain edge cases, like if the executor defines "decompile" or "getscripthash" function yet doesn't define this function there might be loss of functionality of the saveinstance. Although that would be very rare and weird
local base64encode = global_container.base64encode

local service = setmetatable({}, {
	__index = function(self, serviceName)
		local o, s = pcall(Instance.new, serviceName)
		local Service = o and s
			or game:GetService(serviceName)
			or settings():GetService(serviceName)
			or UserSettings():GetService(serviceName)

		-- if cloneref then
		-- 	Service = cloneref(Service)
		-- end
		if Service then
			self[serviceName] = Service
		end
		return Service
	end,
})

local SharedString_identifier = 1e15 -- 1 quadrillion, up to 9.(9) quadrillion, in theory this shouldn't ever run out and be enough for all sharedstrings ever imaginable 	-- TODO: worst case, add fallback to str randomizer once numbers run out : )
local SharedStrings = setmetatable({}, {
	__index = function(self, str)
		local identifier = base64encode(tostring(SharedString_identifier)) -- tostring is only needed for built-in base64encode, Luau base64 implementations don't need it as buffers autoconvert
		SharedString_identifier += 1

		self[str] = identifier -- ? The value of the md5 attribute is a Base64-encoded key. <SharedString> type elements use this key to refer to the value of the string. The value is the text content, which is Base64-encoded. Historically, the key was the MD5 hash of the string value. However, this is not required; the key can be any value that will uniquely identify the shared string. Roblox currently uses BLAKE2b truncated to 16 bytes..
		return identifier
	end,
})

local inherited_properties = {}
local default_instances = {}
local referents, ref_size = {}, 0 -- ? Roblox encodes all <Item> elements with a referent attribute. Each value is generated by starting with the prefix RBX, followed by a UUID version 4, with - characters removed, and all characters converted to uppercase.

local function GetRef(instance)
	local ref = referents[instance]
	if not ref then
		ref = ref_size
		referents[instance] = ref
		ref_size += 1
	end
	return ref
end

local function index(self, index_name)
	return self[index_name]
end

local FULL_VERSION

if not pcall(function()
	FULL_VERSION = version()
end) then
	if not pcall(function()
		FULL_VERSION = settings():GetService("DebugSettings").RobloxVersion
	end) then
		if not pcall(function()
			FULL_VERSION = service.RunService:GetRobloxVersion()
		end) then
			FULL_VERSION = "UNKNOWN"
		end
	end
end

local CLIENT_VERSION = tonumber(string.match(FULL_VERSION, "%d+%.(%d+)")) or 9e9
local __BREAK = "__BREAK" .. service.HttpService:GenerateGUID(false)

local CFrame_Rotation_IDs = {
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x02,
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x03,
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x05,
	["\0\0\128\63\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x06,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x07,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x09,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x0a,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x0c,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x0d,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x0e,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x10,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\128"] = 0x11,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x14,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\128"] = 0x15,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x17,
	["\0\0\128\191\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\191\0\0\0\128"] = 0x18,
	["\0\0\0\0\0\0\128\63\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x19,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x1b,
	["\0\0\0\0\0\0\128\191\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x1c,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x1e,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x1f,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x20,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x22,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\191\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\128"] = 0x23,
}
local rotationBuffer = buffer.create(36)

local attr_Type_IDs = {
	string = 0x02,
	boolean = 0x03,
	int32 = 0x04,
	-- float = 0x05, -- float32
	number = 0x06, -- float64 (double)
	-- Array = 0x07,
	-- Dictionary = 0x08,
	UDim = 0x09,
	UDim2 = 0x0A,
	Ray = 0x0B,
	Faces = 0x0C,
	Axes = 0x0D,
	BrickColor = 0x0E,
	Color3 = 0x0F,
	Vector2 = 0x10,
	Vector3 = 0x11,
	Vector2int16 = 0x12,
	Vector3int16 = 0x13,
	CFrame = 0x14,
	EnumItem = 0x15,
	-- 0x16
	NumberSequence = 0x17,
	NumberSequenceKeypoint = 0x18,
	ColorSequence = 0x19,
	ColorSequenceKeypoint = 0x1A,
	NumberRange = 0x1B,
	Rect = 0x1C,
	PhysicalProperties = 0x1D,
	-- 0x1E
	Region3 = 0x1F,
	Region3int16 = 0x20,
	Font = 0x21,
	SecurityCapabilities = 0x22,
	Path2DControlPoint = 0x23,
	TweenInfo = 0x24,
}

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

local Binary_Descriptors
Binary_Descriptors = {
	__PACK_MULTIPLE = function(descriptor, value1, value2, value3)
		local buf1, size1 = descriptor(value1)
		local buf2, size2 = descriptor(value2)

		local len = size1 + size2
		local buf3, size3

		if value3 ~= nil then
			buf3, size3 = descriptor(value3)
			len += size3
		end

		local b = buffer.create(len)

		buffer.copy(b, 0, buf1)
		buffer.copy(b, size1, buf2)

		if value3 ~= nil then
			buffer.copy(b, size1 + size2, buf3)
		end

		return b, len
	end,
	__construct_Sequence = function(keypoint_handler, keypointSize)
		return function(raw)
			local Keypoints = raw.Keypoints
			local Keypoints_n = #Keypoints

			local len = 4 + keypointSize * Keypoints_n
			local b = buffer.create(len)

			buffer.writeu32(b, 0, Keypoints_n)

			local offset = 4
			for _, keypoint in Keypoints do
				keypoint_handler(keypoint, b, offset)
				offset += keypointSize
			end

			return b, len
		end
	end,
	__writei64_le = function(b, offset, raw)
		local low = bit32.band(raw, 0xFFFFFFFF)
		local high = (raw - low) / 0x100000000

		buffer.writei32(b, offset, low)
		buffer.writei32(b, offset + 4, high)
	end,
	__PACK_F32 = nil,
	__PACK_I16 = nil,
	__construct__PACKER = function(float)
		local writeFunc = float and buffer.writef32 or buffer.writei16
		local elementSize = float and 4 or 2

		-- local zbuf, nozbuf = buffer.create(elementSize * 3), buffer.create(elementSize * 2)

		return function(X, Y, Z)
			local len = Z and (elementSize * 3) or (elementSize * 2)
			local b = buffer.create(len)

			writeFunc(b, 0, X)
			writeFunc(b, elementSize, Y)
			if Z then
				writeFunc(b, elementSize * 2, Z)
			end

			return b, len
		end
	end,
	--------------------------------------------------------------
	--------------------------------------------------------------
	--------------------------------------------------------------
	["string"] = function(raw)
		local raw_len = #raw
		local len = 4 + raw_len

		local b = buffer.create(len)

		buffer.writeu32(b, 0, raw_len)
		buffer.writestring(b, 4, raw)

		return b, len
	end,
	["boolean"] = function(raw)
		local b = buffer.create(1)

		buffer.writeu8(b, 0, raw and 1 or 0)

		return b, 1
	end,
	["number"] = function(raw) -- double
		local b = buffer.create(8)

		buffer.writef64(b, 0, raw)

		return b, 8
	end,
	["UDim"] = function(raw)
		local b = buffer.create(8)

		buffer.writef32(b, 0, raw.Scale)
		buffer.writei32(b, 4, raw.Offset)

		return b, 8
	end,
	["UDim2"] = function(raw)
		return Binary_Descriptors.__PACK_MULTIPLE(Binary_Descriptors["UDim"], raw.X, raw.Y)
	end,
	["Ray"] = function(raw)
		return Binary_Descriptors.__PACK_MULTIPLE(Binary_Descriptors["Vector3"], raw.Origin, raw.Direction)
	end,
	["Faces"] = function(raw)
		local b = buffer.create(4)

		buffer.writeu32(b, 0, __COUNT_BITS(raw.Right, raw.Top, raw.Back, raw.Left, raw.Bottom, raw.Front))

		return b, 4
	end,
	["Axes"] = function(raw)
		local b = buffer.create(4)

		buffer.writeu32(b, 0, __COUNT_BITS(raw.X, raw.Y, raw.Z))

		return b, 4
	end,
	["BrickColor"] = function(raw)
		local b = buffer.create(4)

		buffer.writeu32(b, 0, raw.Number)

		return b, 4
	end,
	["Color3"] = function(raw)
		return Binary_Descriptors.__PACK_F32(raw.R, raw.G, raw.B)
	end,
	["Vector2"] = function(raw)
		return Binary_Descriptors.__PACK_F32(raw.X, raw.Y)
	end,
	["Vector3"] = function(raw)
		return Binary_Descriptors.__PACK_F32(raw.X, raw.Y, raw.Z)
	end,
	["Vector2int16"] = function(raw)
		return Binary_Descriptors.__PACK_I16(raw.X, raw.Y)
	end,
	["Vector3int16"] = function(raw)
		return Binary_Descriptors.__PACK_I16(raw.X, raw.Y, raw.Z)
	end,
	["CFrame"] = function(raw)
		local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = raw:GetComponents()

		buffer.writef32(rotationBuffer, 0, R00)
		buffer.writef32(rotationBuffer, 4, R01)
		buffer.writef32(rotationBuffer, 8, R02)
		buffer.writef32(rotationBuffer, 12, R10)
		buffer.writef32(rotationBuffer, 16, R11)
		buffer.writef32(rotationBuffer, 20, R12)
		buffer.writef32(rotationBuffer, 24, R20)
		buffer.writef32(rotationBuffer, 28, R21)
		buffer.writef32(rotationBuffer, 32, R22)

		local rotation_ID = CFrame_Rotation_IDs[buffer.tostring(rotationBuffer)]

		local len = rotation_ID and 13 or 49
		local b = buffer.create(len)

		local __PACK_F32 = Binary_Descriptors.__PACK_F32
		local position = __PACK_F32(X, Y, Z)
		buffer.copy(b, 0, position)
		-- buffer.writef32(b, 0, X)
		-- buffer.writef32(b, 4, Y)
		-- buffer.writef32(b, 8, Z)

		if rotation_ID then
			buffer.writeu8(b, 12, rotation_ID)
		else
			buffer.writeu8(b, 12, 0x0)

			local xBasis = __PACK_F32(R00, R01, R02)
			buffer.copy(b, 13, xBasis)
			local yBasis = __PACK_F32(R10, R11, R12)
			buffer.copy(b, 13 + 12, yBasis)
			local zBasis = __PACK_F32(R20, R21, R22)
			buffer.copy(b, 13 + 24, zBasis)

			-- buffer.writef32(b, 13, R00)
			-- buffer.writef32(b, 17, R01)
			-- buffer.writef32(b, 21, R02)

			-- buffer.writef32(b, 25, R10)
			-- buffer.writef32(b, 29, R11)
			-- buffer.writef32(b, 33, R12)

			-- buffer.writef32(b, 37, R20)
			-- buffer.writef32(b, 41, R21)
			-- buffer.writef32(b, 45, R22)
		end

		return b, len
	end,
	["EnumItem"] = function(raw)
		local b_Name, Name_size = Binary_Descriptors["string"](tostring(raw.EnumType))

		local len = Name_size + 4
		local b = buffer.create(len)

		buffer.copy(b, 0, b_Name)
		buffer.writeu32(b, Name_size, raw.Value)

		return b, len
	end,
	["NumberSequence"] = nil,
	["NumberSequenceKeypoint"] = function(keypoint, b, offset)
		if not b then
			return Binary_Descriptors.__PACK_F32(keypoint.Envelope, keypoint.Time, keypoint.Value)
		end

		buffer.writef32(b, offset, keypoint.Envelope)
		offset += 4
		buffer.writef32(b, offset, keypoint.Time)
		offset += 4
		buffer.writef32(b, offset, keypoint.Value)
	end,
	["ColorSequence"] = nil,
	["ColorSequenceKeypoint"] = function(keypoint, b, offset)
		local Value = Binary_Descriptors["Color3"](keypoint.Value)

		if not b then
			b = buffer.create(20)
			offset = 0
		end

		buffer.writef32(b, offset, 0)
		offset += 4
		buffer.writef32(b, offset, keypoint.Time)
		offset += 4
		buffer.copy(b, offset, Value)

		return b, 20
	end,
	["NumberRange"] = function(raw)
		return Binary_Descriptors.__PACK_F32(raw.Min, raw.Max)
	end,
	["Rect"] = function(raw)
		return Binary_Descriptors.__PACK_MULTIPLE(Binary_Descriptors["Vector2"], raw.Min, raw.Max)
	end,
	["PhysicalProperties"] = function(raw) -- ? Not sure yet (https://github.com/RobloxAPI/spec/blob/master/properties/drafts/AttributesSerializeFull.md#physicalproperties)
		local len = 1
		if raw then
			len += 24
		end
		local b = buffer.create(len)

		buffer.writeu8(b, 0, raw and 3 or 0) -- 3 means it has set CustomPhysicalProperties & has set AcousticAbsorption, normally this would be __COUNT_BITS but AcousticAbsorption has been enabled by default

		if raw then
			buffer.writef32(b, 1, raw.Density)
			buffer.writef32(b, 5, raw.Friction)
			buffer.writef32(b, 9, raw.Elasticity)
			buffer.writef32(b, 13, raw.FrictionWeight)
			buffer.writef32(b, 17, raw.ElasticityWeight)
			buffer.writef32(b, 21, raw.AcousticAbsorption)
		end

		return b, len
	end,
	["Region3"] = function(raw)
		local Translation = raw.CFrame.Position
		local HalfSize = raw.Size * 0.5

		return Binary_Descriptors.__PACK_MULTIPLE(
			Binary_Descriptors["Vector3"],
			Translation - HalfSize, -- /App/util/Region3.cpp#L38
			Translation + HalfSize -- /App/util/Region3.cpp#L42
		)
	end,
	["Region3int16"] = function(raw)
		return Binary_Descriptors.__PACK_MULTIPLE(Binary_Descriptors["Vector3int16"], raw.Min, raw.Max)
	end,
	["Font"] = function(raw)
		local string__descriptor = Binary_Descriptors["string"]

		local b_Family, Family_size = string__descriptor(raw.Family)
		local b_CachedFaceId, CachedFaceId_size = string__descriptor("")

		local len = 3 + Family_size + CachedFaceId_size
		local b = buffer.create(len)

		local ok_w, weight = pcall(index, raw, "Weight")
		local ok_s, style = pcall(index, raw, "Style")

		buffer.writeu16(b, 0, ok_w and weight.Value or 0)
		buffer.writeu8(b, 2, ok_s and style.Value or 0)

		buffer.copy(b, 3, b_Family)
		buffer.copy(b, 3 + Family_size, b_CachedFaceId)

		return b, len
	end,
	["SecurityCapabilities"] = function(raw)
		local b = buffer.create(8)

		if raw == BASE_CAPABILITIES then
			return b, 8
		end

		Binary_Descriptors.__writei64_le(b, 0, __COUNT_CAPABILITY_BITS(raw))

		return b, 8
	end,
	["Path2DControlPoint"] = function(raw)
		return Binary_Descriptors.__PACK_MULTIPLE(
			Binary_Descriptors["UDim2"],
			raw.Position,
			raw.LeftTangent,
			raw.RightTangent
		)
	end,
	["TweenInfo"] = function(raw)
		local b = buffer.create(21)

		buffer.writef32(b, 0, raw.Time)
		buffer.writef32(b, 4, raw.DelayTime)
		buffer.writei32(b, 8, raw.RepeatCount)
		buffer.writeu32(b, 12, raw.EasingStyle.Value)
		buffer.writeu32(b, 16, raw.EasingDirection.Value)
		buffer.writeu8(b, 20, raw.Reverses and 1 or 0)

		return b, 21
	end,
}

do -- Sequences
	Binary_Descriptors["NumberSequence"] =
		Binary_Descriptors.__construct_Sequence(Binary_Descriptors["NumberSequenceKeypoint"], 12)

	Binary_Descriptors["ColorSequence"] =
		Binary_Descriptors.__construct_Sequence(Binary_Descriptors["ColorSequenceKeypoint"], 20)
end

do -- Vectors
	Binary_Descriptors.__PACK_F32 = Binary_Descriptors.__construct__PACKER(true)

	Binary_Descriptors.__PACK_I16 = Binary_Descriptors.__construct__PACKER()
end

local ESCAPES_PATTERN = "[&<>\"'\0\1-\9\11-\12\14-\31\127-\255]" -- * The safe way is to escape all five characters in text. However, the three characters " ' and > needn't be escaped in text
-- %z (\0 aka NULL) might not be needed as Roblox automatically converts it to space everywhere it seems like
-- Characters from: https://create.roblox.com/docs/en-us/ui/rich-text#escape-forms
-- * EscapesPattern should be ordered from most common to least common characters for sake of speed
-- * Might wanna use their numerical codes instead of named codes for reduced file size (Could be an Option)
-- TODO Maybe we should invert the pattern to only allow certain characters (future-proof)
local ESCAPES = {
	["&"] = "&amp;", -- 38
	["<"] = "&lt;", -- 60
	[">"] = "&gt;", -- 62
	['"'] = "&#34;", --  quot
	["'"] = "&#39;", -- apos
	["\0"] = "",
}

for rangeStart, rangeEnd in string.gmatch(ESCAPES_PATTERN, "(.)%-(.)") do
	for charCode = string.byte(rangeStart), string.byte(rangeEnd) do
		ESCAPES[string.char(charCode)] = "&#" .. charCode .. ";"
	end
end

local XML_Descriptors
XML_Descriptors = {
	__CDATA = function(raw) -- ? Normally Roblox doesn't use CDATA unless the string has newline characters (\n); We rather CDATA everything for sake of speed
		return "<![CDATA[" .. raw .. "]]>"
	end,
	__NORMALIZE_NUMBER = function(raw)
		if raw ~= raw then
			return "NAN"
		elseif raw == math.huge then
			return "INF"
		elseif raw == -math.huge then
			return "-INF"
		end

		return raw
	end,
	__NORMALIZE_RANGE = function(raw)
		return raw ~= raw and "0" or raw -- Normally we should return "-nan(ind)" instead of "0" but this adds more compatibility
	end,
	__MINMAX = function(min, max, descriptor)
		return "<min>" .. descriptor(min) .. "</min><max>" .. descriptor(max) .. "</max>"
	end,
	__PROTECTEDSTRING = function(raw) -- ? its purpose is to "protect" data from being treated as ordinary character data during processing;
		return string_find(raw, "]]>") and string.gsub(raw, ESCAPES_PATTERN, ESCAPES) or XML_Descriptors.__CDATA(raw)
	end,
	__construct_Sequence = function(keypoint_handler)
		-- The value is the text content, formatted as a space-separated list of floating point numbers.
		-- tostring(raw) also works (but way slower rn)
		-- ? Trailing whitespace after Envelope is needed for lune compatibility
		return function(raw)
			local sequence = ""

			for _, keypoint in raw.Keypoints do
				sequence ..= keypoint_handler(keypoint)
			end

			return sequence
		end
	end,
	__VECTOR = function(X, Y, Z) -- Each element is a <float>
		local Value = "<X>" .. X .. "</X><Y>" .. Y .. "</Y>" -- There is no Vector without at least two Coordinates.. (Vector1, at least on Roblox)

		if Z then
			Value ..= "<Z>" .. Z .. "</Z>"
		end

		return Value
	end,
	--------------------------------------------------------------
	--------------------------------------------------------------
	--------------------------------------------------------------
	-- AssetContentMap = function(raw) return "[]" end,  AssetContentMapSerializationEnabled	& VoxelGridNew5_PlaceFilter	FFlags; https://github.com/MarioMaster9/rbxl/blob/master/util/BinaryChunk.py#L298
	Axes = function(raw)
		-- The text of this element is formatted as an integer between 0 and 7

		return "<axes>" .. __COUNT_BITS(raw.X, raw.Y, raw.Z) .. "</axes>"
	end,

	-- ! Assuming all base64 encoded strings won't have newlines

	BinaryString = function(raw) -- ! only add raw == nil if such edge-case exists (note it)
		return raw == "" and "" or base64encode(raw)
	end,

	BrickColor = function(raw)
		return raw.Number -- * Roblox encodes the tags as "int", but this is not required for Roblox to properly decode the type. For better compatibility, it is preferred that third-party implementations encode and decode "BrickColor" tags instead. Could also use "int" or "Color3uint8"
	end,
	CFrame = function(raw)
		local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = raw:GetComponents()
		return XML_Descriptors.__VECTOR(X, Y, Z)
			.. "<R00>"
			.. R00
			.. "</R00><R01>"
			.. R01
			.. "</R01><R02>"
			.. R02
			.. "</R02><R10>"
			.. R10
			.. "</R10><R11>"
			.. R11
			.. "</R11><R12>"
			.. R12
			.. "</R12><R20>"
			.. R20
			.. "</R20><R21>"
			.. R21
			.. "</R21><R22>"
			.. R22
			.. "</R22>",
			"CoordinateFrame"
	end,
	-- CFrameQuat = function(raw) -- ? This will probably never release as it's not even used anywhere naturally, but there are hints it does exist as a DataType
	-- 	local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = raw:GetComponents()
	-- 	local trace = R00 + R11 + R22
	-- 	local S, QW, QX, QY, QZ

	-- 	if trace > 0 then
	-- 		S = math.sqrt(1 + trace) * 2
	-- 		QW = 0.25 * S
	-- 		QX = (R21 - R12) / S
	-- 		QY = (R02 - R20) / S
	-- 		QZ = (R10 - R01) / S
	-- 	elseif (R00 > R11) and (R00 > R22) then
	-- 		S = math.sqrt(1 + R00 - R11 - R22) * 2
	-- 		QW = (R21 - R12) / S
	-- 		QX = 0.25 * S
	-- 		QY = (R01 + R10) / S
	-- 		QZ = (R02 + R20) / S
	-- 	elseif R11 > R22 then
	-- 		S = math.sqrt(1 + R11 - R00 - R22) * 2
	-- 		QW = (R02 - R20) / S
	-- 		QX = (R01 + R10) / S
	-- 		QY = 0.25 * S
	-- 		QZ = (R12 + R21) / S
	-- 	else
	-- 		S = math.sqrt(1 + R22 - R00 - R11) * 2
	-- 		QW = (R10 - R01) / S
	-- 		QX = (R02 + R20) / S
	-- 		QY = (R12 + R21) / S
	-- 		QZ = 0.25 * S
	-- 	end

	-- 	return XML_Descriptors.__VECTOR(X, Y, Z)
	-- 		.. "<QX>"
	-- 		.. QX
	-- 		.. "</QX><QY>"
	-- 		.. QY
	-- 		.. "</QY><QZ>"
	-- 		.. QZ
	-- 		.. "</QZ><QW>"
	-- 		.. QW
	-- 		.. "</QW>"
	-- end,
	Color3 = function(raw) -- Each element is a <float>
		return "<R>" .. raw.R .. "</R><G>" .. raw.G .. "</G><B>" .. raw.B .. "</B>" -- ? It is recommended that Color3 is encoded with elements instead of text.
	end,
	Color3uint8 = function(raw)
		-- https://github.com/rojo-rbx/rbx-dom/blob/master/docs/xml.md#color3uint8
		-- ? It is recommended that Color3uint8 is encoded with text instead of elements.

		return 0xFF000000
			+ (math.floor(raw.R * 255) * 0x10000)
			+ (math.floor(raw.G * 255) * 0x100)
			+ math.floor(raw.B * 255)
		-- return bit32.bor(
		-- 	bit32.bor(bit32.bor(bit32.lshift(0xFF, 24), bit32.lshift(0xFF * raw.R, 16)), bit32.lshift(0xFF * raw.G, 8)),
		-- 	0xFF * raw.B
		-- )

		-- return tonumber(string.format("0xFF%02X%02X%02X",raw.R*255,raw.G*255,raw.B*255))
	end,
	ColorSequence = nil,
	ColorSequenceKeypoint = function(keypoint)
		local __NORMALIZE_RANGE = XML_Descriptors.__NORMALIZE_RANGE

		local color3 = keypoint.Value

		return __NORMALIZE_RANGE(keypoint.Time)
			.. " "
			.. __NORMALIZE_RANGE(color3.R)
			.. " "
			.. __NORMALIZE_RANGE(color3.G)
			.. " "
			.. __NORMALIZE_RANGE(color3.B)
			.. " 0 "
	end,
	Content = function(raw) -- TODO Not sure about Object & Opaque, run tests when possible
		-- * Currently the only way to tell which properties serialize (CanSave & CanLoad don't help here) is either API-2 dump or ReflectionService
		local SourceType = raw.SourceType
		return SourceType == Enum.ContentSourceType.None and "<null></null>"
			or SourceType == Enum.ContentSourceType.Uri and "<uri>" .. XML_Descriptors.string(raw.Uri) .. "</uri>"
			or SourceType == Enum.ContentSourceType.Object and "<Ref>" .. GetRef(raw.Object) .. "</Ref>"
			or SourceType == Enum.ContentSourceType.Opaque and "<Ref>" .. GetRef(raw.Opaque) .. "</Ref>"
	end,
	ContentId = function(raw) -- ! only add raw == nil if such edge-case exists (note it)
		return raw == "" and "<null></null>" or "<url>" .. XML_Descriptors.string(raw) .. "</url>", "Content" -- ~~TODO Remove "Content" str once Roblox fully releases Content DataType~~ Nvm, looks like both are using <Content> tag now (ex. EmissiveMaskContent & ColorMap)
	end,
	CoordinateFrame = function(raw)
		return "<CFrame>" .. XML_Descriptors.CFrame(raw) .. "</CFrame>"
	end,
	-- DateTime = function(raw) return raw.UnixTimestampMillis end, -- ? Not sure
	EnumItem = function(raw)
		return raw.Value, "token"
	end,
	Faces = function(raw)
		-- The text of this element is formatted as an integer between 0 and 63
		return "<faces>" .. __COUNT_BITS(raw.Right, raw.Top, raw.Back, raw.Left, raw.Bottom, raw.Front) .. "</faces>"
	end,
	Font = function(raw)
		-- TODO (OPTIONAL ELEMENT): Figure out how to determine (ContentId) <CachedFaceId><url>rbxasset://fonts/GothamSSm-Medium.otf</url></CachedFaceId>
		--[[
		? game:GetService("TextService"):GetFontMemoryData()
		? rbxasset://fonts/families/{Enum.Font.BuilderSans.Name}.json
		]]

		local ok_w, weight = pcall(index, raw, "Weight")
		local ok_s, style = pcall(index, raw, "Style")

		return "<Family>"
			.. XML_Descriptors.ContentId(raw.Family)
			.. "</Family><Weight>"
			.. (ok_w and XML_Descriptors.EnumItem(weight) or "")
			.. "</Weight><Style>"
			.. (ok_s and style.Name or "") -- Weird but this field accepts .Name of enum instead..
			.. "</Style>"
	end,
	NetAssetRef = nil,
	NumberRange = function(raw) -- tostring(raw) also works
		-- The value is the text content, formatted as a space-separated list of floating point numbers.
		local __NORMALIZE_RANGE = XML_Descriptors.__NORMALIZE_RANGE

		return __NORMALIZE_RANGE(raw.Min) .. " " .. __NORMALIZE_RANGE(raw.Max) --[[.. " "]] -- ! This might be required for compatibility; __NORMALIZE_RANGE is not needed here but it fixes the issue where "nan 10" value would reset to "0 0"
	end,
	NumberSequence = nil,
	NumberSequenceKeypoint = function(keypoint)
		local __NORMALIZE_RANGE = XML_Descriptors.__NORMALIZE_RANGE

		return __NORMALIZE_RANGE(keypoint.Time)
			.. " "
			.. __NORMALIZE_RANGE(keypoint.Value)
			.. " "
			.. __NORMALIZE_RANGE(keypoint.Envelope)
			.. " "
	end,
	-- Path2DControlPoint = function(raw)  -- ? Not sure
	-- 	local udim2 = XML_Descriptors.UDim2
	-- 	return "<Position>"
	-- 		.. udim2(raw.Position)
	-- 		.. "</Position>"
	-- 		.. "<LeftTangent>"
	-- 		.. udim2(raw.LeftTangent)
	-- 		.. "</LeftTangent>"
	-- 		.. "<RightTangent>"
	-- 		.. udim2(raw.RightTangent)
	-- 		.. "</RightTangent>"
	-- end,

	PhysicalProperties = function(raw)
		--[[
			Contains at least one CustomPhysics element, which is interpreted according to the bool type. If this value is true, then the tag also contains an element for each component of the PhysicalProperties:

			Density
			Friction
			Elasticity
			FrictionWeight
			ElasticityWeight
			AcousticAbsorption

			The value of each component is represented by the text content formatted as a 32-bit floating point number (see float)
		]]

		local CustomPhysics = "<CustomPhysics>" .. XML_Descriptors.bool(raw and true or false) .. "</CustomPhysics>"

		return raw
				and CustomPhysics .. "<Density>" .. raw.Density .. "</Density><Friction>" .. raw.Friction .. "</Friction><Elasticity>" .. raw.Elasticity .. "</Elasticity><FrictionWeight>" .. raw.FrictionWeight .. "</FrictionWeight><ElasticityWeight>" .. raw.ElasticityWeight .. "</ElasticityWeight><AcousticAbsorption>" .. raw.AcousticAbsorption .. "</AcousticAbsorption>"
			or CustomPhysics
	end,
	-- ProtectedString = function(raw) return tostring(raw), "ProtectedString" end,
	Ray = function(raw)
		local vector3 = XML_Descriptors.Vector3

		return "<origin>" .. vector3(raw.Origin) .. "</origin><direction>" .. vector3(raw.Direction) .. "</direction>"
	end,
	Rect = function(raw)
		return XML_Descriptors.__MINMAX(raw.Min, raw.Max, XML_Descriptors.Vector2), "Rect2D"
	end,
	Region3 = function(raw) -- ? Not sure about xml format yet, the math is correct though (/Network/Replicator.cpp#L1306)
		local Translation = raw.CFrame.Position
		local HalfSize = raw.Size * 0.5

		return XML_Descriptors.__MINMAX(
			Translation - HalfSize, -- /App/util/Region3.cpp#L38
			Translation + HalfSize, -- /App/util/Region3.cpp#L42
			XML_Descriptors.Vector3
		)
	end,
	Region3int16 = function(raw) -- ? Not sure yet (/App/v8tree/EnumProperty.cpp#L346)
		return XML_Descriptors.__MINMAX(raw.Min, raw.Max, XML_Descriptors.Vector3int16)
	end,

	-- ReplicationPV = function(raw) -- ? Not sure yet
	-- 	local vector3 = XML_Descriptors.Vector3

	-- 	return "<RotationalVelocity>"
	-- 		.. vector3(raw.RotationalVelocity)
	-- 		.. "</RotationalVelocity><LinearVelocity>"
	-- 		.. vector3(raw.LinearVelocity)
	-- 		.. "</LinearVelocity><Position>"
	-- 		.. XML_Descriptors.CFrame(raw.Position)
	-- 		.. "</Position>"
	-- end,

	SharedString = function(raw)
		return SharedStrings[XML_Descriptors.BinaryString(raw)]
	end,
	SecurityCapabilities = function(raw)
		if raw == BASE_CAPABILITIES then
			return 0
		end

		return __COUNT_CAPABILITY_BITS(raw)
	end,
	-- SystemAddress = function(raw) return raw end, -- PeerId? systemAddress as a string in the format "IP|Port", "|" being portDelineator, should not be '.', ':', '%', '-', '/', a number, or a-f  -- ? Not sure (binaryAddress)
	-- TweenInfo = function(raw) -- ? Not sure
	-- 	local __NORMALIZE_NUMBER = XML_Descriptors.__NORMALIZE_NUMBER
	-- 	local EnumItem = XML_Descriptors.EnumItem

	-- 	return "<Time>"
	-- 		.. __NORMALIZE_NUMBER(raw.Time)
	-- 		.. "</Time><DelayTime>"
	-- 		.. __NORMALIZE_NUMBER(raw.DelayTime)
	-- 		.. "</DelayTime><RepeatCount>"
	-- 		.. __NORMALIZE_NUMBER(raw.RepeatCount)
	-- 		.. "</RepeatCount><Reverses>"
	-- 		.. XML_Descriptors.bool(raw.Reverses)
	-- 		.. "</Reverses><EasingDirection>"
	-- 		.. enum(raw.EasingDirection)
	-- 		.. "</EasingDirection><EasingStyle>"
	-- 		.. enum(raw.EasingStyle)
	-- 		.. "</EasingStyle>"
	-- end,
	UDim = function(raw)
		--[[
			S: Represents the Scale component. Interpreted as a <float>.
			O: Represents the Offset component. Interpreted as an <int>.
		]]

		return "<S>" .. raw.Scale .. "</S><O>" .. raw.Offset .. "</O>"
	end,
	UDim2 = function(raw)
		--[[
			XS: Represents the X.Scale component. Interpreted as a <float>.
			XO: Represents the X.Offset component. Interpreted as an <int>.
			YS: Represents the Y.Scale component. Interpreted as a <float>.
			YO: Represents the Y.Offset component. Interpreted as an <int>.
		]]

		local X, Y = raw.X, raw.Y

		return "<XS>"
			.. X.Scale
			.. "</XS><XO>"
			.. X.Offset
			.. "</XO><YS>"
			.. Y.Scale
			.. "</YS><YO>"
			.. Y.Offset
			.. "</YO>"
	end,

	UniqueId = function(raw)
		-- 	--[[
		-- 		UniqueId properties might be random everytime Studio saves a place file
		-- 		and don't have a use right now outside of packages, which SSI doesn't
		-- 		account for anyway. They generate diff noise, so we shouldn't serialize
		-- 		them until we have to.
		-- 	]]
		-- 	-- https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/master/LuaPackages/Packages/_Index/ApolloClient/ApolloClient/utilities/common/makeUniqueId.lua#L68
		return string.gsub(raw, "-", "") -- seems to be string type by default
	end,

	-- User = function(raw)
	-- 	return raw:ToString() -- ? not sure yet
	-- end,

	Vector2 = function(raw)
		--[[
			X: Represents the X component. Interpreted as a <float>.
			Y: Represents the Y component. Interpreted as a <float>.
		]]
		return XML_Descriptors.__VECTOR(raw.X, raw.Y)
	end,
	Vector2int16 = nil,
	-- Vector2int16 = Descriptors.Vector2, -- except as <int>
	Vector3 = function(raw)
		--[[
			X: Represents the X component. Interpreted as a <float>.
			Y: Represents the Y component. Interpreted as a <float>.
			Z: Represents the Z component. Interpreted as a <float>.
		]]
		return XML_Descriptors.__VECTOR(raw.X, raw.Y, raw.Z)
	end,
	Vector3int16 = nil,
	-- Vector3int16 = Descriptors.Vector3, -- except as <int>\
	bool = function(raw)
		return raw and "true" or "false"
	end,
	double = nil, -- Float64
	float = nil, -- Float32
	int = nil, -- Int32
	int64 = nil, -- Int64 (long)
	string = function(raw)
		return (raw == nil or raw == "") and ""
			or string_find(raw, "]]>") and string.gsub(raw, ESCAPES_PATTERN, ESCAPES)
			or XML_Descriptors.__CDATA(string.gsub(raw, "\0", ""))
	end,

	--------------------------------------------------------------
	-----------%localappdata%/Roblox/GlobalSettings_13.xml--------
	-----------------------settings().Studio----------------------
	--------------------------------------------------------------
	-- QDir = function(raw) -- ? Not sure
	-- 	return raw
	-- end,
	-- QFont = function(raw) -- ? Not sure
	-- 	return raw
	-- end,
}

do -- Sequences
	XML_Descriptors.NumberSequence = XML_Descriptors.__construct_Sequence(XML_Descriptors.NumberSequenceKeypoint)

	XML_Descriptors.ColorSequence = XML_Descriptors.__construct_Sequence(XML_Descriptors.ColorSequenceKeypoint)
end

for descriptorName, redirectName in
	{
		NetAssetRef = "SharedString",
		Vector2int16 = "Vector2",
		Vector3int16 = "Vector3",
		double = "__NORMALIZE_NUMBER",
		float = "__NORMALIZE_NUMBER",
		int = "__NORMALIZE_NUMBER",
		int64 = "__NORMALIZE_NUMBER",
	}
do
	XML_Descriptors[descriptorName] = XML_Descriptors[redirectName]
end

local ClassList, FetchAPI

do
	local ClassPropertyExceptions = ArrayToDict({
		Whitelist = {
			MeshPart = { "CollisionFidelity" },
			PartOperation = { "CollisionFidelity" },
			TriangleMeshPart = { "CollisionFidelity" },
		},
		Blacklist = {
			LuaSourceContainer = { "ScriptGuid" },
			Instance = { "UniqueId", "HistoryId" },
		},
	}, true)

	local function AttributesSerialize(attrs, header_bytes)
		-- * There are certain restrictions for names of attributes
		-- https://create.roblox.com/docs/reference/engine/classes/Instance#SetAttribute
		-- But it seems like even if those are present, Studio still opens the file just fine
		-- So there is no need to check for them currently

		-- ? Return early for empty tags (this proved equally as fast when done using counter/next)

		local attrs_n = 0
		local buffer_size = 4
		local attrs_sorted = {}
		local attrs_formatted = table.clone(attrs)

		if header_bytes then
			buffer_size += #header_bytes
		end

		for attr, val in attrs do
			attrs_n += 1
			attrs_sorted[attrs_n] = attr

			local Type = typeof(val)

			local Descriptor = Binary_Descriptors[Type]
			local attr_size

			attrs_formatted[attr], attr_size = Descriptor(val)

			buffer_size += 5 + #attr + attr_size
		end

		table.sort(attrs_sorted)

		local b = buffer.create(buffer_size)

		local offset = 0

		if header_bytes then
			for _, header_byte in header_bytes do
				buffer.writeu8(b, offset, header_byte)
				offset += 1
			end
		end

		buffer.writeu32(b, offset, attrs_n)
		offset += 4

		local string__descriptor = Binary_Descriptors["string"]
		for _, attr in attrs_sorted do
			local b_Name, Name_size = string__descriptor(attr)

			buffer.copy(b, offset, b_Name)
			offset += Name_size

			buffer.writeu8(b, offset, attr_Type_IDs[typeof(attrs[attr])])
			offset += 1

			local bb = attrs_formatted[attr]

			buffer.copy(b, offset, bb)
			offset += buffer.len(bb)
		end

		return buffer.tostring(b)
	end

	local function AttenuationSerialize(attenuations)
		if not next(attenuations) then
			return "\0" -- ? [CONSTANT] Version byte (likely)
		end

		local attenuations_n = 0

		local attenuations_sorted = {}

		for key in attenuations do
			attenuations_n += 1
			attenuations_sorted[attenuations_n] = key
		end

		table.sort(attenuations_sorted) -- ? Seems to be sorted by default, just in case

		local b = buffer.create(1 + attenuations_n * 8)

		local offset = 1
		for _, key in attenuations_sorted do
			buffer.writef32(b, offset, key)
			offset += 4
			buffer.writef32(b, offset, attenuations[key]) -- volume
			offset += 4
		end

		return buffer.tostring(b)
	end

	local function TransformsSerialize(transforms)
		local transforms_n = #transforms

		if transforms_n == 0 then
			return "\1\0\0\0\0\0\0\0"
		end

		local b = buffer.create(8 + transforms_n * 48)

		buffer.writeu32(b, 0, 1) -- ? [CONSTANT] Version byte (likely)
		buffer.writeu32(b, 4, transforms_n)

		local __PACK_F32 = Binary_Descriptors.__PACK_F32

		local offset = 8
		for _, transform in transforms do
			local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = transform:GetComponents()

			local xBasis = __PACK_F32(R00, R01, R02)
			buffer.copy(b, offset, xBasis)
			offset += 12

			local yBasis = __PACK_F32(R10, R11, R12)
			buffer.copy(b, offset, yBasis)
			offset += 12

			local zBasis = __PACK_F32(R20, R21, R22)
			buffer.copy(b, offset, zBasis)
			offset += 12

			local position = __PACK_F32(X, Y, Z)
			buffer.copy(b, offset, position)
			offset += 12
		end

		return buffer.tostring(b)
	end

	local NotScriptableFixes = { --[[
		For more info:
		]]
		Instance = {
			AttributesSerialize = function(instance)
				local attrs = instance:GetAttributes()

				if not next(attrs) then
					return ""
				end

				return AttributesSerialize(attrs)
			end,
			DefinesCapabilities = "Sandboxed",
			Tags = function(instance)
				-- https://github.com/RobloxAPI/spec/blob/master/properties/Tags.md

				local tags = service.CollectionService:GetTags(instance) -- ? Seems faster than instance:GetTags

				if #tags == 0 then
					return ""
				end

				return table.concat(tags, "\0")
			end,
		},
		Path2D = {
			PropertiesSerialize = function(instance)
				local control_points = instance:GetControlPoints()
				local control_points_n = #control_points

				if control_points_n == 0 then
					return "\0\0\0\0"
				end

				local b = buffer.create(4 + control_points_n * 49)
				buffer.writeu32(b, 0, control_points_n)

				local TypeID_Path2DControlPoint = attr_Type_IDs["Path2DControlPoint"]
				local Path2DControlPoint_descriptor = Binary_Descriptors["Path2DControlPoint"]

				local offset = 4
				for i, point in control_points do
					local buf = Path2DControlPoint_descriptor(point)

					buffer.writeu8(b, offset, TypeID_Path2DControlPoint)
					offset += 1

					buffer.copy(b, offset, buf)
					offset += 48
				end

				return buffer.tostring(b)
			end,
		},
		PlayerEmulatorService = {
			SerializedEmulatedPolicyInfo = function(instance)
				local EmulatedPolicyInfo = instance:GetEmulatedPolicyInfo()

				if not next(EmulatedPolicyInfo) then
					return ""
				end

				return AttributesSerialize(EmulatedPolicyInfo)
			end,
		},
		StyleRule = {
			PropertiesSerialize = function(instance)
				local props = instance:GetProperties()

				if not next(props) then
					return "\0\0\0\0"
				end

				return AttributesSerialize(props)
			end,
			PropertyTransitionsSerialize = function(instance)
				local transitions = instance:GetPropertyTransitions()

				if not next(transitions) then
					return "\2\0\0\0\0\0"
				end

				return AttributesSerialize(transitions, { 0x02, 0x00 })
			end,
		},
		StyleQuery = {
			ConditionsSerialize = function(instance)
				local props = instance:GetConditions()

				if not next(props) then
					return "\0\0\0\0"
				end

				return AttributesSerialize(props)
			end,
		},
		MarkerCurve = {
			ValuesAndTimes = function(instance)
				local markers = instance:GetMarkers()
				local markers_n = #markers

				if markers_n == 0 then
					-- return "" -- Seems to also work
					return "\2\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0"
				end

				local strings_size = 0
				for i, marker in markers do
					strings_size += #marker.Value + 1
				end

				local b = buffer.create(8 + strings_size + 8 + (markers_n * 4))

				-- Values section
				buffer.writeu32(b, 0, 2) -- Constant
				buffer.writeu32(b, 4, markers_n)

				local offset = 8
				for i, marker in markers do
					local value = marker.Value
					buffer.writestring(b, offset, value)
					offset += #value + 1
					-- buffer.writeu8(b, offset, 0) -- Null terminator
					-- offset += 1
				end

				-- Times section (as 2400x scaled integers)
				buffer.writeu32(b, offset, 1) -- Constant
				offset += 4
				buffer.writeu32(b, offset, markers_n)
				offset += 4

				for i, marker in markers do
					local scaled_time = math.round(marker.Time * 2400)
					buffer.writeu32(b, offset, scaled_time)
					offset += 4
				end

				return buffer.tostring(b)
			end,
		},
		AnimationNodeDefinition = {
			InputPinData = function(instance)
				local input_pins = instance:GetInputPins()

				local input_pins_n = #input_pins

				if input_pins_n == 0 then
					return "\1\0\0\0\0\0\0\0"
				end

				local buffer_size = 8

				for _, pin in input_pins do
					buffer_size += 4 + #pin
				end

				local b = buffer.create(buffer_size)

				buffer.writeu32(b, 0, 1) -- ? [CONSTANT] Version byte (likely)
				buffer.writeu32(b, 4, input_pins_n)

				local string__descriptor = Binary_Descriptors["string"]
				local offset = 8
				for _, pin in input_pins do
					local b_pin, pin_size = string__descriptor(pin)

					buffer.copy(b, offset, b_pin)
					offset += pin_size
				end

				return buffer.tostring(b)
			end,
		},
		AnimationClip = {
			GuidBinaryString = function(instance) -- RobloxScriptSecurity
				local cleanGuid = string.gsub(instance.Guid, "[{}-]", "")
				local bytes = buffer.create(16)

				for i = 0, 15 do
					local hexByte = string.sub(cleanGuid, (i * 2) + 1, (i * 2) + 2)
					local val = tonumber(hexByte, 16) or 0
					buffer.writeu8(bytes, i, val)
				end

				return buffer.tostring(bytes)
			end,
		},
		AnimationRigData = {
			label = function(instance)
				local labels = instance:GetLabels() -- RobloxScriptSecurity
				local labels_n = #labels

				if labels_n == 0 then
					return "\1\0\0\0\0\0\0\0"
				end

				local b = buffer.create(8 + labels_n * 4)

				buffer.writeu32(b, 0, 1) -- ? [CONSTANT] Version byte (likely)
				buffer.writeu32(b, 4, labels_n)

				local offset = 8

				for _, label in labels do
					buffer.writeu32(b, offset, label)
					offset += 4
				end

				return buffer.tostring(b)
			end,
			name = function(instance)
				local names = instance:GetNames() -- RobloxScriptSecurity
				local names_n = #names

				if names_n == 0 then
					return "\1\0\0\0\0\0\0\0"
				end

				local buffer_size = 8

				for _, name in names do
					buffer_size += 4 + #name
				end

				local b = buffer.create(buffer_size)

				buffer.writeu32(b, 0, 1) -- ? [CONSTANT] Version byte (likely)
				buffer.writeu32(b, 4, names_n)

				local offset = 8

				for _, name in names do
					buffer.writeu32(b, offset, #name)
					offset += 4
				end
				for _, name in names do
					buffer.writestring(b, offset, name)
					offset += #name
				end

				return buffer.tostring(b)
			end,
			parent = function(instance)
				local parents = instance:GetParents() -- RobloxScriptSecurity
				local parents_n = #parents

				if parents_n == 0 then
					return "\1\0\0\0\0\0\0\0"
				end

				local b = buffer.create(8 + #parents * 2)

				buffer.writeu32(b, 0, 1) -- ? [CONSTANT] Version byte (likely)
				buffer.writeu32(b, 4, parents_n)

				local offset = 8

				for _, parent in parents do
					buffer.writeu16(b, offset, parent) -- ? likely u8 with \0 (Null) terminators but this is safer in case they overflow beyond 255 values
					offset += 2
				end

				return buffer.tostring(b)
			end,
			postTransform = function(instance)
				return TransformsSerialize(instance:GetPostTransforms()) -- RobloxScriptSecurity
			end,
			preTransform = function(instance)
				return TransformsSerialize(instance:GetPreTransforms()) -- RobloxScriptSecurity
			end,
			transform = function(instance)
				return TransformsSerialize(instance:GetTransforms()) -- RobloxScriptSecurity
			end,
		},
		AudioDeviceInput = {
			AccessList = function(instance) -- CanSave & CanLoad false
				local userid_accesslist = instance:GetUserIdAccessList()

				local uid_n = #userid_accesslist

				if uid_n == 0 then
					return ""
				end

				local b = buffer.create(uid_n * 8)

				local __writei64_le = Binary_Descriptors.__writei64_le

				local offset = 0
				for _, user_id in userid_accesslist do
					__writei64_le(b, offset, user_id)
					offset += 8
				end

				return buffer.tostring(b)
			end,
		},
		AudioEmitter = {
			AngleAttenuation = function(instance)
				return AttenuationSerialize(instance:GetAngleAttenuation())
			end,
			DistanceAttenuation = function(instance)
				return AttenuationSerialize(instance:GetDistanceAttenuation())
			end,
		},
		AudioListener = {
			AngleAttenuation = function(instance)
				return AttenuationSerialize(instance:GetAngleAttenuation())
			end,
			DistanceAttenuation = function(instance)
				return AttenuationSerialize(instance:GetDistanceAttenuation())
			end,
		},
		DebuggerBreakpoint = { line = "Line" }, -- ? This shouldn't appear in live games (try to prove this wrong)
		BallSocketConstraint = { MaxFrictionTorqueXml = "MaxFrictionTorque" },
		BasePart = {
			Color3uint8 = "Color",
			MaterialVariantSerialized = "MaterialVariant",
			size = "Size",
			siz = "Size",
		},
		DoubleConstrainedValue = { value = "Value" },
		IntConstrainedValue = { value = "Value" },

		CustomEvent = {
			PersistedCurrentValue = function(instance)
				local receiver = instance:GetAttachedReceivers()[1]
				if receiver then
					return receiver:GetCurrentValue()
				end

				local tempReceiver = Instance.new("CustomEventReceiver")
				local clone = Instance.fromExisting(instance)

				tempReceiver.Source = clone
				local value = tempReceiver:GetCurrentValue()

				tempReceiver:Destroy()
				clone:Destroy()

				return value
			end,
		},

		-- Lighting = {
		-- 	ExtendLightRangeTo120 = function() -- Seems default true now
		-- 		local light = Instance.new("PointLight")
		-- 		light.Range = 200
		-- 		return light.Range == 120 -- Ideally cache
		-- 	end,
		-- },

		Terrain = {
			AcquisitionMethod = "LastUsedModificationMethod", -- ? Not sure, RobloxScriptSecurity
			-- Material = function(instance) -- EnableMaterialSlotTable FFlag, uncomment once GetMaterialSlot is enabled
			-- 	local slots = {}
			-- 	for slotIndex = 2, 1e9 do
			-- 		local ok, baseMaterial, materialVariant, color =
			-- 			pcall(instance.GetMaterialSlot, instance, slotIndex)

			-- 		if ok then
			-- 			if baseMaterial then
			-- 				table.insert(
			-- 					slots,
			-- 					{
			-- 						slotIndex = slotIndex,
			-- 						baseMaterial = baseMaterial,
			-- 						materialVariant = materialVariant,
			-- 						color = color,
			-- 					}
			-- 				)
			-- 			end
			-- 		else
			-- 			break
			-- 		end
			-- 	end

			-- 	local size = 8 -- header

			-- 	for _, slot in slots do
			-- 		size += 15 + #slot.materialVariant
			-- 	end

			-- 	local b = buffer.create(size)
			-- 	local offset = 0

			-- 	-- header
			-- 	buffer.writeu32(b, offset, 1) -- version
			-- 	offset += 4

			-- 	buffer.writeu32(b, offset, #slots)
			-- 	offset += 4

			-- 	for _, slot in slots do
			-- 		buffer.writeu32(b, offset, slot.slotIndex)
			-- 		offset += 4

			-- 		buffer.writeu8(b, offset, (slot.color.R * 255))
			-- 		offset += 1
			-- 		buffer.writeu8(b, offset, (slot.color.G * 255))
			-- 		offset += 1
			-- 		buffer.writeu8(b, offset, (slot.color.B * 255))
			-- 		offset += 1

			-- 		buffer.writeu32(b, offset, slot.baseMaterial.Value)
			-- 		offset += 4

			-- 		buffer.writeu32(b, offset, #slot.materialVariant)
			-- 		offset += 4

			-- 		buffer.writestring(b, offset, slot.materialVariant)
			-- 		offset += #slot.materialVariant
			-- 	end

			-- 	return buffer.tostring(b)
			-- end,
			MaterialColors = function(instance) -- https://github.com/RobloxAPI/spec/blob/master/properties/MaterialColors.md
				-- TODO Use code below once GetFirstCustomMaterialSlotIndex & GetMaterialSlot are enabled
				--[[
				local colors = {}
				for slotIndex = 0, instance:GetFirstCustomMaterialSlotIndex() - 1 do -- ! GetFirstCustomMaterialSlotIndex was removed
					local o, baseMaterial, materialVariant, color = pcall(instance.GetMaterialSlot, instance, slotIndex)

					if o then
						if color then
							table.insert(colors, color)
						end
					else
						break
					end
				end
				local b = buffer.create(#colors * 3)
				local offset = 0
				for _, color in colors do
					buffer.writeu8(b, offset, (color.R * 255))
					offset += 1
					buffer.writeu8(b, offset, (color.G * 255))
					offset += 1
					buffer.writeu8(b, offset, (color.B * 255))
					offset += 1
				end
				]]

				local TERRAIN_MATERIAL_COLORS =
					{ --https://github.com/rojo-rbx/rbx-dom/blob/master/rbx_dom_lua/src/customProperties.lua#L5
						Enum.Material.Grass,
						Enum.Material.Slate,
						Enum.Material.Concrete,
						Enum.Material.Brick,
						Enum.Material.Sand,
						Enum.Material.WoodPlanks,
						Enum.Material.Rock,
						Enum.Material.Glacier,
						Enum.Material.Snow,
						Enum.Material.Sandstone,
						Enum.Material.Mud,
						Enum.Material.Basalt,
						Enum.Material.Ground,
						Enum.Material.CrackedLava,
						Enum.Material.Asphalt,
						Enum.Material.Cobblestone,
						Enum.Material.Ice,
						Enum.Material.LeafyGrass,
						Enum.Material.Salt,
						Enum.Material.Limestone,
						Enum.Material.Pavement,
					}

				local b = buffer.create(69) -- 69 bytes: 6 reserved + 63 for colors (21 materials * 3 components)
				local offset = 6 -- 6 reserved bytes

				for _, material in TERRAIN_MATERIAL_COLORS do
					local color = instance:GetMaterialColor(material)
					buffer.writeu8(b, offset, (color.R * 255))
					offset += 1
					buffer.writeu8(b, offset, (color.G * 255))
					offset += 1
					buffer.writeu8(b, offset, (color.B * 255))
					offset += 1
				end

				return buffer.tostring(b)
			end,
		},
		TriangleMeshPart = {
			FluidFidelityInternal = "FluidFidelity",
		},
		MeshPart = {
			InitialSize = "MeshSize",
			MeshID = "MeshId",
			VertexCount = function(instance) -- RobloxSecurity
				local meshId = instance.MeshId
				if meshId == "" then
					return __BREAK
				end
				return #service.UGCValidationService:GetMeshVerts(meshId)
			end,
		},
		PartOperation = { InitialSize = "MeshSize" },
		Part = { shape = "Shape", shap = "Shape" },
		TrussPart = { style = "Style" },
		FormFactorPart = {
			formFactorRaw = "FormFactor",
		},
		Fire = { heat_xml = "Heat", size_xml = "Size" },
		Humanoid = {
			Health_XML = "Health",
			InternalBodyScale = function(instance) -- RobloxScriptSecurity
				-- X - BodyWidthScale
				-- Y - BodyHeightScale
				-- Z - BodyDepthScale
				local a = instance.RootPart

				if not a then
					return __BREAK
				end

				return instance:GetAccessoryHandleScale(a, Enum.BodyPartR15.RootPart)
			end,
			InternalHeadScale = function(instance) -- RobloxScriptSecurity
				-- HeadScale
				local a = instance.Parent and instance.Parent:FindFirstChild("Head")

				if not a then
					return __BREAK
				end

				return instance:GetAccessoryHandleScale(a, Enum.BodyPartR15.Head).X -- X, Y, Z seem to be always equal
			end,
			NetworkHumanoidState = function(instance) -- CanSave & CanLoad false
				return instance:GetState()
			end,
		},
		HumanoidDescription = {
			AccessoryBlob = function(instance)
				local blob = {}

				for _, acc in instance:GetAccessories(false) do
					table.insert(blob, {
						AssetId = acc.AssetId,
						Order = acc.Order,
						AccessoryType = acc.AccessoryType.Name,
						Puffiness = acc.Puffiness,
					})
				end

				return service.HttpService:JSONEncode(blob)
			end,
			EmotesDataInternal = function(instance)
				local emotes_data = ""
				for name, ids in instance:GetEmotes() do
					emotes_data ..= name .. "^" .. table.concat(ids, "^") .. "^\\"
				end
				return emotes_data
			end,
			EquippedEmotesDataInternal = function(instance)
				local equipped_emotes_data = ""
				for _, emote in instance:GetEquippedEmotes() do
					equipped_emotes_data ..= emote.Slot .. "^" .. emote.Name .. "\\"
				end
				return equipped_emotes_data
			end,
		},
		LocalizationTable = {
			Contents = function(instance)
				return instance:GetContents() --service.HttpService:JSONEncode(instance:GetEntries())
			end,
		},
		MaterialService = { Use2022MaterialsXml = "Use2022Materials" }, -- RobloxScriptSecurity
		VideoPlayer = {
			PlayingReplicating = "IsPlaying", -- CanSave & CanLoad false
		},

		Model = {
			ModelMeshCFrame = function(instance)
				return instance:GetModelCFrame() -- GetBoundingBox
			end,
			ModelMeshSize = function(instance)
				return instance:GetExtentsSize() -- GetBoundingBox, GetModelSize
			end,
			Scale = function(instance) -- CanSave & CanLoad false
				return instance:GetScale()
			end,
			ScaleFactor = function(instance)
				return instance:GetScale()
			end,
			WorldPivotData = "WorldPivot", -- TODO This doesn't accurately represent whether optional type property is present or not (it's never nil), gethiddenproperty or gethiddenproperty_fallback is preferred
		},
		PackageLink = {
			PackageContentSerialize = "PackageContent",
			PackageIdSerialize = "PackageId",
			VersionIdSerialize = "VersionNumber",
		},
		Players = { MaxPlayersInternal = "MaxPlayers", PreferredPlayersInternal = "PreferredPlayers" }, -- ? Only needed for execs that lack LocalUserSecurity (Level 2, 5, 9), even so, it's a pretty useless information as it can be viewed elsewhere

		StarterPlayer = { AvatarJointUpgrade_SerializedRollout = "AvatarJointUpgrade" }, -- RobloxScriptSecurity
		Smoke = { size_xml = "Size", opacity_xml = "Opacity", riseVelocity_xml = "RiseVelocity" },
		Sound = {
			xmlRead_MinDistance_3 = "RollOffMinDistance", -- * Also MinDistance
			xmlRead_MaxDistance_3 = "RollOffMaxDistance", -- * Also MaxDistance
		},
		ViewportFrame = {
			CameraCFrame = function(instance)
				local CurrentCamera = instance.CurrentCamera

				return CurrentCamera and CurrentCamera.CFrame or CFrame.identity
			end,
			CameraFieldOfView = function(instance)
				local CurrentCamera = instance.CurrentCamera

				return math.rad(CurrentCamera and CurrentCamera.FieldOfView or 70)
			end,
		},
		WeldConstraint = {
			CFrame0 = function(instance)
				local Part0, Part1 = instance.Part0, instance.Part1

				return Part0 and Part1 and Part0.CFrame:ToObjectSpace(Part1.CFrame) or CFrame.identity
			end,
			CFrame1 = function(instance)
				local Part0, Part1 = instance.Part0, instance.Part1

				return Part0 and Part1 and Part1.CFrame:ToObjectSpace(Part0.CFrame) or CFrame.identity
			end,
			Part0Internal = "Part0",
			Part1Internal = "Part1",
			State = function(instance)
				return __COUNT_BITS(instance.Enabled, instance.Active)
			end,
		},
		Workspace = {
			-- SignalBehavior2 = "SignalBehavior", -- * Both are NotScriptable so it doesn't make sense to keep
			CollisionGroupData = function()
				local collision_groups = game:GetService("PhysicsService"):GetRegisteredCollisionGroups()

				local col_groups_n = #collision_groups

				if col_groups_n == 0 then
					return "\1\0"
				end

				local buffer_size = 2 -- Initial size

				for _, group in collision_groups do
					buffer_size += 7 + #group.name
				end

				local b = buffer.create(buffer_size)

				buffer.writeu8(b, 0, 1) -- ? [CONSTANT] Version byte (likely)
				buffer.writeu8(b, 1, col_groups_n) -- Group count

				local TypeID_int32 = attr_Type_IDs["int32"]
				local offset = 2
				for i, group in collision_groups do
					local name, id, mask = group.name, i - 1, group.mask
					local name_len = #name

					buffer.writeu8(b, offset, id) -- ID
					offset += 1

					buffer.writeu8(b, offset, TypeID_int32) -- ? Type ID for int32 (0x04)
					offset += 1

					buffer.writei32(b, offset, mask) -- Mask value as signed 32-bit integer
					offset += 4

					buffer.writeu8(b, offset, name_len) -- Name length
					offset += 1
					buffer.writestring(b, offset, name) -- Name
					offset += name_len
				end

				return buffer.tostring(b)
			end,
		},
	}
	for _, enum_item in Enum.Material:GetEnumItems() do
		NotScriptableFixes.MaterialService[enum_item.Name .. "Name"] = function(instance)
			return instance:GetBaseMaterialOverride(enum_item)
		end
	end

	FetchAPI = function()
		-- Credits @MaximumADHD

		local API_Dump

		local Max_SecurityCapabilities = SecurityCapabilities.new(unpack(Enum.SecurityCapability:GetEnumItems()))
		local filter = { Security = Max_SecurityCapabilities, ExcludeDisplay = true, ExcludeInherited = true }

		-- ! exact version match is preferred, mismatched dump versions might result in saveinstance trying to save properties that your client doesn't have yet
		local APIDUMP_FETCHERS = {
			[1] = function()
				local res = readfile(FULL_VERSION)
				if res and res ~= "" and service.HttpService:JSONDecode(res) then
					return res
				end
			end,
			[2] = function() -- version-history.json -> exact_match -> zbeta -> LIVE -> sibling major matches
				local client_version_str = tostring(CLIENT_VERSION)
				local dump
				local matching_versions, matched, is_matched, exact_match = {}, {}
				local function process_line(line, noinsert)
					local file_version, patch_commit, version_hash =
						string.match(line, '"%d+%.(%d+)%.([^"]+)": "(version%-[^"]+)')
					if file_version == client_version_str then
						is_matched = true
						if version_hash and not matched[version_hash] then -- ! this might cause issues if different file_versions point to the same version_hash (never happened)
							matched[version_hash] = true
							if not noinsert then -- to avoid fetching duplicates
								table.insert(matching_versions, version_hash) -- ? Retain the order (by latest)
							end
							if string.sub(FULL_VERSION, -#patch_commit) == patch_commit then
								return version_hash -- exact match
							end
						end
					elseif is_matched then
						return false -- stop iteration
					end
				end

				-- ! Assumes Normal dumps never include Default; Full dumps always do.
				local function isFullDump(classes)
					if not classes then
						return false
					end
					for _, class in classes do
						for _, member in class.Members do
							if member.MemberType == "Property" then
								return member.Default ~= nil
							end
						end
					end
					return false -- no properties found at all; treat as inconclusive/not full
				end

				local function tryFetchDump(url)
					local ok, decoded = pcall(function()
						local raw = game:HttpGet(url, true)
						return service.HttpService:JSONDecode(raw)
					end)
					return ok and decoded or nil
				end

				local function fetchFullApiDump(hash)
					-- Primary: Roblox CDN (only WindowsStudio64 hashes seem supported here)
					local decoded
					for _, base in {
						"https://setup.rbxcdn.com/",
						"https://setup-cfly.rbxcdn.com/",
						"https://setup-ak.rbxcdn.com/",
						"https://s3.amazonaws.com/setup.roblox.com/",
					} do
						decoded = tryFetchDump(base .. hash .. "-Full-API-Dump.json")
						if decoded and isFullDump(decoded.Classes) then
							break
						end
						decoded = nil
					end
					if decoded and isFullDump(decoded.Classes) then
						return service.HttpService:JSONEncode(decoded.Classes) -- minify it
					end

					-- Fallback: our own archived full dumps, in case Roblox's endpoint
					-- silently returned a normal dump instead of a full one (or 404'd).
					decoded = tryFetchDump(
						"https://raw.githubusercontent.com/setup-rbxcdn/roblox-full-api-dumps/refs/heads/main/full-dumps/"
							.. hash
							.. "-Full-API-Dump.json"
					)
					if decoded and isFullDump(decoded.Classes) then -- isFullDump check is useless here but why not
						return service.HttpService:JSONEncode(decoded.Classes)
					end

					return nil
				end

				do
					local o, r = pcall(
						game.HttpGet,
						game,
						"https://raw.githubusercontent.com/setup-rbxcdn/setup-rbxcdn.github.io/refs/heads/main/version-history/Windows/Studio64.json",
						true
					)
					if o then
						local version_history = string.split(r, "\n")
						version_history[#version_history] = nil -- the "}"
						-- 1. version-history pass (bottom-up)
						for i = #version_history, 2, -1 do -- 2 to avoid "{"
							local res = process_line(version_history[i])
							if res == false then
								break
							elseif res then
								exact_match = res
							end
						end
					end
				end
				do -- ? this might happen when user is on a new version but Roblox-Client-Tracker hasn't updated version-history.json yet
					local function fallback_channel(channel)
						local ok, res = pcall(function()
							return service.HttpService:JSONDecode(
								game:HttpGet(
									"https://clientsettingscdn.roblox.com/v2/client-version/WindowsStudio64"
										.. (channel and "/channel/" .. channel or ""),
									true
								)
							)
						end)
						if not ok then
							return
						end
						if res.version and res.clientVersionUpload then -- just in case
							local line = '"' .. res.version .. '": "' .. res.clientVersionUpload
							return process_line(line, true)
						end
					end
					if not exact_match then
						exact_match = fallback_channel("zbeta") or fallback_channel() -- LIVE
					end
				end
				if exact_match then
					dump = fetchFullApiDump(exact_match)
				end
				if not dump then
					for _, version_hash in matching_versions do -- TODO ideally match nearest by Commit segment of version(), new>old
						dump = fetchFullApiDump(version_hash)
						if dump then
							break
						end
					end
				end
				return dump
			end,
			[3] = function()
				-- ! Some executors (like Xeno) error on ReflectionService.GetClasses due to their ProxyService
				-- TODO At the time of writing this is missing a way to confirm NotCreatable & NotScriptable
				-- also is missing some classes like UserGameSettings, not that important though as none of them appear under DataModel
				local classes, classes_size = {}, 1

				for _, api_class in service.ReflectionService:GetClasses(filter) do
					local members, members_size = {}, 1
					local className = api_class.Name

					local class = {
						Name = className,
						Members = members,
						Superclass = api_class.Superclass or "<<<ROOT>>>",
					}
					local permits = api_class.Permits

					local tags = {}
					if api_class.Service then
						table.insert(tags, "Service")
					elseif permits and permits["GetService"] then
						table.insert(tags, "Service")
					elseif not permits or not permits["New"] then -- Some services can be Instance.new so it's better to include them
						table.insert(tags, "NotCreatable")
					end

					if #tags ~= 0 then
						class.Tags = tags
					end

					local o, r = pcall(
						service.ReflectionService.GetPropertiesOfClass,
						service.ReflectionService,
						className,
						filter
					) -- ? Might produce errors (ex. RolloutValidation) therefore pcall
					if o then
						for _, property in r do
							local propertyName = property.Name

							local valueType = property.Type
							local valueType_Name = valueType.EngineType

							local category = valueType.Category

							local member_tags = {}

							if not next(property.Permits) then
								table.insert(member_tags, "NotScriptable")
							end

							if valueType_Name == "Enum" then
								category, valueType_Name = "Enum", valueType.EnumType
							elseif valueType_Name == "RefType" then
								category, valueType_Name = "Class", valueType.InstanceType
							else
								local renames = {
									CoordinateFrame = "CFrame",
									Rect2D = "Rect",
									Vector3Int16 = "Vector3int16",
									Vector2Int16 = "Vector2int16",
									Region3Int16 = "Region3int16",
								}
								valueType_Name = renames[valueType_Name] or valueType_Name
							end

							-- property.Display.DeprecationMessage can be used to track Deprecated tag (not always though)

							local member = {
								Name = propertyName,
								MemberType = "Property",
								ValueType = { Name = valueType_Name, Category = category },
								Serialization = { CanLoad = property.Serialized, CanSave = property.Serialized },
								-- Default = Member.Default,
								-- Special = Special,
								-- Tags = MemberTags,
							}

							if #member_tags ~= 0 then
								member.Tags = member_tags
							end

							members[members_size] = member
							members_size += 1
						end
						-- else
						-- warn("Missing", className, r)
					end
					classes[classes_size] = class
					classes_size += 1
				end

				return service.HttpService:JSONEncode(classes)
			end,
			[4] = function()
				return service.HttpService:JSONEncode(
					service.HttpService:JSONDecode(
						game:HttpGet(
							"https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Mini-API-Dump.json",
							true
						)
					).Classes
				)
			end,
		}

		for i, fetcher in APIDUMP_FETCHERS do
			local o, r = pcall(fetcher)
			if o and r then
				API_Dump = r
				if i == 2 then -- relies on [2] being the same
					if writefile then
						writefile(FULL_VERSION, API_Dump)
					end
				end
				break
			elseif r ~= false and 2 < i then
				warn("[DEBUG] Failed to get", FULL_VERSION, "version API Dump, trying fallbacks..")
				warn("[DEBUG] Method number:", i, "Reason:", r)
			end
		end

		local classList = {}
		local tmp_classDict = {}

		local ClassesWhitelist, ClassesBlacklist = ClassPropertyExceptions.Whitelist, ClassPropertyExceptions.Blacklist

		local API_Dump_Decoded = service.HttpService:JSONDecode(API_Dump)

		-- First pass (prep)
		for _, API_Class in API_Dump_Decoded do
			local ClassName = API_Class.Name
			local props = {}

			for _, Member in API_Class.Members do
				local MemberType = Member.MemberType
				if MemberType == "Property" or MemberType == "Function" then
					props[Member.Name] = {
						ValueType = MemberType == "Property" and Member.ValueType.Name,
						MemberType = MemberType,
						-- Serialization = Member.Serialization,
					}
				end
			end

			tmp_classDict[ClassName] = props
		end

		-- Second pass (actual)
		for _, API_Class in API_Dump_Decoded do
			local ClassProperties, ClassProperties_size = {}, 1
			local Class = {
				Properties = ClassProperties,
				Superclass = API_Class.Superclass,
				-- Tags = {},
				NotCreatable = nil,
			}

			local ClassName = API_Class.Name
			local ClassTags = API_Class.Tags

			if ClassTags then
				local Tags = ArrayToDict(ClassTags, nil, nil, "string")
				-- Class.Tags = Tags -- or {}
				Class.NotCreatable = Tags.NotCreatable
				Class.Service = Tags.Service
			end

			local NotScriptableFixClass = NotScriptableFixes[ClassName]

			-- ? Check 96ea8b2a755e55a78aedb55a7de7e83980e11077 commit - If a NotScriptableFix is needed that relies on another NotScriptable Property (which doesn't really make sense in the first place)

			local ClassWhitelist, ClassBlacklist = ClassesWhitelist[ClassName], ClassesBlacklist[ClassName]

			local ContentProperties
			for _, Member in API_Class.Members do
				if Member.MemberType == "Property" then
					local Serialization = Member.Serialization

					if Serialization.CanLoad then -- If Roblox doesn't save it why should we; If Roblox doesn't load it we don't need to save it
						--[[
							-- ! CanSave replaces "Tags.Deprecated" check because there are some old properties which are deprecated yet have CanSave.
							Example: Humanoid.Health is CanSave false due to Humanoid.Health_XML being CanSave true (obsolete properties basically) - in this case both of them will Load. (aka PropertyPatches)
							CanSave being on same level as CanLoad also fixes potential issues with overlapping properties like Color, Color3 & Color3uint8 of BasePart, out of which only Color3uint8 should save
							This also fixes everything in IgnoreClassProperties automatically without need to hardcode :)
							A very simple fix for many problems that saveinstance scripts encounter!
						--]]
						local PropertyName = Member.Name

						local ValueType = Member.ValueType
						local ValueType_Name = ValueType.Name

						if ValueType_Name == "Content" or ValueType_Name == "AssetContentMap" then -- TODO Can Skip this if our dump was fetched from ReflectionService (make it explicit), currently ReflectionService dump isn't written to file
							-- ? This filters out Content DataType properties that Roblox doesn't serialize (even if they have CanSave/CanLoad true), takes less space, time & prevents potential property conflicts (Content vs ContentId)
							if not ContentProperties then
								ContentProperties = {}

								local o, properties = pcall(
									service.ReflectionService.GetPropertiesOfClass,
									service.ReflectionService,
									ClassName,
									filter
								) -- ? Might produce errors (ex. RolloutValidation) therefore pcall
								if o then
									for _, property in properties do -- * might as well check all properties, not just Content type
										ContentProperties[property.Name] = property.Serialized
									end
								end
							end
							if ContentProperties[PropertyName] ~= nil then
								Serialization.CanSave = ContentProperties[PropertyName]
							end
						end

						if
							(Serialization.CanSave or ClassWhitelist and ClassWhitelist[PropertyName])
							and not (ClassBlacklist and ClassBlacklist[PropertyName])
						then
							local MemberTags = Member.Tags

							local Special, PreferredDescriptorName

							if MemberTags then
								for _, tag in MemberTags do
									if type(tag) == "table" then
										PreferredDescriptorName = tag.PreferredDescriptorName
										if PreferredDescriptorName and Special then
											break
										end
									elseif tag == "NotScriptable" then
										Special = true
										if PreferredDescriptorName then
											break
										end
									end
								end
							end

							local preferredDescriptorProp
							if PreferredDescriptorName then
								preferredDescriptorProp = tmp_classDict[ClassName][PreferredDescriptorName]

								if -- Prevents type mismatch
									preferredDescriptorProp == nil
									or (
										preferredDescriptorProp.MemberType == "Property"
										and ValueType_Name ~= preferredDescriptorProp.ValueType
									)
								then -- For ex. (if they were notscriptable) CollisionGroupId (int) -> CollisionGroup (string)
									PreferredDescriptorName = nil
								end
							end

							-- if not Special then
							local Property = {
								Name = PropertyName,
								Category = ValueType.Category,
								-- Default = Member.Default,
								-- Tags = MemberTags,
								ValueType = ValueType_Name,

								Special = Special,

								CanRead = nil,
							}

							if string.sub(ValueType_Name, 1, 8) == "Optional" then
								-- Extract the string after "Optional"
								Property.Optional = string.sub(ValueType_Name, 9)
							end

							local NotScriptableFix = NotScriptableFixClass and NotScriptableFixClass[PropertyName]
							local accessFunc = PreferredDescriptorName
								and (
									preferredDescriptorProp.MemberType == "Property"
										and function(instance)
											return instance[PreferredDescriptorName]
										end
									or function(instance) -- Assume MemberType is "Function"
										return instance[PreferredDescriptorName](instance)
									end
								)

							Property.Fallback = NotScriptableFix
									and (type(NotScriptableFix) == "function" and NotScriptableFix or accessFunc and function(
										instance
									)
										local o, r = pcall(accessFunc, instance)
										if o then
											return r
										end
										return instance[NotScriptableFix]
									end or function(instance)
										return instance[NotScriptableFix]
									end)
								or accessFunc

							ClassProperties[ClassProperties_size] = Property
							ClassProperties_size += 1

							-- end
						end
					end
				end
			end

			classList[ClassName] = Class
		end

		return classList
	end
end

local GLOBAL_ENV = getgenv and getgenv() or _G or shared

local Control = {
	Running = false,
	Stop = false, -- finish early, keep what was collected so far (valid file)
	Kill = false, -- abort immediately, nothing is written
	Processed = 0,
	StatusText = nil,
	LockedPlace = nil,
	Size = 0,
	Decompiled = 0,
	DecompileTime = 0,
}

--[=[
    @class SynSaveInstance
    Represents the options for saving instances with custom settings using the synsaveinstance function.
]=]

--- @interface CustomOptions table
--- * Structure of the main CustomOptions table.
--- * Note: Options are case-insensitive, meaning you can type `NilInstances` option as `nilInStaNces` and it still will be valid.
--- @within SynSaveInstance
--- @field __DEBUG_MODE boolean -- This will print debug logs to console about unusual scenarios. Recommended to enable if you wish to help us improve our products and find bugs / issues with it! ___Default:___ false
--- @field ReadMe boolean --___Default:___ true
--- @field CreditComment boolean -- Adds the required original-author credit comment to saved files. ___Default:___ true
--- @field BytecodeTimeout number -- Seconds to wait for getscriptbytecode per script (negative = no timeout). ___Default:___ 3
--- @field SafeMode boolean -- Kicks you before Saving, which keeps you safe. **HIGHLY RECOMMENDED TO KEEP ENABLED**. ___Default:___ true
--- @field KillAllScripts boolean -- Kills all scripts to further protect you. SafeMode also enables this by default. **HIGHLY RECOMMENDED TO KEEP ENABLED**. ___Default:___ true
--- @field BoostFPS boolean -- Massively boosts FPS by disabling 3D rendering. Other options also enable it, like: SafeMode. ___Default:___ false
--- @field ShutdownWhenDone boolean -- Shuts the game down after saveinstance is finished. ___Default:___ false
--- @field AntiIdle boolean -- Prevents the 20-minute-Idle Kick. ___Default:___ true
--- .Anonymous {boolean|table{UserId = string, Name = string}} -- * **RISKY:** Cleans the file of any info related to your account like: Name, UserId. This is useful for some games that might store that info in GUIs or other Instances. Might potentially mess up parts of strings that contain characters that match your Name or parts of numbers that match your UserId. Can also be a table with UserId & Name keys. ___Default:___ false
--- @field ShowStatus boolean -- ___Default:___ true
--- @field Callback function -- If set, the serialized data will be sent to the callback function instead of to file. ___Default:___ false
--- @field mode string -- Valid modes: full, optimized, scripts. Change this to invalid mode like "invalid" if you only want ExtraInstances. "optimized" mode is **NOT** supported with *@Object* option. ___Default:___ `"optimized"`
--- @field Decompile boolean -- Script decompiling. ___Default:___ true
--- @field scriptcache boolean -- Use decompiled script cache to avoid decompiling duplicate scripts. ___Default:___ true
--- @field DecompileTimeout number -- If the decompilation run time exceeds this value it gets cancelled. Set to -1 to disable timeout (unreliable). ___Default:___ 10
--- @field DecompileJobless boolean -- Includes already decompiled code in the output. No new scripts are decompiled. ___Default:___ false
--- @field SaveBytecode boolean -- Includes bytecode in the output. Useful if you wish to be able to decompile it yourself later. ___Default:___ false
--- .DecompileIgnore {Instance | Instance.ClassName | [Instance.ClassName] = {Instance.Name}} -- * Ignores match & it's descendants by default. To Ignore only the instance itself set the value to `= false`. Examples: "Chat", - Matches any instance with "Chat" ClassName, Players = {"MyPlayerName"} - Matches "Players" Class AND "MyPlayerName" Name ONLY, `workspace` - matches Instance by reference, `[workspace] = false` - matches Instance by reference and only ignores the instance itself and not it's descendants. ___Default:___ {TextChatService}
--- .IgnoreList {Instance | Instance.ClassName | [Instance.ClassName] = {Instance.Name}} -- Structure is similar to **@DecompileIgnore** except `= false` meaning if you ignore one instance it will automatically ignore it's descendants. ___Default:___ {CoreGui, CorePackages}
--- .ExtraInstances {Instance} -- If used with any invalid mode (like "invalidmode") it will only save these instances. ___Default:___ {}
--- @field IgnoreProperties table -- Ignores properties by Name. ___Default:___ {}
--- @field SaveCacheInterval number -- The less the value the more often it saves, but that would mean less performance due to constantly saving. ___Default:___ 0x1600 * 10
--- @field FilePath string -- Must only contain the name (can include path) of the file, no file extension. ___Default:___ false
--- @field AvoidFileOverwrite boolean -- Prevents writing to place file that already exists. ___Default:___ true
--- @field Object Instance -- * If provided, saves as .rbxmx (Model file) instead. If Object is game, it will be saved as a .rbxl file. **MUST BE AN INSTANCE REFERENCE, FOR EXAMPLE - *game.Workspace***. `"optimized"` mode is **NOT** supported with this option. If IsModel is set to false then Object specified here will be saved as a place file. ___Default:___ false
--- @field IsModel boolean -- If Object is specified then sets to true automatically, unless you set it to false. ___Default:___ false
--- @field NilInstances boolean -- Save instances that aren't Parented (Parented to nil). ___Default:___ false
--- .NilInstancesFixes {[Instance.ClassName] = function} -- * This can cause some Classes to be fixed even though they might not need the fix (better be safe than sorry though). For example, Bones inherit from Attachment if we dont define them in the NilInstancesFixes then this will catch them anyways. **TO AVOID THIS BEHAVIOR USE THIS EXAMPLE:** {ClassName_That_Doesnt_Need_Fix = false}. ___Default:___ {Animator = function, AdPortal = function, BaseWrap = function, Attachment = function}
--- @field IgnoreDefaultProperties boolean -- Ignores default properties during saving.  ___Default:___ true
--- @field IgnoreNotArchivable boolean -- Ignores the Archivable property and saves Non-Archivable instances. ___Default:___ true
--- @field IgnorePropertiesOfNotScriptsOnScriptsMode boolean -- Ignores property of every instance that is not a script in "scripts" mode. ___Default:___ false
--- @field IgnoreSpecialProperties boolean -- Prevents calls to `gethiddenproperty` and uses fallback methods instead. This also helps with crashes. If your file is corrupted after saving, you can try turning this on. ___Default:___ false
--- @field IsolateStarterPlayer boolean -- Saves StarterPlayer as separate folder, children of the original instance will be ignored. ___Default:___ false
--- @field IsolatePlayers boolean -- Saves All Players as separate folder, children of the original instance will be ignored. ___Default:___ false
--- @field IsolateLocalPlayer boolean -- Saves LocalPlayer as separate folder, original instance will be ignored. ___Default:___ false
--- @field IsolateLocalPlayerCharacter boolean -- Saves LocalPlayer.Character as separate folder, original instance will be ignored. ___Default:___ false
--- @field SavePlayerCharacters boolean -- Ignore player characters while saving. ___Default:___ false
--- @field SaveNotCreatable boolean -- * Includes non-serializable instances as Folder objects (Name is misleading as this is mostly a fix for certain NilInstances and isn't always related to NotCreatable). Other options also enable it, like: IsolatePlayers, IsolateLocalPlayer, etc. ___Default:___ false
--- .NotCreatableFixes table<Instance.ClassName> -- * {"Player"} is the same as {Player = "Folder"}; Format like {SpawnLocation = "Part"} is only to be used when SpawnLocation inherits from "Part" AND "Part" is Creatable. ___Default:___ { "", "Player", "PlayerScripts", "PlayerGui", "TouchTransmitter" }
--- @field AlternativeWritefile boolean -- * Splits file content string into segments and writes them using appendfile. This might help with crashes when it starts writing to file. Though there is a risk of appendfile working incorrectly on some executors. ___Default:___ true
--- @field IgnoreDefaultPlayerScripts boolean -- * **RISKY: Ignores Default PlayerScripts like PlayerModule & RbxCharacterSounds. Prevents crashes on certain Executors. ___Default:___ true
--- @field IgnoreSharedStrings boolean -- * **RISKY: FIXES CRASHES (TEMPORARY, TESTED ON ROEXEC ONLY). FEEL FREE TO DISABLE THIS TO SEE IF IT WORKS FOR YOU**. ___Default:___ true
--- @field SharedStringOverwrite boolean -- * **RISKY:** if the process is not finished aka crashed then none of the affected values will be available. SharedStrings can also be used for ValueTypes that aren't `SharedString`, this behavior is not documented anywhere but makes sense (Could create issues though, due to _potential_ ValueType mix-up, only works on certain types which are all base64 encoded so far). Reason: Allows for potential smaller file size (can also be bigger in some cases). ___Default:___ false
--- @field TreatUnionsAsParts boolean -- * **RISKY:** Converts all UnionOperations to Parts. Useful if your Executor isn't able to save (read) Unions, because otherwise they will be invisible. ___Default:___ false (except Solara)

--- @interface OptionsAliases
--- @within SynSaveInstance
--- Alias → Canonical option mapping for the [SynSaveInstance.CustomOptions] table.
--- Format: { Alias = CanonicalOption }
--- These are resolved before user options are processed and cannot be modified at runtime.
--- @field timeout string -- DecompileTimeout
--- @field FileName string -- FilePath
--- @field IgnoreArchivable string -- IgnoreNotArchivable
--- @field IgnoreDefaultProps string -- IgnoreDefaultProperties
--- @field InstancesBlacklist string -- IgnoreList
--- @field SaveLocalPlayer string -- IsolateLocalPlayer
--- @field IsolatePlayerGui string -- IsolateLocalPlayer
--- @field SavePlayerGui string -- IsolateLocalPlayer
--- @field SavePlayers string -- IsolatePlayers
--- @field SaveNonCreatable string -- SaveNotCreatable
--- @field SaveCharacters string -- SavePlayerCharacters

--- @interface OptionsAliasesInverse
--- @within SynSaveInstance
--- Alias → Canonical option mapping with boolean inversion.
--- Format: { Alias = CanonicalOption }
--- These aliases invert the provided boolean value before applying it.
--- Example: noscripts = true → Decompile = false
--- @field noscripts string -- Decompile
--- @field RemovePlayers string -- IsolatePlayers
--- @field RemovePlayerCharacters string -- SavePlayerCharacters

--[=[
	@function saveinstance
	Saves instances with specified options. Example:
	```lua
	local Params = {
		RepoURL = "https://raw.githubusercontent.com/xgg-2/xgg-2/main/",
		SSI = "saveinstance",
	}

	local synsaveinstance = loadstring(game:HttpGet(Params.RepoURL .. Params.SSI .. ".luau", true), Params.SSI)()

	local CustomOptions = { SafeMode = true, DecompileTimeout = 15, SaveBytecode = true }

	synsaveinstance(CustomOptions)
	```
	@within SynSaveInstance
	@yields
	@param Parameter_1 variant<table, table<Instance>> -- Can either be [SynSaveInstance.CustomOptions table] or a filled with instances ({Instance}), (then it will be treated as ExtraInstances with an invalid mode and IsModel will be true).
	@param Parameter_2 table -- [OPTIONAL] If present, then Parameter_2 will be assumed to be [SynSaveInstance.CustomOptions table]. And then if the Parameter_1 is an Instance, then it will be assumed to be [SynSaveInstance.CustomOptions table].Object. If Parameter_1 is a table filled with instances ({Instance}), then it will be assumed to be [SynSaveInstance.CustomOptions table].ExtraInstances and IsModel will be true). This exists for sake compatibility with `saveinstance(game, {})`
]=]

local function run_save(CustomOptions, CustomOptions2)
	if GLOBAL_ENV.XSAVE_RUNNING then
		return
	end
	GLOBAL_ENV.XSAVE_RUNNING = true
	-- do -- ? Causes issues on SirHurt (Kick lacking Capability "Consequences"), let threads operate on their default/preferred identity set by the developers
	-- 	local setthreadidentity = global_container.setthreadidentity
	-- 	if setthreadidentity then
	-- 		pcall(setthreadidentity, 8) -- ? Arceus X Fix
	-- 	end
	-- end

	local totalsize, chunks = 0, table.create(1)
	local savebuffer, savebuffer_size = {}, 1
	local CREDIT = "<!-- xsave (xgg-2), based on UniversalSynSaveInstance https://discord.gg/wx4ThpAsmw -->"
	local header = '<roblox version="4">'

	local StatusText

	local OPTIONS = {
		mode = "optimized",
		Decompile = EXECUTOR_NAME ~= "Velocity", -- TODO Temp fix for crashes
		scriptcache = true,
		-- decomptype = "",
		DecompileTimeout = 10,
		BytecodeTimeout = 3,
		-- * New:
		__DEBUG_MODE = false,

		-- Binary = false, -- true in syn newer versions (false in our case because no binary support yet), Description: Saves everything in Binary Mode (rbxl/rbxm).
		Callback = false,
		--Clipboard/CopyToClipboard = false, -- Description: If set to true, the serialized data will be set to the clipboard, which can be later pasted into studio easily. Useful for saving models. (Binary Only)
		-- MaxThreads = 3 -- Description: The number of decompilation threads that can run at once. More threads means it can decompile for scripts at a time.
		-- DisableCompression = false, --Description: Disables compression in the binary output

		DecompileJobless = false,
		DecompileIgnore = { -- * Clean these up (merged Old Syn and New Syn)
			-- "Chat",
			"TextChatService",
			ModuleScript = nil,
		},
		IgnoreDefaultPlayerScripts = true,
		SaveBytecode = false,

		IgnoreProperties = {},

		IgnoreList = { "CoreGui", "CorePackages" },

		ExtraInstances = {},
		NilInstances = false,
		NilInstancesFixes = {},

		SaveCacheInterval = 0x1600 * 10,
		ShowStatus = true,
		KillAllScripts = true,
		CreditComment = true, -- Keeps the required UniversalSynSaveInstance credit comment at the top of saved files
		SafeMode = true,
		BoostFPS = false,
		ShutdownWhenDone = false,
		AntiIdle = true,
		Anonymous = false,
		ReadMe = true,
		FilePath = false,
		AvoidFileOverwrite = true,
		Object = false,
		IsModel = false,

		IgnoreDefaultProperties = true,
		IgnoreNotArchivable = true,
		IgnorePropertiesOfNotScriptsOnScriptsMode = false,
		IgnoreSpecialProperties = ArrayToDict({ "Fluxus", "Delta", "Solara" })[EXECUTOR_NAME] or false, -- ! Please submit more Executors that crash on gethiddenproperty (with this disabled basically)

		IsolateLocalPlayer = false, --  #service.StarterGui:GetChildren() == 0
		IsolateLocalPlayerCharacter = false,
		IsolatePlayers = false,
		IsolateStarterPlayer = false,
		SavePlayerCharacters = false,

		SaveNotCreatable = false,
		NotCreatableFixes = {
			-- "InputObject",
			-- "LodDataEntity",
			-- "Path",
			"", -- * FilteredSelection
			"AdvancedDragger",
			"AnimationTrack",
			"Dragger",
			"Player",
			"PlayerGui",
			"PlayerMouse",
			"PlayerMouse",
			"PlayerScripts",
			"ScreenshotHud",
			"StudioData",
			"TextChatMessage",
			"TextSource",
			"TouchTransmitter",
			"Translator",
			CloudLocalizationTable = "LocalizationTable",
			Platform = "Part",
			Status = "Model", -- gets created by studio automatically usually so there will be duplicates due to this
			-- CoreScript = "Script", -- useless
			-- ChatWindowMessageProperties = "TextChatMessageProperties", -- ? Not needed as this can be derived with ChatWindowConfiguration.DeriveNewMessageProperties
		},

		-- ! Risky

		IgnoreSharedStrings = EXECUTOR_NAME ~= "Wave",
		SharedStringOverwrite = false,
		TreatUnionsAsParts = EXECUTOR_NAME == "Solara", -- TODO Temporary true (once removed, remove Note from docs too)
		AlternativeWritefile = not ArrayToDict({ "WRD", "Xeno", "Zorara" })[EXECUTOR_NAME],

		OptionsAliases = { -- You can't really modify these as a user (because they're read before user's Options are loaded)
			timeout = "DecompileTimeout",
			FileName = "FilePath",
			IgnoreArchivable = "IgnoreNotArchivable",
			IgnoreDefaultProps = "IgnoreDefaultProperties",
			InstancesBlacklist = "IgnoreList",
			SaveLocalPlayer = "IsolateLocalPlayer",
			IsolatePlayerGui = "IsolateLocalPlayer",
			SavePlayerGui = "IsolateLocalPlayer",
			SaveNonCreatable = "SaveNotCreatable",
			SavePlayers = "IsolatePlayers",
			SaveCharacters = "SavePlayerCharacters",
		},
		OptionsAliasesInverse = {
			noscripts = "Decompile",
			RemovePlayers = "IsolatePlayers",
			RemovePlayerCharacters = "SavePlayerCharacters",
		},
	}
	local OPTIONS_lowercase, OptionsAliasesInverse_lowercase, CustomOptions_valid = {}, {}, {}

	do
		local function buildMap(dest, source, warnLabel)
			for k, v in source do
				local key = string.lower(k)

				if dest[key] then
					warn("DUPLICATE " .. warnLabel, k)
				else
					dest[key] = v
				end
			end
		end

		-- base options
		for o in OPTIONS do
			local option = string.lower(o)
			if OPTIONS_lowercase[option] then
				warn("DUPLICATE OPTION", o)
			else
				OPTIONS_lowercase[option] = o
			end
		end

		-- aliases
		buildMap(OPTIONS_lowercase, OPTIONS.OptionsAliases, "ALIAS")

		-- inverse aliases
		buildMap(OptionsAliasesInverse_lowercase, OPTIONS.OptionsAliasesInverse, "INVERSE ALIAS")
	end

	do -- * Load Settings
		local function construct_NilinstanceFix(Name, ClassName, Separate)
			return function(instance, instancePropertyOverrides)
				local Exists

				if not Separate then
					Exists = OPTIONS.NilInstancesFixes[Name]
				end

				local Fix

				local DoesntExist = not Exists
				if DoesntExist then
					Fix = Instance.new(ClassName)
					if not Separate then
						OPTIONS.NilInstancesFixes[Name] = Fix
					end
					-- Fix.Name = Name

					instancePropertyOverrides[Fix] =
						{ __SaveSpecific = true, __Children = { instance }, Properties = { Name = Name } }
				else
					Fix = Exists
					table.insert(instancePropertyOverrides[Fix].__Children, instance)
				end

				-- InstancesOverrides[instance].Parent = AnimationController
				if DoesntExist then
					return Fix
				end
			end
		end

		-- TODO: Merge BaseWrap & Attachment & AdPortal fix (put all under MeshPart container)
		-- TODO?:
		-- DebuggerWatch DebuggerWatch must be a child of ScriptDebugger
		-- PluginAction Parent of PluginAction must be Plugin or PluginMenu that created it!
		OPTIONS.NilInstancesFixes.Animator = construct_NilinstanceFix(
			"Animator has to be placed under Humanoid or AnimationController",
			"AnimationController"
		)
		OPTIONS.NilInstancesFixes.AdPortal = construct_NilinstanceFix("AdPortal must be parented to a Part", "Part")
		OPTIONS.NilInstancesFixes.Attachment =
			construct_NilinstanceFix("Attachments must be parented to a BasePart or another Attachment", "Part") -- * Bones inherit from Attachments
		OPTIONS.NilInstancesFixes.BaseWrap =
			construct_NilinstanceFix("BaseWrap must be parented to a MeshPart", "MeshPart")
		OPTIONS.NilInstancesFixes.PackageLink =
			construct_NilinstanceFix("Package already has a PackageLink", "Folder", true)

		if CustomOptions2 and type(CustomOptions2) == "table" then
			local tmp = CustomOptions
			local Type = typeof(tmp)
			CustomOptions = CustomOptions2
			if Type == "Instance" then
				CustomOptions.Object = tmp
			elseif Type == "table" and typeof(tmp[1]) == "Instance" then
				CustomOptions.ExtraInstances = tmp
				OPTIONS.IsModel = true
			end
		end

		local Type = typeof(CustomOptions)

		if Type == "table" then
			if typeof(CustomOptions[1]) == "Instance" then
				OPTIONS.mode = "invalidmode"
				OPTIONS.ExtraInstances = CustomOptions
				OPTIONS.IsModel = true
				CustomOptions = {}
			else
				for key, value in CustomOptions do
					local k = string.lower(key)

					local option = OPTIONS_lowercase[k]
					local invert = false

					if not option then
						option = OptionsAliasesInverse_lowercase[k]
						invert = option ~= nil
					end

					if option then
						local finalValue
						if invert then
							finalValue = not value
						else
							finalValue = value
						end

						OPTIONS[option] = finalValue
						CustomOptions_valid[option] = true
					else
						warn("[xsave] Unknown option: " .. tostring(key))
					end
				end
			end
		elseif Type == "Instance" then
			OPTIONS.mode = "invalidmode"
			OPTIONS.Object = CustomOptions
			CustomOptions = {}
		else
			CustomOptions = {}
		end
	end

	if not writefile and not OPTIONS.Callback then
		-- appendfile could be used a fallback but what kind of exec has appendfile without writefile
		local function coreCall(method, ...)
			local StarterGui = service.StarterGui
			method = StarterGui[method]
			if not method then
				return
			end

			for _ = 1, 10 do -- maxtries
				local success, result = pcall(method, StarterGui, ...)
				if success then
					return result
				end
				task.wait(1)
			end
		end

		local text = 'Function "writefile" is NOT available\nUse the Option "Callback" instead for now (check docs)'

		coreCall("SetCore", "SendNotification", {
			Title = "SAVEINSTANCE ERROR",
			Text = text,
			Duration = 15,
			Icon = "rbxassetid://9072920609",
		})
		coreCall("SetCore", "SendNotification", {
			Title = "SAVEINSTANCE ERROR",
			Text = "Please ask your executor's developers to add writefile",
			Duration = 15,
			Icon = "rbxassetid://9072920609",
		})

		warn(text)

		GLOBAL_ENV.XSAVE_RUNNING = nil
		return
	end

	if OPTIONS.IgnoreDefaultPlayerScripts then
		-- TODO This is a bad workaround, find a better automatic way
		-- TODO Look into https://robloxapi.github.io/ref/class/LuaSourceContainer.html#member-isPlayerScript
		local DecompileIgnore = OPTIONS.DecompileIgnore

		local default_scripts = ArrayToDict({
			ModuleScript = { "PlayerModule" },
			LocalScript = {
				"BubbleChat",
				"ChatScript",
				"PlayerScriptsLoader",
				"RbxCharacterSounds",
			},
		}, true)

		local function ignorePath(path)
			if path then
				for _, child in path:GetChildren() do
					local class_match = default_scripts[child.ClassName]
					if class_match then
						local name_match = class_match[child.Name]
						if name_match then
							table.insert(DecompileIgnore, child)
						end
					end
				end
			end
		end

		ignorePath(service.StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts"))

		local LocalPlayer = service.Players.LocalPlayer
		if LocalPlayer then
			ignorePath(LocalPlayer:FindFirstChildOfClass("PlayerScripts"))
		end
	end

	local InstancesOverrides = {}

	local DecompileIgnore, IgnoreList, IgnoreProperties, NotCreatableFixes =
		ArrayToDict(OPTIONS.DecompileIgnore, true),
		ArrayToDict(OPTIONS.IgnoreList, true),
		ArrayToDict(OPTIONS.IgnoreProperties),
		ArrayToDict(OPTIONS.NotCreatableFixes, true, "Folder")

	local __DEBUG_MODE = OPTIONS.__DEBUG_MODE

	if __DEBUG_MODE and type(__DEBUG_MODE) ~= "function" then
		__DEBUG_MODE = warn
	end

	local LP_UserId, LP_Name, ANON_UserId, ANON_Name, AnonymizableTypes

	do
		local anonymous = OPTIONS.Anonymous
		local lp = service.Players.LocalPlayer

		if anonymous and lp then
			AnonymizableTypes = ArrayToDict({ "double", "float", "int", "int64", "string" })
			LP_UserId, LP_Name = lp.UserId, lp.Name

			local istable = type(anonymous) == "table"
			ANON_UserId = istable and anonymous.UserId or 1
			ANON_Name = istable and anonymous.Name or "Roblox"
		end
	end

	local FilePath = OPTIONS.FilePath
	local SaveCacheInterval = OPTIONS.SaveCacheInterval
	local ToSaveInstance = OPTIONS.Object
	local IsModel = OPTIONS.IsModel

	if ToSaveInstance and CustomOptions.IsModel == nil then
		IsModel = true
	end

	local IgnoreDefaultProperties = OPTIONS.IgnoreDefaultProperties
	local IgnoreNotArchivable = not OPTIONS.IgnoreNotArchivable
	local IgnorePropertiesOfNotScriptsOnScriptsMode = OPTIONS.IgnorePropertiesOfNotScriptsOnScriptsMode

	local old_gethiddenproperty
	if OPTIONS and gethiddenproperty then
		old_gethiddenproperty = gethiddenproperty
		gethiddenproperty = nil
	end

	local SaveNotCreatable = OPTIONS.SaveNotCreatable
	local TreatUnionsAsParts = OPTIONS.TreatUnionsAsParts

	local DecompileJobless = OPTIONS.DecompileJobless
	if DecompileJobless then
		OPTIONS.scriptcache = true
	end
	local ScriptCache = OPTIONS.scriptcache and getscriptbytecode

	local DecompileTimeout = OPTIONS.DecompileTimeout

	local IgnoreSharedStrings = OPTIONS.IgnoreSharedStrings
	local SharedStringOverwrite = OPTIONS.SharedStringOverwrite

	local ldeccache = GLOBAL_ENV.XSAVE_SCRIPTCACHE

	local DecompileIgnoring, ToSaveList, ldecompile, placename, elapse_t, SaveNotCreatableWillBeEnabled, RecoveredScripts

	if OPTIONS.ReadMe then
		RecoveredScripts = {}
	end

	if ScriptCache and not ldeccache then
		ldeccache = {}
		GLOBAL_ENV.XSAVE_SCRIPTCACHE = ldeccache
	end

	if ToSaveInstance == game then
		OPTIONS.mode = "full"
		ToSaveInstance = nil
		IsModel = nil
	end

	local function isLuaSourceContainer(instance)
		return instance:IsA("LuaSourceContainer")
	end

	do
		Control.Options = OPTIONS
		local mode = string.lower(OPTIONS.mode)
		local tmp = table.clone(OPTIONS.ExtraInstances)

		local PlaceName = game.PlaceId

		pcall(function()
			PlaceName ..= " " .. service.MarketplaceService:GetProductInfoAsync(PlaceName).Name
		end)

		local function sanitizeFileName(str)
			return string.sub(string.gsub(string.gsub(string.gsub(str, "[^%w _]", ""), " +", " "), " +$", ""), 1, 240)
		end

		if ToSaveInstance then
			if mode == "optimized" then -- ! NOT supported with Model file mode
				mode = "full"
			end

			for _, key in
				{
					"IsolateLocalPlayer",
					"IsolateLocalPlayerCharacter",
					"IsolatePlayers",
					"IsolateStarterPlayer",
					"NilInstances",
				}
			do
				if CustomOptions_valid[key] == nil then
					OPTIONS[key] = false
				end
			end
		end

		local filetype = IsModel and ".rbxmx" or ".rbxlx"

		if FilePath then
			placename = FilePath
		elseif IsModel then
			placename =
				sanitizeFileName("model " .. PlaceName .. " " .. (ToSaveInstance or tmp[1] or game):GetFullName())
		else
			placename = sanitizeFileName("place " .. PlaceName)
		end

		if OPTIONS.AvoidFileOverwrite and isfile then
			local counter = 0
			local temp = placename

			while isfile(temp .. filetype) do
				counter += 1
				temp = placename .. "(" .. counter .. ")"
			end

			placename = temp .. filetype
		else
			placename = placename .. filetype
		end

		if GLOBAL_ENV[placename] then -- ? AvoidFileOverwrite kinda messes with this, but shouldn't be an issue
			-- warn("xsave is already saving to this file")
			return
		end

		GLOBAL_ENV[placename] = true
		Control.LockedPlace = placename
		Control.FileName = placename
		GLOBAL_ENV.XSAVE_RUNNING = nil

		if mode ~= "scripts" then
			IgnorePropertiesOfNotScriptsOnScriptsMode = nil
		end

		local TempRoot = ToSaveInstance or game

		if mode == "full" then
			if not ToSaveInstance then
				local Children = TempRoot:GetChildren()
				if 0 < #Children then
					local tmp_dict = ArrayToDict(tmp)
					for _, child in Children do
						if not tmp_dict[child] then
							table.insert(tmp, child)
						end
					end
				end
			end
		elseif mode == "optimized" then -- ! Incompatible with .rbxmx (Model file) mode
			-- if IsolatePlayers then
			-- 	table.insert(_list_0, "Players")
			-- end
			local tmp_dict = ArrayToDict(tmp)

			for _, serviceName in
				{
					"Workspace",
					"Players",
					"Lighting",
					"MaterialService",
					"ReplicatedFirst",
					"ReplicatedStorage",

					"ServerScriptService", -- LoadStringEnabled property (doesn't replicate); Just in case
					"ServerStorage", -- Just in case

					"StarterGui",
					"StarterPack",
					"StarterPlayer",
					"Teams",
					"SoundService",
					"Chat",
					"TextChatService",

					"LocalizationService", -- For LocalizationTables
					-- "InsertService",
					"JointsService",

					-- "TestService",
					-- "VoiceChatService",
				}
			do
				local _service = game:FindService(serviceName)
				if _service and not tmp_dict[_service] then
					table.insert(tmp, _service)
				end
			end
		elseif mode == "scripts" then
			-- TODO: Only save paths that lead to scripts (nothing else)
			-- Currently saves paths along with children of each tree
			local unique = {}
			for _, instance in TempRoot:GetDescendants() do
				if isLuaSourceContainer(instance) then
					local Parent = instance.Parent
					while Parent and Parent ~= TempRoot do
						instance = instance.Parent
						Parent = instance.Parent
					end
					if Parent then
						unique[instance] = true
					end
				end
			end
			for instance in unique do
				table.insert(tmp, instance)
			end
		end

		ToSaveList = tmp

		if ToSaveInstance then
			table.insert(ToSaveList, 1, ToSaveInstance)
		end
	end

	local IsolateLocalPlayer = OPTIONS.IsolateLocalPlayer
	local IsolateLocalPlayerCharacter = OPTIONS.IsolateLocalPlayerCharacter
	local IsolatePlayers = OPTIONS.IsolatePlayers
	local IsolateStarterPlayer = OPTIONS.IsolateStarterPlayer
	local NilInstances = OPTIONS.NilInstances

	if NilInstances and enablenilinstances then -- ? Solara fix
		enablenilinstances()
	end
	local function get_size_format()
		local Size

		for i, unit in
			{
				"B",
				"KB",
				"MB",
				"GB",
				"TB",
			}
		do
			if totalsize < 0x400 ^ i then
				Size = math.floor(totalsize / (0x400 ^ (i - 1)) * 10) / 10 .. " " .. unit
				break
			end
		end

		return Size
	end

	local RunService = service.RunService
	local function wait_for_render()
		RunService.RenderStepped:Wait()
	end

	local Loading
	local function run_with_loading(text, keepStatus, waitForRender, taskFunction, ...)
		local previousStatus

		if StatusText then
			if keepStatus then
				previousStatus = StatusText.Text
			end
			Loading = task.spawn(function()
				local spinner_count = 0
				local chars = { "|", "/", "—", "\\" }
				local chars_size = #chars

				local function getLoadingText()
					spinner_count += 1

					if chars_size < spinner_count then
						spinner_count = 1
					end

					return chars[spinner_count]
				end

				text ..= " "

				while true do
					StatusText.Text = text .. getLoadingText()
					task.wait(0.25)
				end
			end)
			if waitForRender then
				wait_for_render()
			end
		end

		local result = { taskFunction(...) }

		if Loading then
			task.cancel(Loading)
			Loading = nil
			if previousStatus then
				StatusText.Text = previousStatus
			end
		end

		return unpack(result)
	end

	local function construct_TimeoutHandler(timeout, f, timeout_return)
		return timeout < 0 and function(script)
			return pcall(f, script)
		end or function(script) -- TODO Ideally use ... (vararg) instead of `script` in case this is reused for something other than `decompile` & `getscriptbytecode`
			local thread = coroutine.running()
			local timeoutThread, isCancelled

			timeoutThread = task.delay(timeout, function()
				isCancelled = true -- TODO task.cancel
				coroutine.resume(thread, nil, timeout_return)
			end)

			task.spawn(function()
				local ok, result = pcall(f, script)

				if isCancelled then
					return
				end

				task.cancel(timeoutThread)

				while coroutine.status(thread) ~= "suspended" do
					task.wait()
				end

				coroutine.resume(thread, ok, result)
			end)

			return coroutine.yield()
		end
	end

	local getbytecode
	if getscriptbytecode then
		getbytecode = construct_TimeoutHandler(OPTIONS.BytecodeTimeout, getscriptbytecode) -- ? Solara fix
	end

	local SaveBytecode
	if OPTIONS.SaveBytecode and getscriptbytecode then
		SaveBytecode = function(script)
			local s, bytecode = getbytecode(script)

			if s and bytecode and bytecode ~= "" then
				return "-- Bytecode (Base64):\n-- " .. base64encode(bytecode) .. "\n\n"
			end
		end
	end

	do
		if not OPTIONS.Decompile then
			ldecompile = function()
				return "-- Decompiling is disabled"
			end
		elseif decompile then
			local decomp = construct_TimeoutHandler(DecompileTimeout, decompile, "Decompiler timed out")

			ldecompile = function(script)
				-- local name = scr.ClassName .. scr.Name
				local bytecode
				if ScriptCache then
					local s
					s, bytecode = getbytecode(script)
					local cached

					if s then
						if not bytecode or bytecode == "" then
							return "-- The Script is Empty"
						end
						cached = ldeccache[bytecode]
					else
						bytecode = nil
					end

					if cached then
						if __DEBUG_MODE then
							__DEBUG_MODE("Found in Cache", script:GetFullName())
						end
						return cached
					end
				else
					if DecompileJobless then
						return "-- Not found in already decompiled ScriptCache"
					end

					-- task.wait() -- TODO Maybe remove?
				end

				local decompileStarted = os.clock()
				local ok, result = run_with_loading("Decompiling " .. script.Name, true, nil, decomp, script)
				Control.Decompiled += 1
				Control.DecompileTime += os.clock() - decompileStarted
				if not result then
					ok, result = false, "Empty Output"
				end

				local output
				if ok then
					result = string.gsub(result, "\0", "\\0") -- ? Some decompilers sadly output \0 which prevents files from opening
					output = result
				else
					output = "--[[ Failed to decompile. Reason:\n" .. (result or "") .. "\n]]"
				end

				if ScriptCache and bytecode then -- TODO there might(?) be an edgecase where it manages to decompile (built-in) even though getscriptbytecode failed, and the output won't get cached
					ldeccache[bytecode] = output -- ? Should we cache even if it timed out?
					if __DEBUG_MODE then
						__DEBUG_MODE("Cached", script:GetFullName())
					end
				end

				return output
			end
		else
			ldecompile = function()
				return "-- Your Executor does NOT have a Decompiler"
			end
		end
	end

	local function GetLocalPlayer()
		return service.Players.LocalPlayer
			or service.Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
			or service.Players.LocalPlayer
	end

	local function filterLinkedSource(str)
		local o, r = pcall(service.HttpService.JSONDecode, service.HttpService, str)
		if o and r.errors then
			return
		end
		return true
	end

	local function replaceClassName(instance, InstanceName, ClassName)
		local InstanceOverride
		if InstanceName ~= ClassName then -- TODO Compare against default instance instead (TouchTransmitter is called TouchInterest by default)
			InstanceOverride = InstancesOverrides[instance]
			if not InstanceOverride then
				InstanceOverride = { Properties = { Name = "[" .. ClassName .. "] " .. InstanceName } }
				InstancesOverrides[instance] = InstanceOverride
			end
		end
		return InstanceOverride
	end

	local function gsubCaseInsensitive(input, search, replacement) -- * Credits to friends
		local inputLower = string.lower(input)
		search = string.lower(search)

		if not string_find(input, search) then
			return input
		end

		local lastFinish = 0
		local subStrings = {}
		local search_len = #search
		local input_len = #input
		while search_len <= input_len - lastFinish do
			local init = lastFinish + 1

			local start, finish = string_find(inputLower, search, init)

			if start == nil then
				break
			end

			table.insert(subStrings, string.sub(input, init, start - 1))

			lastFinish = finish
		end

		if lastFinish == 0 then
			return input
		end

		table.insert(subStrings, string.sub(input, lastFinish + 1))

		return table.concat(subStrings, replacement)
	end

	local function filterPropVal(result, propertyName, category) -- ? raw == nil thanks to SerializedDefaultAttributes; "can't get value" - due to WriteOnly tag;  "Invalid value for enum " - "StreamingPauseMode" (old games probably) Roexec
		return result == nil
			or result == "can't get value"
			or type(result) == "string"
				and (category == "Enum" or string_find(result, "Unable to get property " .. propertyName))
	end

	local function ReadProperty(instance, property, propertyName, special, category, optional)
		local raw = __BREAK

		local InstanceOverride = InstancesOverrides[instance]
		if InstanceOverride then
			local PropertiesOverride = InstanceOverride.Properties
			if PropertiesOverride then
				local PropertyOverride = PropertiesOverride[propertyName]
				if PropertyOverride ~= nil then
					return PropertyOverride
				end
			end
		end

		local CanRead = property.CanRead

		if CanRead == false then -- * Skips because we've checked this property before
			return __BREAK
		end

		if special then
			if gethiddenproperty then
				local ok, result = pcall(gethiddenproperty, instance, propertyName)

				if ok then
					raw = result
				end

				if filterPropVal(raw, propertyName, category) then
					-- * Skip next time we encounter this too perhaps (unless there's a chance for it to be readable on other instance, somehow)

					if result ~= nil or not optional then
						if __DEBUG_MODE then
							__DEBUG_MODE("Filtered", propertyName)
						end
						-- Property.Special = false
						property.CanRead = false
					end

					return __BREAK -- ? We skip it because even if we use "" it will just reset to default in most cases, unless it's a string tag for example (same as not being defined)
				end
			end
		else
			if CanRead then
				raw = instance[propertyName]
			else -- Assuming CanRead == nil (untested)
				local ok, result = pcall(index, instance, propertyName)

				if ok then
					raw = result
				elseif gethiddenproperty then -- ! Be careful with this 'and gethiddenproperty' logic
					ok, result = pcall(gethiddenproperty, instance, propertyName)

					if ok then
						raw = result

						property.Special = true
					end
				end

				property.CanRead = ok

				if not ok or filterPropVal(raw, propertyName, category) then
					return __BREAK
				end
			end
		end

		return raw
	end

	local function ReturnItem(className, instance)
		return '<Item class="' .. className .. '" referent="' .. GetRef(instance) .. '"><Properties>' -- TODO: Ideally this shouldn't return <Properties> as well as the line below to close it IF  IgnorePropertiesOfNotScriptsOnScriptsMode is Enabled OR If all properties are default (reduces file size by at least 1.4%)
	end

	local function ReturnProperty(tag, propertyName, value)
		return "<" .. tag .. ' name="' .. propertyName .. '">' .. value .. "</" .. tag .. ">"
	end

	local function ReturnValueAndTag(raw, valueType, descriptor)
		local value, tag = (descriptor or XML_Descriptors[valueType])(raw)

		return value, tag or valueType
	end

	local function InheritsFix(fixes, className, instance)
		local Fix = fixes[className]
		if Fix then
			return Fix
		elseif Fix == nil then
			for class_name, fix in fixes do
				if instance:IsA(class_name) then
					return fix
				end
			end
		end
	end

	local function GetInheritedProps(className)
		local cached = inherited_properties[className]
		if cached then
			return cached
		end

		local prop_list = {}
		local layer = ClassList[className]
		while layer do
			local layer_props = layer.Properties
			table.move(layer_props, 1, #layer_props, #prop_list + 1, prop_list)

			-- for _, prop in layer.Properties do
			-- 	prop_list[prop_count] = prop -- ? table.clone is needed for case where .Default is modified
			-- 	prop_count += 1
			-- end

			layer = ClassList[layer.Superclass]
		end
		inherited_properties[className] = prop_list
		return prop_list
	end

	local function save_cache()
		local savestr = table.concat(savebuffer)

		local savestr_len = #savestr
		totalsize += savestr_len
		Control.Size = totalsize

		-- store chunk as-is (NO concatenation accumulation)
		table.insert(chunks, savestr)

		table.clear(savebuffer)
		savebuffer_size = 1

		if StatusText then
			StatusText.Text = "Saving.. Size: " .. get_size_format() .. " | Instances: " .. Control.Processed
		end

		wait_for_render() -- ? Needed for at least 1fps (status text)
	end

	local function save_specific(className, properties)
		local Ref = Instance.new(className) -- ! Assuming anything passed here is Creatable
		local Item = ReturnItem(Ref.ClassName, Ref)

		for propertyName, val in properties do
			local whitelisted, value, tag

			-- TODO: Improve all sort of overrides & exceptions in the code (code below is awful)
			if propertyName == "Source" then
				tag = "ProtectedString"
				value = XML_Descriptors.__PROTECTEDSTRING(val)
				whitelisted = true
			elseif propertyName == "Name" then
				whitelisted = true
				value, tag = ReturnValueAndTag(val, "string") -- * Doubt ValueType will change
			end

			if whitelisted then
				Item ..= ReturnProperty(tag, propertyName, value)
			end
		end
		Item ..= "</Properties>"
		return Item
	end

	local gethiddenproperty_fallback

	local function save_hierarchy(hierarchy)
		for _, instance in hierarchy do
			if Control.Kill then
				error("xsave: killed by user", 0)
			end
			if Control.Stop then
				break
			end
			Control.Processed += 1

			local InstanceOverride, ClassTagOverride, ClassNameOverride

			if not InstanceOverride then
				InstanceOverride = InstancesOverrides[instance]
				if InstanceOverride then
					ClassTagOverride = InstanceOverride.__ClassName
				end
			end
			local ClassName = instance.ClassName

			local InstanceName = instance.Name
			local SkipEntirely

			if not ClassTagOverride then -- ! Assuming anything that has __ClassName comes from save_extra
				if IgnoreNotArchivable and not instance.Archivable then
					continue
				end

				SkipEntirely = IgnoreList[instance]
				if SkipEntirely then
					continue
				end

				do
					local OnIgnoredList = IgnoreList[ClassName]
					if OnIgnoredList and (OnIgnoredList == true or OnIgnoredList[InstanceName]) then
						continue
					end
				end

				if not DecompileIgnoring then
					DecompileIgnoring = DecompileIgnore[instance]

					if DecompileIgnoring == nil then
						local DecompileIgnored = DecompileIgnore[ClassName]
						if DecompileIgnored then
							DecompileIgnoring = DecompileIgnored == true or DecompileIgnored[InstanceName]
						end
					end

					if DecompileIgnoring then
						DecompileIgnoring = instance
					elseif DecompileIgnoring == false then
						DecompileIgnoring = 1 -- Ignore one instance
					end
				end

				do
					local Fix = NotCreatableFixes[ClassName]

					if Fix then
						if SaveNotCreatable then
							ClassName, InstanceOverride = Fix, replaceClassName(instance, InstanceName, ClassName)
						else
							continue -- They won't show up in Studio anyway (Enable SaveNotCreatable if you wish to bypass this)
						end
					else -- ! Assuming nothing that is a PartOperation or inherits from it is in NotCreatableFixes
						if TreatUnionsAsParts and instance:IsA("PartOperation") then
							ClassName, InstanceOverride = "Part", replaceClassName(instance, InstanceName, ClassName)
							ClassNameOverride = "BasePart" -- * Mutual Superclass for PartOperation and Part; For properties only
						elseif not ClassList[ClassName] then -- ? API Dump is outdated then
							if __DEBUG_MODE then
								__DEBUG_MODE("Class not Found", ClassName)
							end

							ClassTagOverride = ClassName -- ? To at least retain .ClassName unlike the rest of the class-specific properties
							ClassName = "Folder" -- ? replaceClassName is not needed because of the ClassTagOverride
						end
					end
				end
			end
			-- ? The reason we only save .Name (and few other props in save_specific) is because
			-- ? we can be sure this is a custom container (ex. NilInstancesFixes)
			-- ? However, in case of NotCreatableFixes, the Instance might have Tags, Attributes etc. that can potentially be saved (even though it's a Folder)
			if InstanceOverride and InstanceOverride.__SaveSpecific then
				savebuffer[savebuffer_size] = save_specific(ClassName, InstanceOverride.Properties) -- ! Assuming anything that has __SaveSpecific will have .Properties
				savebuffer_size += 1
			else
				-- local Properties =
				savebuffer[savebuffer_size] = ReturnItem(ClassTagOverride or ClassName, instance) -- TODO: Ideally this shouldn't return <Properties> as well as the line below to close it IF  IgnorePropertiesOfNotScriptsOnScriptsMode is ENABLED
				savebuffer_size += 1
				if not (IgnorePropertiesOfNotScriptsOnScriptsMode and not isLuaSourceContainer(instance)) then
					local default_instance, new_def_inst

					if IgnoreDefaultProperties then
						default_instance = default_instances[ClassName]
						if not default_instance then
							local Class = ClassList[ClassName]
							if not Class.NotCreatable then -- __api_dump_class_not_creatable__ also indicates this
								-- NotCreatableFixes are exceptions to the check above meaning if we don't keep the NotCreatableFixes updated then Instance.new below might start erroring in the future potentially; HOWEVER IsPropertyModified solves this issue and no updates are really needed as NotCreatableFixes is up-to-date as of VERSION-HERE (which is when IPM gets enabled)
								local ok, result = pcall(Instance.new, ClassName) -- ! pcall is needed for level 3 execs (for example TestService); EXCEPTION NOTED ABOVE (irrelevant)

								if ok then
									new_def_inst = result

									default_instance = {}

									default_instances[ClassName] = default_instance
								else
									Class.NotCreatable = true
									if __DEBUG_MODE then
										__DEBUG_MODE("Failed to create default Instance", ClassName, result)
									end
								end
							elseif __DEBUG_MODE then
								__DEBUG_MODE("Unable to create default Instance (NotCreatable)", ClassName)
							end
						end
					end

					for _, Property in GetInheritedProps(ClassNameOverride or ClassName) do
						local PropertyName = Property.Name

						if IgnoreProperties[PropertyName] then
							continue
						end

						local ValueType = Property.ValueType

						if IgnoreSharedStrings and ValueType == "SharedString" then -- ? More info in Options
							continue
						end

						local Special, Category, Optional = Property.Special, Property.Category, Property.Optional
						local raw
						if
							not (
								ValueType == "ProtectedString"
								and PropertyName == "Source"
								and isLuaSourceContainer(instance)
							)
						then
							raw = ReadProperty(instance, Property, PropertyName, Special, Category, Optional)

							if raw == __BREAK then -- ! Assuming __BREAK is always returned when there's a failure to read a property
								local GHPFFailed, Fallback = Property.GHPFFailed, Property.Fallback
								if GHPFFailed and not Fallback then
									continue
								end

								if not GHPFFailed then
									local ok, result = pcall(gethiddenproperty_fallback, instance, PropertyName) -- * This helps in reading: Vector3int16, OptionalCoordinateFrame DataTypes. It also acts as an almost entire fallback for gethiddenproperty in case it is missing
									if result == nil and not Optional then
										ok = nil
									end

									if ok then
										raw = result
									else
										GHPFFailed = true
										Property.GHPFFailed = GHPFFailed
									end
								end

								if GHPFFailed and Fallback then
									local ok, result = pcall(Fallback, instance)

									if ok then
										raw = result
									else
										Property.Fallback = nil -- Low level execs might fail due to lack of some Capabilities
										if __DEBUG_MODE then
											__DEBUG_MODE("Fix Failed", PropertyName, result)
										end
										continue
									end
								end

								if raw == __BREAK then
									continue
								end
							end

							-- Special = Property.Special -- ? Read TODO below (must be updated if it's used frequently afterwards)

							if
								default_instance
								and Property.CanRead
								and not Property.Special -- TODO: .Special is checked more than once (because it might be updated during ReadProperty)
							then -- ? Could be not just "Source" in the future
								if new_def_inst then
									default_instance[PropertyName] = index(new_def_inst, PropertyName)
								end
								if default_instance[PropertyName] == raw then
									continue
								end
							end
						end
						-- Serialization start

						if SharedStringOverwrite and ValueType == "BinaryString" then -- TODO: Convert this to table if more types are added
							ValueType = "SharedString"
						end

						if AnonymizableTypes and AnonymizableTypes[ValueType] then
							-- TODO This might cause issues on non-unique Usernames (ex. "Cake" if game is about cakes then everything supposedly related to your name will be replaced with "Roblox"); Certain UserIds might also affect numbers, like if your UserId is 2481848 and there is some number that matches 2481848 then that number will be replaced with 1, potentially making the number incorrect.
							-- TODO So for now it's best to keep this disabled by default

							if ValueType == "string" then
								raw = gsubCaseInsensitive(raw, LP_Name, ANON_Name)
							elseif raw == LP_UserId then
								raw = ANON_UserId
							end
						end

						local tag, value
						if Category == "Class" then
							tag = "Ref"
							if raw then
								if SaveNotCreatableWillBeEnabled then
									local Fix = NotCreatableFixes[raw.ClassName]
									if
										Fix
										and (
											PropertyName == "PlayerToHideFrom"
											or ValueType ~= "Instance" and ValueType ~= Fix
										)
									then -- * To avoid errors
										continue
									end
								end

								value = GetRef(raw)
							else
								value = "null"
							end
						elseif Category == "Enum" then -- ! We do this order (Enums before Descriptors) specifically because Font Enum might get a Font Descriptor despite having Enum Category, unlike Font DataType which that Descriptor is meant for
							value, tag = XML_Descriptors.EnumItem(raw)
						else
							local Descriptor = XML_Descriptors[ValueType]

							if Descriptor then
								value, tag = ReturnValueAndTag(raw, ValueType, Descriptor)
							elseif ValueType == "ProtectedString" then -- TODO: Try fitting this inside Descriptors
								tag = ValueType

								if PropertyName == "Source" then
									if DecompileIgnoring then -- ? Should this really prevent extraction of the original source if present ?
										if DecompileIgnoring == 1 then
											DecompileIgnoring = nil
										end
										value = "-- Ignored"
									else
										local should_decompile = true
										local LinkedSource
										local o, LinkedSource_Url = pcall(index, instance, "LinkedSource") -- ! AuroraScript has Source but not LinkedSource
										if not o then
											LinkedSource_Url = ""
										end
										local hasLinkedSource = LinkedSource_Url ~= ""
										local LinkedSource_type
										if hasLinkedSource then
											local Path = instance:GetFullName()
											if RecoveredScripts then
												table.insert(RecoveredScripts, Path)
											end

											LinkedSource = string.match(LinkedSource_Url, "%w+$") -- TODO: No sure if this pattern matches all possible cases. Example is: 'rbxassetid://0&hash=cd73dd2fe5e5013137231c227da3167e'
											if LinkedSource then
												if ScriptCache then
													local cached = ldeccache[LinkedSource]

													if cached then
														value = cached
														should_decompile = nil
													end
												end
												if should_decompile then
													if DecompileJobless then
														value = "-- Not found in LinkedSource ScriptCache"
														should_decompile = nil
													end

													LinkedSource_type = string.find(LinkedSource, "%a") and "hash"
														or "id"

													local asset = LinkedSource_type .. "=" .. LinkedSource

													local ok, source = pcall(function()
														-- Credits @halffalse
														return game:HttpGet(
															"https://assetdelivery.roproxy.com/v1/asset/?" .. asset
														)
													end)

													if ok and filterLinkedSource(source) then
														if ScriptCache then
															ldeccache[LinkedSource] = source
														end

														value = source

														should_decompile = nil
													end
												end
											else --if __DEBUG_MODE then -- * We print this anyway because very important
												warn(
													"FAILED TO EXTRACT ORIGINAL SCRIPT SOURCE (OPEN A GITHUB ISSUE): ",
													instance:GetFullName(),
													LinkedSource_Url
												)
											end
										end

										if should_decompile then
											local isLocalScript = instance:IsA("LocalScript")
											if
												isLocalScript and instance.RunContext == Enum.RunContext.Server
												or not isLocalScript
													and instance:IsA("Script")
													and instance.RunContext ~= Enum.RunContext.Client
											then
												value = "-- [FilteringEnabled] Server Scripts are IMPOSSIBLE to save" -- TODO: Could be not just server scripts in the future
											else
												value = ldecompile(instance)
												if SaveBytecode then
													local output = SaveBytecode(instance)
													if output then
														value = output .. value
													end
												end
											end
										end

										value = (hasLinkedSource and "-- Original Source: https://assetdelivery.roblox.com/v1/asset/?" .. (LinkedSource_type or "id") .. "=" .. (LinkedSource or LinkedSource_Url) .. "\n\n" or "")
											.. value
									end
								end
								value = XML_Descriptors.__PROTECTEDSTRING(value)
							else
								--OptionalCoordinateFrame and so on, we make it dynamic

								if Optional then
									Descriptor = XML_Descriptors[Optional]

									if Descriptor then
										if raw == nil then
											-- * It can be empty, because it's optional
											-- ? Though why even save it if it's empty considering it's optional
											continue
										-- value, tag = "", ValueType
										else
											value, tag = ReturnValueAndTag(raw, ValueType, Descriptor)
										end
									end
								end
							end
						end

						if tag then
							savebuffer[savebuffer_size] = ReturnProperty(tag, PropertyName, value)
							savebuffer_size += 1
						else --if __DEBUG_MODE then -- * We print this anyway because very important
							warn("UNSUPPORTED TYPE (OPEN A GITHUB ISSUE): ", ValueType, ClassName, PropertyName)
						end
					end
				end
				savebuffer[savebuffer_size] = "</Properties>"
				savebuffer_size += 1

				if SaveCacheInterval < savebuffer_size then
					save_cache()
				end
			end

			if SkipEntirely ~= false then -- ? We save instance without it's descendants in this case (== false)
				local Children = InstanceOverride and InstanceOverride.__Children or instance:GetChildren()

				if #Children ~= 0 then
					save_hierarchy(Children)
				end
			end

			if DecompileIgnoring and DecompileIgnoring == instance then
				DecompileIgnoring = nil
			end

			savebuffer[savebuffer_size] = "</Item>"
			savebuffer_size += 1
		end
	end

	local function save_extra(name, instanceOrTable, saveProps, customClassName, source)
		if not customClassName then
			customClassName = "Folder"
		end

		local properties = { Name = name, Source = source }
		local hierarchy

		if instanceOrTable then
			if type(instanceOrTable) == "table" then
				hierarchy = instanceOrTable
			else
				hierarchy = instanceOrTable:GetChildren()
				if saveProps then
					-- IgnoreList[instanceOrTable] = nil
					-- IgnoreNotArchivable = false

					InstancesOverrides[instanceOrTable] = {
						__ClassName = customClassName, -- ! Assuming any class that contains ProtectedString is never passed, because it expects bytecode, not normal code
						-- __Children = hierarchy,
						Properties = properties,
					}

					save_hierarchy({ instanceOrTable })
				end
			end
		end

		if not saveProps then
			savebuffer[savebuffer_size] = save_specific(customClassName, properties)
			savebuffer_size += 1
			if hierarchy then
				save_hierarchy(hierarchy)
			end
			savebuffer[savebuffer_size] = "</Item>"
			savebuffer_size += 1
		end
	end

	local function save_game()
		do
			if IsModel then
				--[[
			-- ? Roblox encodes the following additional attributes. These are not required. Moreover, any defined schemas are ignored, and not required for a file to be valid: xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd"
			Also http can be converted to https but not sure if Roblox cares
			-- ? <External>null</External><External>nil</External>  - <External> is a legacy concept that is no longer used.
		]]
				header ..= '<Meta name="ExplicitAutoJoints">true</Meta>'
			end
			if writefile and not OPTIONS.Callback then
				writefile(placename, header) -- TODO This is sort of useless if writefile will be used at the end (like if AlternativeWritefile and Callback are unused)
			end
		end

		-- TODO Find a better solution for this
		SaveNotCreatableWillBeEnabled = SaveNotCreatable
			or (IsolateLocalPlayer or IsolateLocalPlayerCharacter) and IsolateLocalPlayer
			or IsolatePlayers
			or NilInstances and global_container.getnilinstances -- ! Make sure this accurately reflects everything below

		save_hierarchy(ToSaveList)

		if IsolateLocalPlayer or IsolateLocalPlayerCharacter then
			local LocalPlayer = service.Players.LocalPlayer
			if LocalPlayer then
				if IsolateLocalPlayer then
					SaveNotCreatable = true
					save_extra("LocalPlayer", LocalPlayer, true)
				end
				if IsolateLocalPlayerCharacter then
					local LocalPlayerCharacter = LocalPlayer.Character
					if LocalPlayerCharacter then
						save_extra("LocalPlayer Character", LocalPlayerCharacter, true, "Model")
					end
				end
			end
		end

		if IsolateStarterPlayer then
			-- SaveNotCreatable = true -- TODO: Enable if StarterPlayerScripts or StarterCharacterScripts stop showing up in isolated folder in Studio
			save_extra("StarterPlayer", service.StarterPlayer) -- no reason to saveprops as you can see the props on the original instance
		end

		if IsolatePlayers then
			SaveNotCreatable = true
			save_extra("Players", service.Players) -- no reason to saveprops as you can see the props on the original instance
		end

		if NilInstances and global_container.getnilinstances then
			local nil_instances, nil_instances_size = {}, 1

			local NilInstancesFixes = OPTIONS.NilInstancesFixes

			for _, instance in global_container.getnilinstances() do
				if instance == game then
					instance = nil
					-- break
				else
					local ClassName = instance.ClassName

					local Fix = InheritsFix(NilInstancesFixes, ClassName, instance)

					if Fix then
						instance = Fix(instance, InstancesOverrides)
						-- continue
					end

					local Class = ClassList[ClassName]
					if Class then
						if Class.Service then -- For CSGDictionaryService, NonReplicatedCSGDictionaryService, LogService, ProximityPromptService, TestService & more
							-- instance.Parent = game
							instance = nil
							-- continue
						end
					end
				end
				if instance then
					nil_instances[nil_instances_size] = instance
					nil_instances_size += 1
				end
			end
			SaveNotCreatable = true
			save_extra("Nil Instances", nil_instances)
		end

		if OPTIONS.ReadMe then
			save_extra(
				"README",
				nil,
				nil,
				"Script",
				"--[[\n"
					.. (#RecoveredScripts ~= 0 and "\t\tIMPORTANT: Original Source of these Scripts was Recovered: " .. service.HttpService:JSONEncode(
						RecoveredScripts
					) .. "\n" or "")
					.. [[
		If you didn't save in Binary (rbxl) - it's recommended to save the game right away to take advantage of the binary format & to preserve values of certain properties if you used IgnoreDefaultProperties setting (as they might change in the future).
		You can do that by going to FILE -> Save to File As -> Make sure File Name ends with .rbxl -> Save

		ServerStorage, ServerScriptService and Server Scripts are IMPOSSIBLE to save because of FilteringEnabled.

		If your player cannot spawn into the game, please move the scripts in StarterPlayer somewhere else or delete them. Then run `game:GetService("Players").CharacterAutoLoads = true`.
		And use "Play Here" to start game instead of "Play" to spawn your Character where your Camera currently is.

		If the chat system does not work, please use the explorer and delete everything inside the TextChatService/Chat service(s). 
		Or run `game:GetService("Chat"):ClearAllChildren() game:GetService("TextChatService"):ClearAllChildren()`
				
		If Union and MeshPart collisions don't work, run the script below in the Studio Command Bar:
				
				
		local C = game:GetService("CoreGui")
		local D = Enum.CollisionFidelity.Default
				
		for _, v in game:GetDescendants() do
			if v:IsA("TriangleMeshPart") and not v:IsDescendantOf(C) then
				v.CollisionFidelity = D
			end
		end
		print("Done")
				
		If you can't move the Camera, run this script in the Studio Command Bar:
			
		workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
		
		Or Destroy the Camera.

		This file was generated with the following settings:
		]]
					.. service.HttpService:JSONEncode(OPTIONS)
					.. "\n\n\t\tElapsed time: "
					.. os.clock() - elapse_t
					.. " Date (UTC): "
					.. DateTime.now():FormatUniversalTime("LL LTS", "en-gb")
					.. " PlaceId: "
					.. game.PlaceId
					.. " PlaceVersion: "
					.. game.PlaceVersion
					.. " Client Version: "
					.. FULL_VERSION
					.. " Platform: "
					.. (
						select(
							2,
							pcall(function()
								return service.UserInputService:GetPlatform().Name -- Won't work on lvl 2 execs but we can safely assume they're on PC (and likely Windows)
							end)
						) or "Unknown"
					)
					.. " Executor: "
					.. (identify_executor and table.concat({ identify_executor() }, " ") or "Unknown")
					.. "\n]]"
			)
		end
		do
			local tmp = { "<SharedStrings>" }
			for value, identifier in SharedStrings do
				table.insert(tmp, '<SharedString md5="' .. identifier .. '">' .. value .. "</SharedString>")
			end

			if 1 < #tmp then -- next(SharedStrings) check also works but seems to be slower
				savebuffer[savebuffer_size] = table.concat(tmp)
				savebuffer_size += 1
				savebuffer[savebuffer_size] = "</SharedStrings>"
				savebuffer_size += 1
			end
		end

		savebuffer[savebuffer_size] =
			"</roblox>"
		savebuffer_size += 1
		save_cache()
		do
			local function buildFinalString(chunks)
				local parts = table.create(#chunks + 1)
				parts[1] = (OPTIONS.CreditComment and CREDIT or "") .. header

				table.move(chunks, 1, #chunks, 2, parts)

				return table.concat(parts)
			end

			local Callback = OPTIONS.Callback
			if Callback then
				Callback(buildFinalString(chunks), chunks)
			elseif OPTIONS.AlternativeWritefile and appendfile then
				local SEGMENT_SIZE = 4145728 -- Celery has an arbitrary savefile/appendfile size limit of ~4MB for reasons unknown. This is a workaround to save the file in segments.
				local totallen = 0
				for _, chunk in chunks do
					totallen += math.ceil(#chunk / SEGMENT_SIZE)
				end

				local currentlen = 0

				for _, chunk in chunks do
					local chunk_len = #chunk
					local offset = 1

					while offset <= chunk_len do
						local savestr = string.sub(chunk, offset, offset + SEGMENT_SIZE - 1)

						run_with_loading(
							"Writing to File " .. math.round(currentlen / totallen * 100) .. "% (Depends on Exec)",
							nil,
							true,
							appendfile,
							placename,
							savestr
						)

						currentlen += 1
						offset += SEGMENT_SIZE

						if offset <= chunk_len then
							task.wait()
						end
					end
				end
			else
				run_with_loading(
					"Writing " .. get_size_format() .. " to File (Depends on Exec)",
					nil,
					true,
					writefile,
					placename,
					buildFinalString(chunks)
				)
			end
		end
	end

	local Connections = {}
	local function Connect(event, func)
		table.insert(Connections, event:Connect(func))
	end
	local function Cleanup()
		for _, connection in Connections do
			connection:Disconnect()
		end
		GLOBAL_ENV[placename] = nil
	end
	do
		local Players = service.Players

		if IgnoreList.Model ~= true then
			local function ignoreCharacter(player)
				Connect(player.CharacterAdded, function(character)
					IgnoreList[character] = true
				end)

				local Character = player.Character
				if Character then
					IgnoreList[Character] = true
				end
			end

			if not OPTIONS.SavePlayerCharacters then
				Connect(Players.PlayerAdded, function(player)
					ignoreCharacter(player)
				end)

				for _, player in Players:GetPlayers() do
					ignoreCharacter(player)
				end
			else
				IgnoreNotArchivable = false -- TODO Bad solution (Characters are NotArchivable); Also make sure the next solution is compatible with IsolateLocalPlayerCharacter
				if IsolateLocalPlayerCharacter then
					task.spawn(function()
						ignoreCharacter(GetLocalPlayer())
					end)
				end
			end
		end
		if IsolateLocalPlayer and IgnoreList.Player ~= true then
			task.spawn(function()
				IgnoreList[GetLocalPlayer()] = true
			end)
		end
	end

	if OPTIONS.KillAllScripts and not GLOBAL_ENV.XSAVE_KAS then
		GLOBAL_ENV.XSAVE_KAS = true
		-- * partial credits @centerepic
		game:GetService("ScriptContext"):SetTimeout(math.clamp(SaveCacheInterval * 0.000047, 20, 30))

		local self = coroutine.running()
		do
			local islclosure = islclosure
			local isexecutorclosure = isexecutorclosure or checkclosure or isourclosure
			local hookfunction = not ArrayToDict({ "SirHurt", "Volt" })[EXECUTOR_NAME] and hookfunction

			local function filterNkill(f)
				if not f then
					return
				end

				for _, v in table.clone(f()) do
					local _type = type(v)
					if _type == "thread" then
						if v ~= self then
							pcall(coroutine.close, v)
						end
					elseif _type == "function" then
						if
							(not islclosure or islclosure(v)) and (not isexecutorclosure or not isexecutorclosure(v))
						then
							if hookfunction then
								pcall(hookfunction, v, coroutine.yield)
							end
						end
					end
				end
			end

			filterNkill(debug and debug.getregistry or getreg or getregistry)
			filterNkill(getallthreads)
			filterNkill(getgc)
		end
	end

	if IsolateStarterPlayer then
		IgnoreList.StarterPlayer = false
	end

	if IsolatePlayers then
		IgnoreList.Players = false
	end

	if OPTIONS.ShowStatus then
		do
			local Exists = GLOBAL_ENV.XSAVE_STATUS
			if Exists then
				Exists:Destroy()
			end
		end

		local StatusGui = Instance.new("ScreenGui")

		GLOBAL_ENV.XSAVE_STATUS = StatusGui

		StatusGui.DisplayOrder = 2e9
		pcall(function() -- ? Compatibility with level 2
			StatusGui.OnTopOfCoreBlur = true
		end)

		StatusText = Instance.new("TextLabel")

		StatusText.Text = "Saving..."

		StatusText.BackgroundTransparency = 1
		StatusText.Font = Enum.Font.Code
		StatusText.AnchorPoint = Vector2.new(1)
		StatusText.Position = UDim2.new(1)
		StatusText.Size = UDim2.new(0.3, 0, 0, 20)

		StatusText.TextColor3 = Color3.new(1, 1, 1)
		StatusText.TextScaled = true
		StatusText.TextStrokeTransparency = 0.7
		StatusText.TextXAlignment = Enum.TextXAlignment.Right
		StatusText.TextYAlignment = Enum.TextYAlignment.Top

		StatusText.Parent = StatusGui
		Control.StatusText = StatusText

		local function randomString()
			local length = math.random(10, 20)
			local randomarray = table.create(length)
			for i = 1, length do
				randomarray[i] = string.char(math.random(32, 126))
			end
			return table.concat(randomarray)
		end

		if global_container.gethui then
			StatusGui.Name = randomString()
			StatusGui.Parent = global_container.gethui()
		else
			if global_container.protectgui then
				StatusGui.Name = randomString()
				global_container.protectgui(StatusGui)
				StatusGui.Parent = game:GetService("CoreGui")
			else
				local RobloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
				if RobloxGui then
					StatusGui.Parent = RobloxGui
				else
					StatusGui.Name = randomString()
					StatusGui.Parent = game:GetService("CoreGui")
				end
			end
		end
	end

	do
		if OPTIONS.SafeMode then
			task.spawn(function()
				local LocalPlayer = GetLocalPlayer()

				local PlayerScripts = LocalPlayer:FindFirstChildOfClass("PlayerScripts")
				if PlayerScripts then
					local function construct_InstanceOverride(instance)
						local children = instance:GetChildren()
						InstancesOverrides[instance] = {
							__Children = children,
						}
						for _, child in children do
							construct_InstanceOverride(child)
						end
					end
					construct_InstanceOverride(PlayerScripts)

					InstancesOverrides[LocalPlayer] = {
						__Children = LocalPlayer:GetChildren(),
						Properties = { Name = "[" .. LocalPlayer.ClassName .. "] " .. LocalPlayer.Name },
					}
				end
				local msg =
					"[SAVEINSTANCE SAFEMODE]\nSaving..\nDo NOT leave\nLVL7 Executor RECOMMENDED for more SAFETY\nTo Disable this: SafeMode=false (Less Protection)"
				local function Kick()
					LocalPlayer:Kick(msg)
				end

				Kick()
				pcall(function()
					Connect(service.GuiService.ErrorMessageChanged, function()
						if service.GuiService:GetErrorMessage() ~= msg then
							Kick()
						end
					end)
				end)
				wait_for_render()
				-- task.wait(5)
				-- task.delay(10, service.GuiService.ClearError, service.GuiService)
			end)

			if CustomOptions_valid["BoostFPS"] == nil then
				OPTIONS.BoostFPS = true
			end
		end

		if OPTIONS.BoostFPS then
			pcall(function()
				service.RunService:Set3dRenderingEnabled(false)
			end)
		end

		if OPTIONS.AntiIdle then
			local Idled = GetLocalPlayer().Idled
			Connect(Idled, function()
				service.VirtualInputManager:SendMouseWheelEvent(
					service.UserInputService:GetMouseLocation().X,
					service.UserInputService:GetMouseLocation().Y,
					true,
					game
				)
			end)
		end

		if not ClassList then -- means first run
			do -- * Load Region of Déjà Vu
				local UGCValidationService -- = service.UGCValidationService

				gethiddenproperty_fallback = function(instance, propertyName)
					if not UGCValidationService then
						UGCValidationService = service.UGCValidationService
					end
					return UGCValidationService:GetPropertyValue(instance, propertyName) -- TODO Sadly there's no way to tell whether value is actually nil or the function just couldn't read it (always returns nil for "Class" category properties)
					-- TODO `category ~= "Class"` causes WeldConstraint Part1Internal to be read as nil and not get unfiltered. Currently, there are no properties of category "Class" that match the following: NotScriptable, can be read with gethiddenproperty_fallback accurately (it always outputs nil for "Class" category, making that check useless anyway) & don't have a NotScriptableFix.
				end
				if gethiddenproperty then
					local o, r = pcall(gethiddenproperty, workspace, "StreamOutBehavior")
					if not o or r ~= nil and typeof(r) ~= "EnumItem" then -- * Tests if gethiddenproperty is broken
						gethiddenproperty = nil
					else
						o, r =
							pcall(gethiddenproperty, Instance.new("AnimationRigData", Instance.new("Folder")), "parent") -- * Tests how it reacts to property overlap (shadowing) due to AnimationRigData.parent; expected BinaryString

						if o and r ~= nil and type(r) ~= "string" then
							gethiddenproperty = nil
						end
					end
				end
				local function benchmark(funcs, ...)
					local ranking = table.create(2)
					for i, f in funcs do
						local start = os.clock()
						for _ = 1, 50 do
							f(...)
						end
						ranking[i] = { t = os.clock() - start, f = f }
					end
					table.sort(ranking, function(a, b)
						return a.t < b.t
					end)
					return ranking[1].f
				end

				local test_str = string.rep("\1\0\0\0\1\2\3\4\5\6\7", 50)

				do
					if
						not bit32.byteswap
						or not (function()
							local o, r = pcall(bit32.byteswap, 2712847316)
							if not o then
								return -- It might be disabled on some builds
							end
							return r == 3569595041
						end)()
					then -- Because Fluxus is missing byteswap
						-- https://github.com/luau-lang/rfcs/blob/master/docs/function-bit32-byteswap.md
						local b32 = table.clone(bit32)

						b32.byteswap = function(n)
							return bit32.bor(
								bit32.lshift(n, 24),
								bit32.band(bit32.lshift(n, 8), 0xFF0000),
								bit32.band(bit32.rshift(n, 8), 0xFF00),
								bit32.rshift(n, 24)
							)
						end
						if table.isfrozen(bit32) then
							b32 = table.freeze(b32)
						end
						GLOBAL_ENV.bit32 = b32
					end

					-- Credits @daily3014 & @XoifaiI
					local rbxcrypt_base64encode
					pcall(function()
						local b64_enc_buf = loadstring(
							game:HttpGet(
								"https://raw.githubusercontent.com/daily3014/rbx-cryptography/refs/heads/main/src/Utilities/Base64.luau",
								true
							),
							"Base64"
						)().Encode
						rbxcrypt_base64encode = function(raw)
							return buffer.tostring(b64_enc_buf(buffer.fromstring(raw)))
						end
					end)

					local EncodingService = game:GetService("EncodingService")
					local EncodingService_base64encode = function(raw)
						return buffer.tostring(EncodingService:Base64Encode(buffer.fromstring(raw)))
					end

					-- * Tests if base64encode exists and works properly then benchmark it
					if base64encode and base64encode("\1\0\0\0\1") == "AQAAAAE=" then
						if rbxcrypt_base64encode then
							base64encode = benchmark(
								{ base64encode, rbxcrypt_base64encode, EncodingService_base64encode },
								test_str
							)
						end
					else
						base64encode = rbxcrypt_base64encode
					end

					if not base64encode then
						warn("base64encode not found")
						Cleanup()
						return
					end
				end
			end
			do
				local ok, result = pcall(FetchAPI)
				if ok then
					ClassList = result
				else
					warn("Failed to load the API Dump")
					warn(result)
					Cleanup()
					return
				end
			end
		end

		elapse_t = os.clock()

		local ok, err = xpcall(save_game, function(err)
			return debug.traceback(err)
		end)
		Control.Succeeded = ok
		Control.Error = err

		if OPTIONS.BoostFPS then
			pcall(function()
				local max = 5
				task.delay(
					math.clamp(max - (os.clock() - elapse_t), 0, max),
					service.GuiService.ClearError,
					service.GuiService
				)
				service.RunService:Set3dRenderingEnabled(true)
			end)
		end

		if old_gethiddenproperty then
			gethiddenproperty = old_gethiddenproperty
		end

		Cleanup()

		elapse_t = os.clock() - elapse_t
		local Log10 = math.log10(elapse_t)
		local ExtraTime = 10

		if StatusText then
			task.spawn(function()
				if ok then
					StatusText.Text = string.format("Saved! Time %.3f seconds; Size %s", elapse_t, get_size_format())
					StatusText.TextColor3 = Color3.new(0, 1)
					task.wait(Log10 * 2 + ExtraTime)
				else
					if Loading then
						task.cancel(Loading)
						Loading = nil
					end
					StatusText.Text = "Failed! Check F9 console for more info"
					StatusText.TextColor3 = Color3.new(1)
					warn("Error found while saving:")
					warn(err)
					task.wait(Log10 + ExtraTime)
				end
				StatusText:Destroy()
			end)
		end

		if OPTIONS.ShutdownWhenDone and ok then
			task.wait(Log10 * 2 + ExtraTime)
			game:Shutdown()
		end
	end
end

local Storage = { dir = "xsave" }

function Storage.read(name)
	if not (isfile and readfile) then
		return nil
	end
	local ok, data = pcall(function()
		local path = Storage.dir .. "/" .. name
		if isfile(path) then
			return service.HttpService:JSONDecode(readfile(path))
		end
	end)
	return ok and data or nil
end

function Storage.write(name, value)
	if not writefile then
		return false
	end
	return (pcall(function()
		if makefolder and isfolder and not isfolder(Storage.dir) then
			makefolder(Storage.dir)
		end
		writefile(Storage.dir .. "/" .. name, service.HttpService:JSONEncode(value))
	end))
end

local Format = {}

function Format.int(n)
	local reversed = string.gsub(string.reverse(tostring(math.floor(n + 0.5))), "(%d%d%d)", "%1,")
	reversed = string.reverse(reversed)
	if string.sub(reversed, 1, 1) == "," then
		reversed = string.sub(reversed, 2)
	end
	return reversed
end

function Format.time(seconds)
	if seconds ~= seconds or seconds == math.huge then
		return "-"
	end
	local total = math.floor(math.max(0, seconds) + 0.5)
	if seconds < 1 then
		return "< 1 s"
	elseif total < 60 then
		return string.format("%d s", total)
	elseif total < 3600 then
		return string.format("%d min %02d s", total // 60, total % 60)
	end
	return string.format("%d h %02d min", total // 3600, (total % 3600) // 60)
end

function Format.bytes(n)
	local units = { "B", "KB", "MB", "GB" }
	local i = 1
	while n >= 1024 and i < #units do
		n /= 1024
		i += 1
	end
	if i == 1 then
		return string.format("%d B", n)
	end
	return string.format("%.1f %s", n, units[i])
end

local OPTIMIZED_SERVICES = {
	"Workspace", "Players", "Lighting", "MaterialService", "ReplicatedFirst", "ReplicatedStorage",
	"ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Teams",
	"SoundService", "Chat", "TextChatService", "LocalizationService", "JointsService",
}

local DEFAULT_RATES = { perInstance = 0.0006, perDecompile = 0.15, bytesPerInstance = 700, bytesPerScript = 2500 }

local Estimator = {}

function Estimator.load()
	if not Estimator.entries then
		local data = Storage.read("history.json")
		Estimator.entries = type(data) == "table" and data or {}
	end
	return Estimator.entries
end

function Estimator.record(entry)
	local entries = Estimator.load()
	table.insert(entries, entry)
	while #entries > 12 do
		table.remove(entries, 1)
	end
	Storage.write("history.json", entries)
end

function Estimator.rates(opts)
	local entries = Estimator.load()
	local pool = {}
	for _, entry in entries do
		if
			entry.mode == opts.Mode
			and entry.decompile == (opts.Decompile and true or false)
			and entry.ignoreDefaults == (opts.IgnoreDefaultProperties and true or false)
		then
			table.insert(pool, entry)
		end
	end
	local matched = #pool > 0
	if not matched then
		pool = entries
	end

	local rates = table.clone(DEFAULT_RATES)
	rates.samples = #pool
	rates.matched = matched

	local instances, seconds, decompileSeconds, decompiled, bytes = 0, 0, 0, 0, 0
	for _, entry in pool do
		instances += entry.instances or 0
		seconds += entry.seconds or 0
		decompileSeconds += entry.decompileSeconds or 0
		decompiled += entry.decompiled or 0
		bytes += entry.bytes or 0
	end
	if instances > 0 then
		rates.perInstance = math.max((seconds - decompileSeconds) / instances, 1e-5)
		rates.bytesPerInstance = math.max(bytes / instances, 50)
		rates.fromHistory = true
	end
	if decompiled > 0 then
		rates.perDecompile = decompileSeconds / decompiled
	end
	return rates
end

function Estimator.scope(scan, opts)
	local instances, scripts = 0, 0
	if opts.Mode == "optimized" then
		for _, name in OPTIMIZED_SERVICES do
			local stats = scan.roots[name]
			if stats then
				instances += stats.instances
				scripts += stats.scripts
			end
		end
	else
		for _, stats in scan.roots do
			instances += stats.instances
			scripts += stats.scripts
		end
	end
	if opts.NilInstances and scan.nilCount then
		instances += scan.nilCount
	end
	if opts.Mode == "scripts" then
		instances = scripts
	end
	return instances, scripts
end

function Estimator.compute(scan, opts)
	local instances, scripts = Estimator.scope(scan, opts)
	local rates = Estimator.rates(opts)
	local decompileCount = opts.Decompile and scripts or 0
	local timeout = tonumber(opts.DecompileTimeout) or 10

	local serialize = instances * rates.perInstance
	local decompile = decompileCount * rates.perDecompile
	local worst
	if opts.Decompile and timeout >= 0 then
		worst = serialize + decompileCount * timeout
	end

	local bytes
	if rates.fromHistory then
		bytes = instances * rates.bytesPerInstance
	else
		bytes = instances * rates.bytesPerInstance * (opts.IgnoreDefaultProperties and 1 or 2.5)
		bytes += decompileCount * rates.bytesPerScript
		if opts.SaveBytecode then
			bytes += scripts * 3000
		end
	end

	return {
		instances = instances,
		scripts = scripts,
		decompileCount = decompileCount,
		serialize = serialize,
		decompile = decompile,
		total = serialize + decompile,
		worst = worst,
		bytes = bytes,
		rates = rates,
	}
end

local Scanner = {}

-- Hidden Roblox UI; never part of a place file, so it is excluded from the estimate
local SCAN_SKIP = { CoreGui = true, CorePackages = true }

function Scanner.run(opts, onProgress, isCancelled)
	local result = {
		roots = {},
		classes = {},
		total = 0,
		scripts = 0,
		done = false,
		seconds = 0,
		opts = { IgnoreNotArchivable = opts.IgnoreNotArchivable, SavePlayerCharacters = opts.SavePlayerCharacters },
	}
	local startedAt = os.clock()
	local Players = game:GetService("Players")
	local ok, roots = pcall(game.GetChildren, game)
	if not ok then
		roots = {}
	end

	local visited = 0
	for _, root in roots do
		if SCAN_SKIP[root.ClassName] then
			continue
		end

		local stats = { instances = 0, scripts = 0 }
		result.roots[root.ClassName] = stats

		local pending = { root }
		while #pending > 0 do
			local inst = table.remove(pending)
			local skip = false

			if opts.IgnoreNotArchivable and inst ~= root then
				local readable, archivable = pcall(index, inst, "Archivable")
				if readable and archivable == false then
					skip = true
				end
			end
			if
				not skip
				and not opts.SavePlayerCharacters
				and inst.ClassName == "Model"
				and Players:GetPlayerFromCharacter(inst)
			then
				skip = true
			end

			if not skip then
				local className = inst.ClassName
				stats.instances += 1
				result.total += 1
				result.classes[className] = (result.classes[className] or 0) + 1
				if inst:IsA("LuaSourceContainer") then
					stats.scripts += 1
					result.scripts += 1
				end
				local got, kids = pcall(inst.GetChildren, inst)
				if got then
					for _, kid in kids do
						table.insert(pending, kid)
					end
				end
			end

			visited += 1
			if visited % 5000 == 0 then
				if isCancelled() then
					return result
				end
				result.seconds = os.clock() - startedAt
				onProgress(result)
				task.wait()
			end
		end
	end

	if global_container.getnilinstances then
		local got, nilInstances = pcall(global_container.getnilinstances)
		if got and type(nilInstances) == "table" then
			result.nilCount = #nilInstances
		end
	end

	result.seconds = os.clock() - startedAt
	result.done = true
	return result
end

local function getCapabilities()
	return {
		decompile = decompile ~= nil,
		getscriptbytecode = global_container.getscriptbytecode ~= nil,
		getnilinstances = global_container.getnilinstances ~= nil,
		gethiddenproperty = global_container.gethiddenproperty ~= nil,
		writefile = writefile ~= nil,
	}
end

local function getGameInfo()
	local Players = game:GetService("Players")
	local info = {
		name = game.PlaceId == 0 and "Local place" or ("Place " .. game.PlaceId),
		placeId = game.PlaceId,
		universeId = game.GameId,
		creator = "",
		players = #Players:GetPlayers(),
		maxPlayers = Players.MaxPlayers,
	}
	pcall(function()
		local product = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		if product.Name and product.Name ~= "" then
			info.name = product.Name
		end
		if product.Creator and product.Creator.Name then
			info.creator = product.Creator.Name
		end
	end)
	return info
end

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

local function xsave_run(CustomOptions, CustomOptions2)
	if Control.Running then
		warn("[xsave] Already running")
		return
	end

	Control.Running = true
	Control.Stop = false
	Control.Kill = false
	Control.Processed = 0
	Control.Size = 0
	Control.Decompiled = 0
	Control.DecompileTime = 0
	Control.Succeeded = nil
	Control.Error = nil
	Control.FileName = nil
	Control.Options = nil
	Control.StatusText = nil
	Control.FinishedAt = nil
	Control.StartedAt = os.clock()

	local ok, err = pcall(run_save, CustomOptions, CustomOptions2)

	Control.FinishedAt = os.clock()
	Control.Running = false

	if not ok then
		Control.Succeeded = false
		Control.Error = tostring(err)
		-- Release locks so a failed run never blocks the next one
		GLOBAL_ENV.XSAVE_RUNNING = nil
		if Control.LockedPlace then
			GLOBAL_ENV[Control.LockedPlace] = nil
			Control.LockedPlace = nil
		end
		warn("[xsave] Failed: " .. tostring(err))
		return
	end

	local used = Control.Options
	if
		Control.Succeeded
		and not Control.Stop
		and used
		and Control.Processed > 0
		and (used.mode == "optimized" or used.mode == "full" or used.mode == "scripts")
	then
		Estimator.record({
			t = os.time(),
			place = game.PlaceId,
			mode = used.mode,
			decompile = used.Decompile and true or false,
			ignoreDefaults = used.IgnoreDefaultProperties and true or false,
			bytecode = used.SaveBytecode and true or false,
			instances = Control.Processed,
			seconds = Control.FinishedAt - Control.StartedAt,
			decompileSeconds = Control.DecompileTime,
			decompiled = Control.Decompiled,
			bytes = Control.Size,
		})
	end
end

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

local xsave = setmetatable({
	Version = "1.1.0",
	Run = xsave_run,
	Gui = xsave_gui,
	Control = Control,
	Stop = function()
		if Control.Running then
			Control.Stop = true
		end
	end,
	Kill = function()
		if Control.Running then
			Control.Kill = true
		end
	end,
	Reset = function()
		Control.Running, Control.Stop, Control.Kill = false, false, false
		GLOBAL_ENV.XSAVE_RUNNING = nil
		if Control.LockedPlace then
			GLOBAL_ENV[Control.LockedPlace] = nil
			Control.LockedPlace = nil
		end
	end,
}, {
	__call = function(_, options, options2)
		if options == nil then
			return xsave_gui()
		end
		return xsave_run(options, options2)
	end,
})

return xsave
