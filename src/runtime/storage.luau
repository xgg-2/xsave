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

