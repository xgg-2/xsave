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

