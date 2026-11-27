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

