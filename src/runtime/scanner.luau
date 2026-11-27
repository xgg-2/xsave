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

