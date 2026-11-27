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

