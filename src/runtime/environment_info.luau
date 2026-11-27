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

