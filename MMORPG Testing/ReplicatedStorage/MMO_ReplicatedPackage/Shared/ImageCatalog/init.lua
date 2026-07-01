--[[
Name: ImageCatalog
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Shared.ImageCatalog
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ContentProvider
Functions: toId, toContentId, M.Resolve, M.SetImage
Clean source lines: 77
]]
local ContentProvider = game:GetService("ContentProvider")

local M = {}


M.Catalog = {
	Default = 79376032079624,
}


local _lower = {}
for k,v in pairs(M.Catalog) do _lower[string.lower(k)] = v end


local function toId(input)
	if input == nil then return nil end
	local t = typeof(input)

	if t == "number" then
		return (input > 0) and input or nil
	end

	if t == "string" then
		local raw = input:match("^rbxassetid://(%d+)$") or input:match("^(%d+)$")
		if raw then
			local n = tonumber(raw)
			return (n and n > 0) and n or nil
		end
		local id = _lower[string.lower(input)]
		return (id and id > 0) and id or nil
	end

	return nil
end

local function toContentId(id)
	return "rbxassetid://" .. tostring(id)
end


function M.Resolve(input)
	local id = toId(input) or M.Catalog.Default
	return toContentId(id)
end


local _token = 0


function M.SetImage(instance: Instance, input)
	local content = M.Resolve(input)
	_token += 1
	local myToken = _token

	instance:SetAttribute("ImageCatalogToken", myToken)
	instance.Image = content


	task.spawn(function()
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ instance })
		end)


		if not ok and instance:GetAttribute("ImageCatalogToken") == myToken then
			instance.Image = toContentId(M.Catalog.Default)
			pcall(function()
				ContentProvider:PreloadAsync({ instance })
			end)
		end
	end)

	return instance.Image
end

return M
