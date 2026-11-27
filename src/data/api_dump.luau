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

