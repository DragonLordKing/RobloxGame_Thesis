--[[
Name: ItemDetailController
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Controllers.ItemDetailController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, UserInputService, TweenService, ReplicatedStorage
Requires:
  - local ImageCatalog = require(sharedFolder:WaitForChild("ImageCatalog"))
  - local GameState = require(utilFolder:WaitForChild("GameState"))
Functions: comma, findDesc, ensureCloseButton, ensureTypeLabel, ensureSectionList, clearSection, addRow, setSection, flattenAbilities, flattenRecipe, pct, normalizePurity, qualityEffect, formatWeight, getOrCreatePurityLabel, disconnectGlowSync, stopTweens, syncGlowShell, ensureGlowShell, getAllStrokes, cacheStrokeDefault, cacheDefaults, clearStrokeGradients, makeBWRadialGradient, removeMysticGlow, applyDefaultStrokes, applyLegendary, applyArtifact, applyMysticGlow, applyQuality, resetSection, setStatsSection, setInfoSection, abilityGridFromData, gridHasContent, ensureAbilitiesGrid, makeRow, abilityRowsRoot, getAbilityRow, abilitySelectionStore, abilityItemKey, selectedAbilityIndex, rememberAbilitySelection, clearAbilityButtons, themeButtonStroke, selectAbilityButton, abilityMetaField, statText, itemPowerDamageScale, effectiveDamageText, ensureAbilityTooltip, positionAbilityTooltip, showAbilityTooltip, hideAbilityTooltip, currentAbilityMeta, wireAbilityClick, fillAbilityButtons, setAbilityLeftIcon, orderForType, populateAbilitiesGrid
Clean source lines: 1632
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local replicatedPackage = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
local sharedFolder = replicatedPackage:WaitForChild("Shared")
local utilFolder = replicatedPackage:WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util")

local ImageCatalog = require(sharedFolder:WaitForChild("ImageCatalog"))
local GameState = require(utilFolder:WaitForChild("GameState"))
local AbilitySelectionUpdate = replicatedPackage:WaitForChild("RemoteEvents"):WaitForChild("AbilitySelectionUpdate")

local Controller = {}
local started = false

local THEME_TEXT = Color3.fromRGB(242, 228, 198)
local THEME_SUBTLE = Color3.fromRGB(210, 196, 166)
local THEME_PANEL = Color3.fromRGB(38, 26, 22)
local THEME_GOLD = Color3.fromRGB(232, 176, 64)

local function comma(n)
	n = tostring(math.floor(tonumber(n) or 0))
	local left, num, right = n:match("^([^%d]*%d)(%d*)(.-)$")
	if not num then return n end
	return left .. num:reverse():gsub("(%d%d%d)", "%1,"):reverse() .. right
end

local function findDesc(root, name)
	return root and root:FindFirstChild(name, true) or nil
end

local function ensureCloseButton(card)
	local close = card:FindFirstChild("CloseX")
	if close and close:IsA("GuiButton") then
		return close
	end
	close = Instance.new("TextButton")
	close.Name = "CloseX"
	close.Text = "X"
	close.Font = Enum.Font.GothamBold
	close.TextScaled = true
	close.TextColor3 = THEME_TEXT
	close.BackgroundColor3 = Color3.fromRGB(26, 18, 16)
	close.BackgroundTransparency = 0.05
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(0.985, 0, 0.02, 0)
	close.Size = UDim2.new(0.045, 0, 0.065, 0)
	close.ZIndex = 50
	close.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = close
	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME_GOLD
	stroke.Transparency = 0.15
	stroke.Thickness = 1
	stroke.Parent = close
	return close
end

local function ensureTypeLabel(slotBox)
	local label = slotBox:FindFirstChild("TypeLabel")
	if label then return label end
	label = Instance.new("TextLabel")
	label.Name = "TypeLabel"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.TextColor3 = THEME_TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0.04, 0, 0.58, 0)
	label.Size = UDim2.new(0.92, 0, 0.28, 0)
	label.Parent = slotBox
	local value = slotBox:FindFirstChild("ValueLabel")
	if value then
		value.Position = UDim2.new(0.04, 0, 0.84, 0)
		value.Size = UDim2.new(0.92, 0, 0.26, 0)
	end
	return label
end

local function ensureSectionList(section)
	local list = section:FindFirstChild("List")
	if list and list:IsA("ScrollingFrame") then
		return list
	end
	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.AnchorPoint = Vector2.new(0.5, 0)
	list.Position = UDim2.new(0.5, 0, 0.22, 0)
	list.Size = UDim2.new(0.96, 0, 0.74, 0)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = section
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

local function clearSection(section)
	if not section then return end
	local list = ensureSectionList(section)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addRow(section, text, order)
	local list = ensureSectionList(section)
	local row = Instance.new("TextLabel")
	row.Name = "Row"
	row.BackgroundColor3 = THEME_PANEL
	row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0
	row.Font = Enum.Font.Gotham
	row.TextScaled = true
	row.TextWrapped = true
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = THEME_TEXT
	row.Text = tostring(text)
	row.Size = UDim2.new(1, 0, 0, 28)
	row.LayoutOrder = order or 1
	row.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = row
	return row
end

local function setSection(section, rows)
	clearSection(section)
	local hasRows = type(rows) == "table" and #rows > 0
	section.Visible = hasRows
	if not hasRows then
		return
	end
	section.Size = UDim2.new(1, 0, 0, math.clamp(58 + (#rows * 34), 120, 260))
	for index, text in ipairs(rows) do
		addRow(section, text, index)
	end
end

local function flattenAbilities(data)
	local rows = {}
	for _, value in ipairs(data.abilities or {}) do
		table.insert(rows, tostring(value))
	end
	local grid = data.abilitiesGrid or data.abilityRows
	if type(grid) == "table" then
		for key, list in pairs(grid) do
			if type(list) == "table" then
				for _, ability in ipairs(list) do
					if type(ability) == "table" then
						table.insert(rows, string.format("%s: %s", tostring(key), tostring(ability.name or ability.Name or ability.id or ability.icon or "Ability")))
					elseif ability ~= nil then
						table.insert(rows, string.format("%s: %s", tostring(key), tostring(ability)))
					end
				end
			end
		end
	end
	return rows
end

local function flattenRecipe(data)
	local rows = {}
	for _, value in ipairs(data.recipe or {}) do
		table.insert(rows, tostring(value))
	end
	for _, value in ipairs(data.recipeGrid or {}) do
		if type(value) == "table" then
			table.insert(rows, tostring(value.name or value.label or value.Id or value.id or "Ingredient"))
		else
			table.insert(rows, tostring(value))
		end
	end
	return rows
end

function Controller.Start(gui)
	if started then return end
	started = true
	gui = gui or script.Parent

	local player = Players.LocalPlayer
	local card = gui:WaitForChild("ItemCard")
	local backdrop = gui:FindFirstChild("Backdrop")
	local header = card:WaitForChild("Header")
	local body = card:WaitForChild("Body")
	local left = body:WaitForChild("LeftCol")
	local right = body:WaitForChild("RightCol")
	local headerRow = header:FindFirstChild("HeaderRow") or header
	card.Active = true
	body.Active = true
	left.Active = true
	right.Active = true
	if backdrop then backdrop.Active = true end

	local previewWrap = left:FindFirstChild("PreviewWrap") or card:FindFirstChild("PreviewWrap")
	local preview = previewWrap and previewWrap:FindFirstChild("ItemImage")
	local amountBadge = card:WaitForChild("AmountBadge")
	local close = ensureCloseButton(card)
	local quality = findDesc(headerRow, "QualityLabel") or findDesc(header, "QualityLabel")
	local enhancementWrap = headerRow:FindFirstChild("EnhancementWrap") or findDesc(header, "EnhancementWrap")
	local purityIcon = findDesc(enhancementWrap or headerRow, "PurityIcon") or findDesc(enhancementWrap or headerRow, "EnhIcon")
	local purityLabel = findDesc(enhancementWrap or headerRow, "PurityLabel") or findDesc(enhancementWrap or headerRow, "EnhLabel")
	local subHeader = card:WaitForChild("SubHeader")
	local weightLabel = subHeader:WaitForChild("WeightLabel")
	local byLabel = subHeader:WaitForChild("ByLabel")
	local namePower = left:WaitForChild("NamePower")
	local descText = left:WaitForChild("DescriptionBox"):WaitForChild("DescriptionScroll"):WaitForChild("DescriptionText")
	local slotBox = left:WaitForChild("SlotValueBox")
	local slotLabel = slotBox:WaitForChild("SlotLabel")
	local valueLabel = slotBox:WaitForChild("ValueLabel")
	local typeLabel = ensureTypeLabel(slotBox)
	local sectionScroll = right:WaitForChild("RightSections"):WaitForChild("SectionScroll")
	local statsSection = sectionScroll:WaitForChild("StatsSection")
	local infoSection = sectionScroll:FindFirstChild("InfoSection")
	if not infoSection then
		infoSection = Instance.new("Frame")
		infoSection.Name = "InfoSection"
		infoSection.BackgroundTransparency = 1
		infoSection.BorderSizePixel = 0
		infoSection.Size = UDim2.new(1, 0, 0, 136)
		infoSection.LayoutOrder = (statsSection.LayoutOrder or 1) - 1
		infoSection.Parent = sectionScroll
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.Text = "Info"
		title.TextColor3 = THEME_GOLD
		title.TextScaled = true
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Position = UDim2.new(0.03, 0, 0.02, 0)
		title.Size = UDim2.new(0.94, 0, 0.18, 0)
		title.Parent = infoSection
	end
	local abilitiesSection = sectionScroll:WaitForChild("AbilitiesSection")
	local recipeSection = sectionScroll:WaitForChild("RecipeSection")

	local activeQualityName = "Normal"
	local activePurityKey = "none"
	local activeTweens = {}
	local glowShell = nil
	local glowSyncConnections = {}
	local recipePayloads = {}
	local abilityPayloads = {}
	local leftAbilityPayloads = {}
	local currentReadOnlyAbilities = false
	local defaultStrokeColors = {}
	local dragging = false
	local dragStart
	local startPos

	local PURITY_ICON_IDS = {
		none = "rbxassetid://137415659844654",
		low = "rbxassetid://105168599680477",
		medium = "rbxassetid://82494760530644",
		high = "rbxassetid://96989742370274",
		mystical = "rbxassetid://119770189908223",
	}

	local ORDERS = {
		Weapon = { "Q", "W", "E", "Passive" },
		Helmet = { "Passive", "D" },
		Armor = { "R", "Passive", "Passive2" },
		Boots = { "F", "Passive" },
		Mount = { "F", "Passive" },
		Cape = { "Passive" },
		Bag = { "Passive" },
		Utility = { "Passive" },
	}

	local function pct(n)
		return math.floor((tonumber(n) or 0) + 0.5)
	end

	local function normalizePurity(purity)
		local value = tostring(purity or "None"):lower()
		if value:find("ashen") or value:find("myst") or value:find("trans") then return "mystical" end
		if value:find("ignited") or value:find("radiant") or value:find("high") then return "high" end
		if value:find("kindled") or value:find("pure") or value:find("med") then return "medium" end
		if value:find("faint") or value:find("glow") or value:find("low") then return "low" end
		return "none"
	end

	local function qualityEffect(qualityName)
		local value = tostring(qualityName or "Normal"):lower()
		if value == "artifact" or value == "masterpiece" then return "artifact" end
		if value == "legendary" then return "legendary" end
		return "default"
	end

	local function formatWeight(weight)
		weight = tonumber(weight) or 0
		if math.abs(weight - math.floor(weight)) < 0.01 then
			return comma(weight)
		end
		return string.format("%.2f", weight)
	end

	local function getOrCreatePurityLabel()
		if purityLabel and purityLabel.Parent then return purityLabel end
		local parent = enhancementWrap or headerRow
		purityLabel = parent:FindFirstChild("PurityLabel") or parent:FindFirstChild("EnhLabel")
		if purityLabel then return purityLabel end
		purityLabel = Instance.new("TextLabel")
		purityLabel.Name = "PurityLabel"
		purityLabel.BackgroundTransparency = 1
		purityLabel.Font = Enum.Font.Gotham
		purityLabel.TextScaled = true
		purityLabel.TextColor3 = THEME_SUBTLE
		purityLabel.TextXAlignment = Enum.TextXAlignment.Left
		purityLabel.AnchorPoint = Vector2.new(0, 0.5)
		purityLabel.Position = UDim2.new(0, 0, 0.5, 0)
		purityLabel.Size = UDim2.new(0.66, 0, 1, 0)
		purityLabel.Parent = parent
		return purityLabel
	end

	local function disconnectGlowSync()
		for _, connection in ipairs(glowSyncConnections) do
			pcall(function() connection:Disconnect() end)
		end
		glowSyncConnections = {}
	end

	local function stopTweens()
		for _, tween in ipairs(activeTweens) do
			pcall(function() tween:Cancel() end)
		end
		activeTweens = {}
	end

	local function syncGlowShell()
		if not glowShell then return end
		glowShell.AnchorPoint = card.AnchorPoint
		glowShell.Position = card.Position
		glowShell.Size = card.Size
		glowShell.Rotation = card.Rotation
		glowShell.Visible = card.Visible
		glowShell.ZIndex = math.max((card.ZIndex or 10) - 1, (backdrop and backdrop.ZIndex or 0) + 1)
		local cardCorner = card:FindFirstChildOfClass("UICorner")
		local shellCorner = glowShell:FindFirstChildOfClass("UICorner")
		if cardCorner and shellCorner then
			shellCorner.CornerRadius = cardCorner.CornerRadius
		end
	end

	local function ensureGlowShell()
		if glowShell and glowShell.Parent then return glowShell end
		glowShell = Instance.new("Frame")
		glowShell.Name = "MysticGlowShell"
		glowShell.BackgroundTransparency = 1
		glowShell.BorderSizePixel = 0
		glowShell.Parent = gui
		Instance.new("UICorner", glowShell)
		syncGlowShell()
		table.insert(glowSyncConnections, card:GetPropertyChangedSignal("Position"):Connect(syncGlowShell))
		table.insert(glowSyncConnections, card:GetPropertyChangedSignal("Size"):Connect(syncGlowShell))
		table.insert(glowSyncConnections, card:GetPropertyChangedSignal("Rotation"):Connect(syncGlowShell))
		table.insert(glowSyncConnections, card:GetPropertyChangedSignal("AnchorPoint"):Connect(syncGlowShell))
		table.insert(glowSyncConnections, card:GetPropertyChangedSignal("Visible"):Connect(syncGlowShell))
		return glowShell
	end

	local function getAllStrokes()
		local strokes = {}
		for _, descendant in ipairs(card:GetDescendants()) do
			if descendant:IsA("UIStroke") then
				table.insert(strokes, descendant)
			end
		end
		return strokes
	end

	local function cacheStrokeDefault(strokeObject)
		if strokeObject and not defaultStrokeColors[strokeObject] then
			defaultStrokeColors[strokeObject] = strokeObject.Color
		end
	end

	local function cacheDefaults()
		for _, strokeObject in ipairs(getAllStrokes()) do
			cacheStrokeDefault(strokeObject)
		end
	end

	local function clearStrokeGradients()
		for _, strokeObject in ipairs(getAllStrokes()) do
			local gradient = strokeObject:FindFirstChild("FXGradient")
			if gradient then gradient:Destroy() end
		end
	end

	local DARK_RED = Color3.fromRGB(128, 16, 16)
	local BLUE = Color3.fromRGB(60, 150, 255)

	local function makeBWRadialGradient(whiteWidth)
		whiteWidth = math.clamp(tonumber(whiteWidth) or 0.52, 0.3, 0.7)
		local half = whiteWidth * 0.5
		local leftEdge = 0.5 - half
		local rightEdge = 0.5 + half
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
			ColorSequenceKeypoint.new(leftEdge, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(rightEdge, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
		})
	end

	local function removeMysticGlow()
		local strokeObject = glowShell and glowShell:FindFirstChild("MysticGlowStroke")
		if strokeObject then strokeObject:Destroy() end
		disconnectGlowSync()
		if glowShell then glowShell:Destroy() end
		glowShell = nil
	end

	local function applyDefaultStrokes()
		stopTweens()
		clearStrokeGradients()
		for _, strokeObject in ipairs(getAllStrokes()) do
			local defaultColor = defaultStrokeColors[strokeObject]
			if defaultColor then strokeObject.Color = defaultColor end
		end
	end

	local function applyLegendary()
		stopTweens()
		clearStrokeGradients()
		for _, strokeObject in ipairs(getAllStrokes()) do
			strokeObject.Color = DARK_RED
		end
	end

	local function applyArtifact()
		stopTweens()
		clearStrokeGradients()
		for _, strokeObject in ipairs(getAllStrokes()) do
			strokeObject.Color = Color3.new(1, 1, 1)
			local gradient = Instance.new("UIGradient")
			gradient.Name = "FXGradient"
			gradient.Color = makeBWRadialGradient(0.52)
			gradient.Rotation = 0
			gradient.Parent = strokeObject
			local spin = TweenService:Create(gradient, TweenInfo.new(16, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0), { Rotation = 359.9 })
			spin:Play()
			gradient:SetAttribute("Spinning", true)
			table.insert(activeTweens, spin)
		end
	end

	local function applyMysticGlow()
		ensureGlowShell()
		syncGlowShell()
		local old = glowShell:FindFirstChild("MysticGlowStroke")
		if old then old:Destroy() end
		local glow = Instance.new("UIStroke")
		glow.Name = "MysticGlowStroke"
		glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		glow.LineJoinMode = Enum.LineJoinMode.Round
		glow.Thickness = 3.5
		glow.Transparency = 0.42
		glow.Color = Color3.new(1, 1, 1)
		glow.Parent = glowShell
		local gradient = Instance.new("UIGradient")
		gradient.Name = "FXGradient"
		local keys = {}
		for i = 0, 6 do
			local h = i / 6
			table.insert(keys, ColorSequenceKeypoint.new(h, Color3.fromHSV(h, 1, 1)))
		end
		gradient.Color = ColorSequence.new(keys)
		gradient.Offset = Vector2.new(-1, 0)
		gradient.Rotation = 0
		gradient.Parent = glow
		local tween = TweenService:Create(gradient, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0), { Offset = Vector2.new(1, 0) })
		tween:Play()
		table.insert(activeTweens, tween)
	end

	local function applyQuality(qualityName, purityKey)
		local effect = qualityEffect(qualityName)
		if effect == "artifact" then
			applyArtifact()
		elseif effect == "legendary" then
			applyLegendary()
		else
			applyDefaultStrokes()
		end
		if purityKey == "mystical" then
			applyMysticGlow()
		else
			removeMysticGlow()
		end
	end

	local function resetSection(section)
		if not section then return nil end
		local list = ensureSectionList(section)
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		return list
	end

	local function setStatsSection(rows)
		rows = type(rows) == "table" and rows or {}
		local hasRows = #rows > 0
		statsSection.Visible = hasRows
		if not hasRows then
			resetSection(statsSection)
			return false
		end
		setSection(statsSection, rows)
		return true
	end

	local function setInfoSection(rows)
		rows = type(rows) == "table" and rows or {}
		local hasRows = #rows > 0
		infoSection.Visible = hasRows
		if not hasRows then
			resetSection(infoSection)
			return false
		end
		setSection(infoSection, rows)
		return true
	end

	local function abilityGridFromData(data)
		local grid = {}
		local source = data.abilitiesGrid or data.abilityRows
		if type(source) == "table" then
			for key, list in pairs(source) do
				if type(list) == "table" then
					grid[tostring(key)] = list
				end
			end
		end
		if next(grid) then return grid end
		local abilities = data.abilities or data.Abilities or {}
		if type(abilities) ~= "table" then return grid end
		for _, ability in ipairs(abilities) do
			local key = "Passive"
			local item = ability
			if type(ability) == "table" then
				key = tostring(ability.Key or ability.key or ability.Row or ability.row or "Passive")
				item = {
					id = ability.imageId or ability.Icon or ability.icon or ability.id or "Default",
					selectable = ability.selectable ~= false,
					selected = ability.selected == true,
					meta = ability,
				}
			else
				local text = tostring(ability)
				key = text:match("^([%w%d]+)%s*[%-%:]") or "Passive"
				item = { id = "Default", selectable = true, meta = text }
			end
			grid[key] = grid[key] or {}
			table.insert(grid[key], item)
		end
		return grid
	end

	local function gridHasContent(grid)
		for _, list in pairs(grid or {}) do
			if type(list) == "table" and #list > 0 then return true end
		end
		return false
	end

	local function ensureAbilitiesGrid()
		local legacyScroll = abilitiesSection:FindFirstChild("RowsScroll")
		if legacyScroll then legacyScroll:Destroy() end
		local legacyRows = abilitiesSection:FindFirstChild("Rows")
		if legacyRows then legacyRows:Destroy() end
		local legacyList = abilitiesSection:FindFirstChild("List")
		if legacyList then legacyList:Destroy() end
		local legacyTemplate = abilitiesSection:FindFirstChild("RowTemplate")
		if legacyTemplate then legacyTemplate:Destroy() end
		abilitiesSection.ClipsDescendants = true
		abilitiesSection.AutomaticSize = Enum.AutomaticSize.None
		if abilitiesSection.Size.Y.Offset < 180 and abilitiesSection.Size.Y.Scale == 0 then
			abilitiesSection.Size = UDim2.new(1, 0, 0, 220)
		end
		local title = abilitiesSection:FindFirstChild("Title")
		if title and title:IsA("TextLabel") then
			title.Position = UDim2.new(0.02, 0, 0.02, 0)
			title.Size = UDim2.new(0.96, 0, 0, 22)
			title.TextScaled = true
		end
		local separator = abilitiesSection:FindFirstChild("Sep")
		if separator and separator:IsA("GuiObject") then
			separator.Position = UDim2.new(0.5, 0, 0, 26)
			separator.Size = UDim2.new(0.96, 0, 0, 1)
		end
		local list = Instance.new("ScrollingFrame")
		list.Name = "List"
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.AnchorPoint = Vector2.new(0.5, 0)
		list.Position = UDim2.new(0.5, 0, 0, 34)
		list.Size = UDim2.new(0.96, 0, 1, -42)
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new()
		list.ScrollBarThickness = 6
		list.ScrollingDirection = Enum.ScrollingDirection.Y
		list.Parent = abilitiesSection
		local rows = Instance.new("Frame")
		rows.Name = "Rows"
		rows.BackgroundTransparency = 1
		rows.Size = UDim2.new(1, 0, 0, 0)
		rows.AutomaticSize = Enum.AutomaticSize.Y
		rows.Parent = list
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = rows
		local function makeRow(key)
			local row = Instance.new("Frame")
			row.Name = key .. "Row"
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 64)
			row.Visible = false
			row.Parent = rows
			local leftWrap = Instance.new("Frame")
			leftWrap.Name = "LeftIconWrap"
			leftWrap.BackgroundColor3 = THEME_PANEL
			leftWrap.BackgroundTransparency = 0.05
			leftWrap.BorderSizePixel = 0
			leftWrap.AnchorPoint = Vector2.new(0, 0.5)
			leftWrap.Position = UDim2.new(0, 0, 0.5, 0)
			leftWrap.Size = UDim2.new(0, 64, 1, 0)
			leftWrap.Parent = row
			local leftCorner = Instance.new("UICorner")
			leftCorner.CornerRadius = UDim.new(0, 8)
			leftCorner.Parent = leftWrap
			local leftStroke = Instance.new("UIStroke")
			leftStroke.Thickness = 1
			leftStroke.Transparency = 0.25
			leftStroke.Color = THEME_GOLD
			leftStroke.Parent = leftWrap
			cacheStrokeDefault(leftStroke)
			local icon = Instance.new("ImageLabel")
			icon.Name = "Icon"
			icon.BackgroundTransparency = 1
			ImageCatalog.SetImage(icon, "Default")
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.5)
			icon.Size = UDim2.fromScale(0.88, 0.88)
			icon.Parent = leftWrap
			local badge = Instance.new("TextLabel")
			badge.Name = "KeyBadge"
			badge.BackgroundColor3 = Color3.fromRGB(26, 18, 16)
			badge.BackgroundTransparency = 0.05
			badge.Text = key
			badge.Font = Enum.Font.GothamBold
			badge.TextScaled = true
			badge.TextColor3 = THEME_TEXT
			badge.AnchorPoint = Vector2.new(1, 1)
			badge.Position = UDim2.new(1, -4, 1, -4)
			badge.Size = UDim2.new(0, 34, 0, 38)
			badge.Parent = leftWrap
			local badgeCorner = Instance.new("UICorner")
			badgeCorner.CornerRadius = UDim.new(0, 8)
			badgeCorner.Parent = badge
			local badgeStroke = Instance.new("UIStroke")
			badgeStroke.Thickness = 1
			badgeStroke.Transparency = 0.2
			badgeStroke.Color = THEME_GOLD
			badgeStroke.Parent = badge
			cacheStrokeDefault(badgeStroke)
			local divider = Instance.new("Frame")
			divider.Name = "Divider"
			divider.BackgroundColor3 = Color3.fromRGB(156, 116, 48)
			divider.BackgroundTransparency = 0.35
			divider.BorderSizePixel = 0
			divider.AnchorPoint = Vector2.new(0, 0.5)
			divider.Position = UDim2.new(0, 72, 0.5, 0)
			divider.Size = UDim2.new(0, 1, 0.8, 0)
			divider.Parent = row
			local buttons = Instance.new("Frame")
			buttons.Name = "Buttons"
			buttons.BackgroundTransparency = 1
			buttons.AnchorPoint = Vector2.new(0, 0.5)
			buttons.Position = UDim2.new(0, 80, 0.5, 0)
			buttons.Size = UDim2.new(1, -88, 1, 0)
			buttons.Parent = row
			local buttonLayout = Instance.new("UIListLayout")
			buttonLayout.FillDirection = Enum.FillDirection.Horizontal
			buttonLayout.Padding = UDim.new(0, 5)
			buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
			buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			buttonLayout.Parent = buttons
			for index = 1, 9 do
				local button = Instance.new("ImageButton")
				button.Name = "Btn" .. tostring(index)
				button.AutoButtonColor = true
				button.BackgroundColor3 = THEME_PANEL
				button.BackgroundTransparency = 0.05
				button.BorderSizePixel = 0
				button.ClipsDescendants = true
				pcall(function() button.ScaleType = Enum.ScaleType.Fit end)
				ImageCatalog.SetImage(button, "Default")
				button.Size = UDim2.new(0, 55, 0, 55)
				button.Visible = false
				local aspect = Instance.new("UIAspectRatioConstraint")
				aspect.AspectRatio = 1
				aspect.Parent = button
				local buttonStroke = Instance.new("UIStroke")
				buttonStroke.Name = "Border"
				buttonStroke.Thickness = 1.2
				buttonStroke.Transparency = 1
				buttonStroke.Color = THEME_GOLD
				buttonStroke.Parent = button
				cacheStrokeDefault(buttonStroke)
				local buttonCorner = Instance.new("UICorner")
				buttonCorner.CornerRadius = UDim.new(0, 6)
				buttonCorner.Parent = button
				button.Parent = buttons
			end
			return row
		end
		for _, key in ipairs({ "Q", "W", "E", "R", "F", "D", "Passive", "Passive2", "Passive3" }) do
			makeRow(key)
		end
		abilitiesSection:SetAttribute("GridAbilities", true)
	end

	local function abilityRowsRoot()
		local rowsScroll = abilitiesSection:FindFirstChild("RowsScroll")
		if rowsScroll and rowsScroll:IsA("ScrollingFrame") then return rowsScroll:FindFirstChild("Rows") end
		local list = abilitiesSection:FindFirstChild("List")
		if list and list:IsA("ScrollingFrame") then return list:FindFirstChild("Rows") end
		return abilitiesSection:FindFirstChild("Rows")
	end

	local function getAbilityRow(key)
		local root = abilityRowsRoot()
		return root and root:FindFirstChild(key .. "Row")
	end

	local function abilitySelectionStore()
		if type(GameState.abilitySelections) ~= "table" then
			GameState.abilitySelections = {}
		end
		return GameState.abilitySelections
	end

	local function abilityItemKey(data)
		if type(data) ~= "table" then
			return "Item"
		end
		return tostring(data.Id or data.id or data.ItemId or data.itemId or data.catalogId or data.DisplayName or data.displayName or data.Name or data.name or data.itemType or data.Type or "Item")
	end

	local function selectedAbilityIndex(itemKey, itemType, rowKey)
		local store = abilitySelectionStore()
		local bucket = store[itemKey]
		local index = type(bucket) == "table" and tonumber(bucket[rowKey]) or nil
		if not index and itemType == "Weapon" then
			if rowKey == "Q" then
				index = tonumber(GameState.currentQ)
			elseif rowKey == "W" then
				index = tonumber(GameState.currentW)
			end
		end
		return math.max(1, math.floor(index or 1))
	end

	local function rememberAbilitySelection(itemKey, itemType, rowKey, index)
		index = math.max(1, math.floor(tonumber(index) or 1))
		local store = abilitySelectionStore()
		local bucket = store[itemKey]
		if type(bucket) ~= "table" then
			bucket = {}
			store[itemKey] = bucket
		end
		bucket[rowKey] = index
		if itemType == "Weapon" then
			if rowKey == "Q" then
				GameState.currentQ = index
			elseif rowKey == "W" then
				GameState.currentW = index
			end
		end
	end

	local function clearAbilityButtons(row)
		if not row then return end
		local leftWrap = row:FindFirstChild("LeftIconWrap")
		if leftWrap then
			leftAbilityPayloads[leftWrap] = nil
			leftWrap:SetAttribute("RowKey", nil)
			leftWrap:SetAttribute("Index", nil)
		end
		local wrap = row:FindFirstChild("Buttons")
		if not wrap then return end
		for _, button in ipairs(wrap:GetChildren()) do
			if button:IsA("ImageButton") then
				ImageCatalog.SetImage(button, "Default")
				button.BackgroundColor3 = THEME_PANEL
				button.BackgroundTransparency = 0.05
				button.BorderSizePixel = 0
				button.ClipsDescendants = true
				pcall(function() button.ScaleType = Enum.ScaleType.Fit end)
				if not button:FindFirstChildOfClass("UIAspectRatioConstraint") then
					local aspect = Instance.new("UIAspectRatioConstraint")
					aspect.AspectRatio = 1
					aspect.Parent = button
				end
				button.Visible = false
				button:SetAttribute("Selectable", false)
				button:SetAttribute("RowKey", nil)
				button:SetAttribute("ItemType", nil)
				button:SetAttribute("ItemKey", nil)
				button:SetAttribute("IconId", nil)
				button:SetAttribute("AbilityMeta", nil)
				abilityPayloads[button] = nil
				local strokeObject = button:FindFirstChild("Border")
				if strokeObject then strokeObject.Transparency = 1 end
			end
		end
		row:SetAttribute("SelectedIndex", nil)
	end

	local function themeButtonStroke(strokeObject)
		if not strokeObject then return end
		local effect = qualityEffect(activeQualityName)
		if effect == "artifact" then
			strokeObject.Color = Color3.new(1, 1, 1)
			local gradient = strokeObject:FindFirstChild("FXGradient")
			if not gradient then
				gradient = Instance.new("UIGradient")
				gradient.Name = "FXGradient"
				gradient.Color = makeBWRadialGradient(0.52)
				gradient.Rotation = 0
				gradient.Parent = strokeObject
			end
			if not gradient:GetAttribute("Spinning") then
				local spin = TweenService:Create(gradient, TweenInfo.new(16, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0), { Rotation = 359.9 })
				spin:Play()
				table.insert(activeTweens, spin)
				gradient:SetAttribute("Spinning", true)
			end
			gradient.Enabled = true
		elseif effect == "legendary" then
			local gradient = strokeObject:FindFirstChild("FXGradient")
			if gradient then gradient.Enabled = false end
			strokeObject.Color = DARK_RED
		else
			local gradient = strokeObject:FindFirstChild("FXGradient")
			if gradient then gradient.Enabled = false end
			local defaultColor = defaultStrokeColors[strokeObject]
			if defaultColor then strokeObject.Color = defaultColor end
		end
	end

	local function selectAbilityButton(row, button)
		local wrap = row:FindFirstChild("Buttons")
		if not wrap then return end
		for _, child in ipairs(wrap:GetChildren()) do
			if child:IsA("ImageButton") then
				local strokeObject = child:FindFirstChild("Border")
				if strokeObject then
					themeButtonStroke(strokeObject)
					strokeObject.Transparency = child:GetAttribute("Selectable") and 0.15 or 1
					local gradient = strokeObject:FindFirstChild("FXGradient")
					if gradient then gradient.Enabled = true end
				end
			end
		end
		local strokeObject = button:FindFirstChild("Border")
		if strokeObject then
			themeButtonStroke(strokeObject)
			local gradient = strokeObject:FindFirstChild("FXGradient")
			if gradient then gradient.Enabled = false end
			strokeObject.Color = BLUE
			strokeObject.Transparency = 0
		end
		row:SetAttribute("SelectedIndex", button:GetAttribute("Index"))
		local leftWrap = row:FindFirstChild("LeftIconWrap")
		if leftWrap then
			leftWrap:SetAttribute("RowKey", button:GetAttribute("RowKey"))
			leftWrap:SetAttribute("Index", button:GetAttribute("Index"))
			leftAbilityPayloads[leftWrap] = abilityPayloads[button] or button:GetAttribute("AbilityMeta")
			local leftIcon = leftWrap:FindFirstChild("Icon")
			if leftIcon and leftIcon:IsA("ImageLabel") then
				leftIcon.Image = button.Image
				leftIcon.ImageColor3 = button.ImageColor3
				leftIcon.ImageTransparency = button.ImageTransparency
				leftIcon.ImageRectOffset = button.ImageRectOffset
				leftIcon.ImageRectSize = button.ImageRectSize
			end
		end
	end

	local abilityTooltip = nil

	local function abilityMetaField(meta, ...)
		if type(meta) ~= "table" then return nil end
		for _, key in ipairs({ ... }) do
			local value = meta[key]
			if value ~= nil and value ~= "" then return value end
		end
		return nil
	end

	local function statText(value, suffix)
		if value == nil or value == "" then return "-" end
		local num = tonumber(value)
		if num then
			local text = (math.abs(num - math.floor(num)) < 0.05) and tostring(math.floor(num)) or string.format("%.1f", num)
			return text .. (suffix or "")
		end
		return tostring(value)
	end

	local function itemPowerDamageScale()
		local character = player.Character
		local itemPower = math.max(0, tonumber(character and character:GetAttribute("ItemPower")) or 0)
		if itemPower <= 0 then return itemPower, 1 end
		return itemPower, math.clamp(1 + math.max(0, itemPower - 100) * 0.0015, 1, 4)
	end

	local function effectiveDamageText(meta)
		local baseDamage = type(meta) == "table" and abilityMetaField(meta, "damage", "Damage", "baseDamage", "BaseDamage") or nil
		local baseNumber = tonumber(baseDamage)
		if not baseNumber then return nil end
		local itemPower, scale = itemPowerDamageScale()
		local character = player.Character
		local abilityBonus = math.max(0, tonumber(character and character:GetAttribute("PhysicalAbilityBonus")) or 0)
		local effective = math.max(0, math.floor(baseNumber * scale + abilityBonus + 0.5))
		if itemPower > 0 then
			return string.format("Damage %s", statText(effective, ""))
		end
		return string.format("Damage %s", statText(baseNumber, ""))
	end

	local function ensureAbilityTooltip()
		if abilityTooltip and abilityTooltip.Parent then return abilityTooltip end
		abilityTooltip = Instance.new("Frame")
		abilityTooltip.Name = "AbilityTooltip"
		abilityTooltip.BackgroundColor3 = Color3.fromRGB(26, 18, 16)
		abilityTooltip.BackgroundTransparency = 0.04
		abilityTooltip.BorderSizePixel = 0
		abilityTooltip.Size = UDim2.fromOffset(300, 142)
		abilityTooltip.Visible = false
		abilityTooltip.ZIndex = 90
		abilityTooltip.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = abilityTooltip
		local stroke = Instance.new("UIStroke")
		stroke.Color = THEME_GOLD
		stroke.Transparency = 0.08
		stroke.Thickness = 1
		stroke.Parent = abilityTooltip
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 9)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = abilityTooltip
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 15
		title.TextColor3 = THEME_TEXT
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextYAlignment = Enum.TextYAlignment.Top
		title.Size = UDim2.new(1, 0, 0, 22)
		title.ZIndex = 91
		title.Parent = abilityTooltip
		local desc = Instance.new("TextLabel")
		desc.Name = "Description"
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 13
		desc.TextWrapped = true
		desc.TextColor3 = THEME_SUBTLE
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.Position = UDim2.fromOffset(0, 27)
		desc.Size = UDim2.new(1, 0, 1, -72)
		desc.ZIndex = 91
		desc.Parent = abilityTooltip
		local footer = Instance.new("TextLabel")
		footer.Name = "Footer"
		footer.BackgroundTransparency = 1
		footer.Font = Enum.Font.GothamBold
		footer.TextSize = 12
		footer.TextColor3 = THEME_GOLD
		footer.TextXAlignment = Enum.TextXAlignment.Left
		footer.AnchorPoint = Vector2.new(0, 1)
		footer.Position = UDim2.new(0, 0, 1, 0)
		footer.Size = UDim2.new(1, 0, 0, 20)
		footer.ZIndex = 91
		footer.Parent = abilityTooltip
		return abilityTooltip
	end

	local function positionAbilityTooltip(button)
		local frame = ensureAbilityTooltip()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local size = frame.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then size = Vector2.new(300, 142) end
		local base = button.AbsolutePosition + Vector2.new(button.AbsoluteSize.X + 10, 0)
		local x = math.clamp(base.X, 8, math.max(8, viewport.X - size.X - 8))
		local y = math.clamp(base.Y, 8, math.max(8, viewport.Y - size.Y - 8))
		frame.Position = UDim2.fromOffset(x, y)
	end

	local function showAbilityTooltip(button, meta, rowKey, index)
		local frame = ensureAbilityTooltip()
		local title = frame:FindFirstChild("Title")
		local desc = frame:FindFirstChild("Description")
		local footer = frame:FindFirstChild("Footer")
		local name = type(meta) == "table" and (abilityMetaField(meta, "name", "Name", "id", "Id") or tostring(rowKey or "Ability")) or tostring(meta or rowKey or "Ability")
		local description = type(meta) == "table" and tostring(abilityMetaField(meta, "description", "Description") or "No details yet.") or "No details yet."
		local cooldown = type(meta) == "table" and abilityMetaField(meta, "cooldown", "Cooldown") or nil
		local range = type(meta) == "table" and abilityMetaField(meta, "range", "Range", "radius", "Radius") or nil
		local mana = type(meta) == "table" and abilityMetaField(meta, "manaCost", "ManaCost", "mana", "Mana") or nil
		local damageText = effectiveDamageText(meta)
		if title then title.Text = string.format("%s %s", tostring(rowKey or ""), name) end
		if desc then desc.Text = description end
		if footer then
			local parts = {}
			if damageText then table.insert(parts, damageText) end
			table.insert(parts, string.format("Cooldown %s", statText(cooldown, "s")))
			table.insert(parts, string.format("Range %s", statText(range, "")))
			table.insert(parts, string.format("Mana %s", statText(mana, "")))
			footer.Text = table.concat(parts, "   ")
		end
		frame.Visible = true
		positionAbilityTooltip(button)
	end

	local function hideAbilityTooltip()
		if abilityTooltip then abilityTooltip.Visible = false end
	end

	local function currentAbilityMeta(button, fallback)
		return abilityPayloads[button] or button:GetAttribute("AbilityMeta") or fallback
	end

	local function wireAbilityClick(row, button, rowKey, itemType, metaPayload, itemKey)
		if button:GetAttribute("Wired") then return end
		button.Activated:Connect(function()
			if not button:GetAttribute("Selectable") then return end
			if currentReadOnlyAbilities then return end
			local selectedIndex = tonumber(button:GetAttribute("Index")) or 1
			local currentRowKey = tostring(button:GetAttribute("RowKey") or rowKey)
			local currentItemType = tostring(button:GetAttribute("ItemType") or itemType)
			local currentItemKey = tostring(button:GetAttribute("ItemKey") or itemKey or currentItemType)
			local meta = currentAbilityMeta(button, metaPayload)
			selectAbilityButton(row, button)
			rememberAbilitySelection(currentItemKey, currentItemType, currentRowKey, selectedIndex)
			pcall(function()
				AbilitySelectionUpdate:FireServer(currentItemKey, currentItemType, currentRowKey, selectedIndex)
			end)
			if _G.OnAbilitySelected then
				_G.OnAbilitySelected(currentItemType, currentRowKey, selectedIndex, meta)
			end
		end)
		button.MouseEnter:Connect(function()
			showAbilityTooltip(button, currentAbilityMeta(button, metaPayload), button:GetAttribute("RowKey") or rowKey, button:GetAttribute("Index"))
		end)
		button.MouseLeave:Connect(hideAbilityTooltip)
		button.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement and abilityTooltip and abilityTooltip.Visible then
				positionAbilityTooltip(button)
			end
		end)
		button:SetAttribute("Wired", true)
	end

	local function fillAbilityButtons(row, items, rowKey, itemType, itemKey)
		if not row then return nil end
		local wrap = row:FindFirstChild("Buttons")
		if not wrap then return nil end
		clearAbilityButtons(row)
		row:SetAttribute("RowKey", rowKey)
		row:SetAttribute("ItemType", itemType)
		row:SetAttribute("ItemKey", itemKey)
		local rememberedIndex = currentReadOnlyAbilities and nil or selectedAbilityIndex(itemKey, itemType, rowKey)
		local selectedButton = nil
		local firstSelectable = nil
		local index = 1
		for _, item in ipairs(items or {}) do
			if index > 9 then break end
			local button = wrap:FindFirstChild("Btn" .. tostring(index))
			if button then
				local iconId = item
				local selectable = true
				local selected = index == rememberedIndex
				local meta = item
				if type(item) == "table" then
					iconId = item.id or item.imageId or item.icon or item.Icon or "Default"
					selectable = item.selectable ~= false
					selected = selected or item.selected == true
					meta = item.meta or item.name or item.Name or item.id or item.icon or "Ability"
				end
				ImageCatalog.SetImage(button, iconId or "Default")
				button.BackgroundColor3 = THEME_PANEL
				button.BackgroundTransparency = 0.05
				button.BorderSizePixel = 0
				button.ClipsDescendants = true
				pcall(function() button.ScaleType = Enum.ScaleType.Fit end)
				if not button:FindFirstChildOfClass("UIAspectRatioConstraint") then
					local aspect = Instance.new("UIAspectRatioConstraint")
					aspect.AspectRatio = 1
					aspect.Parent = button
				end
				button.Visible = true
				button:SetAttribute("Selectable", selectable)
				button:SetAttribute("Index", index)
				button:SetAttribute("RowKey", rowKey)
				button:SetAttribute("ItemType", itemType)
				button:SetAttribute("ItemKey", itemKey)
				button:SetAttribute("IconId", iconId or "Default")
				button:SetAttribute("AbilityMeta", typeof(meta) == "string" and meta or nil)
				abilityPayloads[button] = meta
				local strokeObject = button:FindFirstChild("Border")
				if strokeObject then
					themeButtonStroke(strokeObject)
					strokeObject.Transparency = selectable and 0.15 or 1
				end
				wireAbilityClick(row, button, rowKey, itemType, meta, itemKey)
				if selectable and not firstSelectable then firstSelectable = button end
				if selected and selectable then selectedButton = button end
			end
			index += 1
		end
		selectedButton = selectedButton or firstSelectable
		if selectedButton then
			selectAbilityButton(row, selectedButton)
			if not currentReadOnlyAbilities then
				rememberAbilitySelection(itemKey, itemType, rowKey, tonumber(selectedButton:GetAttribute("Index")) or 1)
			end
		end
		return selectedButton
	end

	local function setAbilityLeftIcon(row, iconId, keyText, metaPayload, rowKey, selectedIndex)
		if not row then return end
		local wrap = row:FindFirstChild("LeftIconWrap")
		if not wrap then return end
		wrap.Active = true
		wrap:SetAttribute("RowKey", rowKey or keyText)
		wrap:SetAttribute("Index", selectedIndex or 1)
		leftAbilityPayloads[wrap] = metaPayload
		local icon = wrap:FindFirstChild("Icon")
		if icon then
			ImageCatalog.SetImage(icon, iconId or "Default")
			pcall(function() icon.Active = false end)
		end
		local badge = wrap:FindFirstChild("KeyBadge")
		if badge and keyText then badge.Text = keyText end
		if not wrap:GetAttribute("TooltipWired") then
			wrap.MouseEnter:Connect(function()
				local meta = leftAbilityPayloads[wrap]
				if meta then
					showAbilityTooltip(wrap, meta, wrap:GetAttribute("RowKey") or keyText, wrap:GetAttribute("Index") or 1)
				end
			end)
			wrap.MouseLeave:Connect(hideAbilityTooltip)
			wrap.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement and abilityTooltip and abilityTooltip.Visible then
					positionAbilityTooltip(wrap)
				end
			end)
			wrap:SetAttribute("TooltipWired", true)
		end
	end

	local function orderForType(itemType, grid)
		local order = {}
		for _, key in ipairs(ORDERS[itemType] or { "Passive" }) do
			table.insert(order, key)
		end
		for key in pairs(grid or {}) do
			local found = false
			for _, existing in ipairs(order) do
				if existing == key then found = true break end
			end
			if not found then table.insert(order, key) end
		end
		return order
	end

	local function populateAbilitiesGrid(data)
		local grid = abilityGridFromData(data)
		if not gridHasContent(grid) then
			abilitiesSection.Visible = false
			return false
		end
		ensureAbilitiesGrid()
		abilitiesSection.Visible = true
		local itemType = tostring(data.itemType or data.type or data.Type or "Passive")
		local itemKey = abilityItemKey(data)
		local root = abilityRowsRoot()
		if not root then return true end
		for _, row in ipairs(root:GetChildren()) do
			if row:IsA("Frame") and row.Name:match("Row$") then
				row.Visible = false
				clearAbilityButtons(row)
			end
		end
		local abilityIcons = type(data.abilityIcons) == "table" and data.abilityIcons or {}
		local visibleRows = 0
		for _, key in ipairs(orderForType(itemType, grid)) do
			local items = grid[key]
			if type(items) == "table" and #items > 0 then
				local row = getAbilityRow(key)
				if row then
					visibleRows += 1
					row.LayoutOrder = visibleRows
					row.Visible = true
					local first = items[1]
					local firstIcon = type(first) == "table" and (first.id or first.imageId or first.icon or first.Icon) or first
					local selectedButton = fillAbilityButtons(row, items, key, itemType, itemKey)
					local selectedIcon = selectedButton and selectedButton:GetAttribute("IconId") or abilityIcons[key] or firstIcon or data.imageId or "Default"
					local selectedMeta = selectedButton and currentAbilityMeta(selectedButton, first) or first
					local selectedIndex = selectedButton and tonumber(selectedButton:GetAttribute("Index")) or 1
					setAbilityLeftIcon(row, selectedIcon, (key == "Passive2" or key == "Passive3") and "Passive" or key, selectedMeta, key, selectedIndex)
				end
			end
		end
		return visibleRows > 0
	end

	local function ensureRecipeGallery()
		local oldList = recipeSection:FindFirstChild("List")
		if oldList then oldList:Destroy() end
		local template = recipeSection:FindFirstChild("RowTemplate")
		if template then template:Destroy() end
		local scroll = recipeSection:FindFirstChild("GalleryScroll")
		if not (scroll and scroll:IsA("ScrollingFrame")) then
			scroll = Instance.new("ScrollingFrame")
			scroll.Name = "GalleryScroll"
			scroll.BackgroundTransparency = 1
			scroll.BorderSizePixel = 0
			scroll.AnchorPoint = Vector2.new(0.5, 0)
			scroll.Position = UDim2.new(0.5, 0, 0.2, 0)
			scroll.Size = UDim2.new(0.96, 0, 0.76, 0)
			scroll.ScrollBarThickness = 6
			scroll.ScrollingDirection = Enum.ScrollingDirection.X
			scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
			scroll.CanvasSize = UDim2.new()
			scroll.ClipsDescendants = true
			scroll.Parent = recipeSection
		end
		local row = scroll:FindFirstChild("Row")
		if not row then
			row = Instance.new("Frame")
			row.Name = "Row"
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(0, 0, 1, 0)
			row.AutomaticSize = Enum.AutomaticSize.X
			row.Parent = scroll
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			layout.VerticalAlignment = Enum.VerticalAlignment.Top
			layout.Padding = UDim.new(0, 8)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = row
		end
		local function makeCard(index)
			local cardFrame = row:FindFirstChild("Card" .. tostring(index))
			if cardFrame then return cardFrame end
			cardFrame = Instance.new("Frame")
			cardFrame.Name = "Card" .. tostring(index)
			cardFrame.BackgroundTransparency = 1
			cardFrame.Size = UDim2.new(0, 102, 1, 0)
			cardFrame.Parent = row
			local cell = Instance.new("Frame")
			cell.Name = "Cell"
			cell.BackgroundColor3 = THEME_PANEL
			cell.BackgroundTransparency = 0.05
			cell.BorderSizePixel = 0
			cell.AnchorPoint = Vector2.new(0.5, 0)
			cell.Position = UDim2.new(0.5, 0, 0, 0)
			cell.Size = UDim2.new(0.96, 0, 1, 0)
			cell.Parent = cardFrame
			local cellCorner = Instance.new("UICorner")
			cellCorner.CornerRadius = UDim.new(0, 10)
			cellCorner.Parent = cell
			local cellStroke = Instance.new("UIStroke")
			cellStroke.Thickness = 1
			cellStroke.Transparency = 0.15
			cellStroke.Color = THEME_GOLD
			cellStroke.Parent = cell
			cacheStrokeDefault(cellStroke)
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Vertical
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			layout.Padding = UDim.new(0, 6)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = cell
			local thumb = Instance.new("ImageButton")
			thumb.Name = "Thumb"
			thumb.AutoButtonColor = true
			thumb.BackgroundColor3 = Color3.fromRGB(22, 16, 14)
			thumb.BackgroundTransparency = 0.1
			ImageCatalog.SetImage(thumb, "Default")
			thumb.Size = UDim2.new(1, -10, 0, 0)
			thumb.LayoutOrder = 1
			thumb.Parent = cell
			local thumbCorner = Instance.new("UICorner")
			thumbCorner.CornerRadius = UDim.new(0, 8)
			thumbCorner.Parent = thumb
			local thumbStroke = Instance.new("UIStroke")
			thumbStroke.Name = "Border"
			thumbStroke.Thickness = 1
			thumbStroke.Transparency = 0.2
			thumbStroke.Color = THEME_GOLD
			thumbStroke.Parent = thumb
			cacheStrokeDefault(thumbStroke)
			local aspect = Instance.new("UIAspectRatioConstraint")
			aspect.AspectRatio = 1
			aspect.Parent = thumb
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "Name"
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = "-"
			nameLabel.Font = Enum.Font.Gotham
			nameLabel.TextScaled = true
			nameLabel.TextWrapped = true
			nameLabel.TextColor3 = THEME_TEXT
			nameLabel.TextXAlignment = Enum.TextXAlignment.Center
			nameLabel.Size = UDim2.new(1, -10, 0, 28)
			nameLabel.LayoutOrder = 2
			nameLabel.Parent = cell
			if not thumb:GetAttribute("Wired") then
				thumb.Activated:Connect(function()
					local recipeIndex = tonumber(thumb:GetAttribute("RecipeIndex"))
					if recipeIndex and _G.OnRecipeClicked then
						_G.OnRecipeClicked(recipePayloads[recipeIndex])
					end
				end)
				thumb:SetAttribute("Wired", true)
			end
			return cardFrame
		end
		for index = 1, 6 do makeCard(index) end
		recipeSection:SetAttribute("RecipeGallery", true)
	end

	local function recipeItemsFromData(data)
		local items = data.recipeGrid or data.RecipeGrid
		if type(items) == "table" and #items > 0 then return items end
		items = {}
		local recipe = data.recipe or data.Recipe
		if type(recipe) == "table" then
			for _, entry in ipairs(recipe) do
				if type(entry) == "table" then
					table.insert(items, entry)
				else
					table.insert(items, { imageId = "Default", name = tostring(entry) })
				end
			end
		end
		return items
	end

	local function reapplySelectedAbilityStrokes()
		local root = abilityRowsRoot()
		if not root then return end
		for _, row in ipairs(root:GetChildren()) do
			if row:IsA("Frame") and row.Visible then
				local selectedIndex = tonumber(row:GetAttribute("SelectedIndex"))
					or selectedAbilityIndex(row:GetAttribute("ItemKey"), row:GetAttribute("ItemType"), row:GetAttribute("RowKey"))
				local wrap = row:FindFirstChild("Buttons")
				local selectedButton = nil
				if wrap and selectedIndex then
					for _, button in ipairs(wrap:GetChildren()) do
						if button:IsA("ImageButton") and button.Visible and tonumber(button:GetAttribute("Index")) == selectedIndex then
							selectedButton = button
							break
						end
					end
				end
				if selectedButton and selectedButton:GetAttribute("Selectable") then
					selectAbilityButton(row, selectedButton)
				end
			end
		end
	end

	local function populateRecipeGallery(data)
		local items = recipeItemsFromData(data)
		if #items == 0 then
			recipeSection.Visible = false
			return false
		end
		if not recipeSection:GetAttribute("RecipeGallery") then ensureRecipeGallery() end
		recipeSection.Visible = true
		recipePayloads = {}
		local scroll = recipeSection:FindFirstChild("GalleryScroll")
		local row = scroll and scroll:FindFirstChild("Row")
		if not row then return true end
		local index = 0
		for _, item in ipairs(items) do
			index += 1
			local cardFrame = row:FindFirstChild("Card" .. tostring(index))
			if not cardFrame then
				local first = row:FindFirstChild("Card1")
				if first then
					cardFrame = first:Clone()
					cardFrame.Name = "Card" .. tostring(index)
					cardFrame.Parent = row
				end
			end
			local isTable = type(item) == "table"
			local imageId = isTable and (item.imageId or item.iconId or item.image or item.Icon or item.id) or "Default"
			local label = isTable and (item.name or item.label or item.Name or tostring(item.Id or item.id or "Ingredient")) or tostring(item)
			recipePayloads[index] = item
			if cardFrame then
				local cell = cardFrame:FindFirstChild("Cell")
				local thumb = cell and cell:FindFirstChild("Thumb")
				local nameLabel = cell and cell:FindFirstChild("Name")
				if thumb then
					ImageCatalog.SetImage(thumb, imageId or "Default")
					thumb:SetAttribute("RecipeIndex", index)
				end
				if nameLabel then nameLabel.Text = tostring(label or "-") end
				cardFrame.Visible = true
			end
		end
		local nextIndex = index + 1
		while row:FindFirstChild("Card" .. tostring(nextIndex)) do
			row["Card" .. tostring(nextIndex)].Visible = false
			nextIndex += 1
		end
		return true
	end

	local function closeDetail()
		card.Visible = false
		if backdrop then
			backdrop.Visible = false
			backdrop.BackgroundTransparency = 1
		end
		stopTweens()
		removeMysticGlow()
	end

	local inventoryRequest = replicatedPackage:WaitForChild("RemoteEvents"):WaitForChild("InventoryRequest")
	local footer = card:FindFirstChild("Footer")
	local equipButton = footer and footer:FindFirstChild("EquipButton")
	local activeDetailData = nil
	local actionBusy = false

	local useAllButton = nil
	if footer and equipButton and equipButton:IsA("TextButton") then
		footer.Size = UDim2.new(0.42, 0, footer.Size.Y.Scale, footer.Size.Y.Offset)
		equipButton.Position = UDim2.new(0, 0, 0, 0)
		equipButton.Size = UDim2.new(0.48, 0, 1, 0)
		useAllButton = footer:FindFirstChild("UseAllButton")
		if not useAllButton then
			useAllButton = equipButton:Clone()
			useAllButton.Name = "UseAllButton"
			useAllButton.Parent = footer
		end
		useAllButton.Position = UDim2.new(0.52, 0, 0, 0)
		useAllButton.Size = UDim2.new(0.48, 0, 1, 0)
		useAllButton.Text = "USE ALL"
	end

	local function updateActionButton(data)
		local itemType = tostring(data and (data.itemType or data.type or data.Type) or "")
		local inventorySlot = data and (data.inventorySlot or data.InventorySlot)
		local amount = math.max(1, math.floor(tonumber(data and (data.amount or data.Amount)) or 1))
		local canUse = itemType == "CoinSack" and inventorySlot ~= nil
		if footer and footer:IsA("GuiObject") then footer.Visible = canUse end
		if equipButton and equipButton:IsA("GuiObject") then
			equipButton.Visible = canUse
			if equipButton:IsA("TextButton") then equipButton.Text = "USE" end
		end
		if useAllButton and useAllButton:IsA("GuiObject") then
			useAllButton.Visible = canUse and amount > 1
			if useAllButton:IsA("TextButton") then useAllButton.Text = "USE ALL" end
		end
	end

	local function openDetail(data)
		data = type(data) == "table" and data or {}
		activeDetailData = data
		currentReadOnlyAbilities = data.ReadOnlyAbilities == true or data.InspectReadOnly == true
		cacheDefaults()
		card.Visible = true
		if backdrop then
			backdrop.Visible = false
			backdrop.BackgroundTransparency = 1
		end
		if preview then
			ImageCatalog.SetImage(preview, data.imageId or data.Icon or data.icon or "Default")
		end
		local amount = math.max(1, math.floor(tonumber(data.amount or data.Amount) or 1))
		amountBadge.Visible = amount > 1
		amountBadge.Text = "x" .. tostring(amount)
		local qualityName = tostring(data.qualityName or data.Quality or "Normal")
		local purityName = tostring(data.purity or data.Purity or "None")
		local purityKey = normalizePurity(purityName)
		activeQualityName = qualityName
		activePurityKey = purityKey
		if quality then
			quality.Text = "Quality: " .. qualityName
			quality.TextColor3 = THEME_TEXT
		end
		local label = getOrCreatePurityLabel()
		if label then
			label.Text = "Purity: " .. (purityName ~= "" and purityName or "None")
			label.TextColor3 = THEME_SUBTLE
		end
		if purityIcon then
			local iconId = data.purityImageId or data.enhancementImageId or PURITY_ICON_IDS[purityKey] or PURITY_ICON_IDS.none
			ImageCatalog.SetImage(purityIcon, iconId)
		end
		local percent = data.weightPercent or data.WeightPercent
		if percent ~= nil then
			weightLabel.Text = string.format("Weight: %s kg (%d%%)", formatWeight(data.weightTotal or data.WeightTotal), pct(percent))
		else
			weightLabel.Text = string.format("Weight: %s kg", formatWeight(data.weightTotal or data.WeightTotal))
		end
		byLabel.Text = tostring(data.byType or "Found") .. " by: " .. tostring(data.byName or "World")
		namePower.Text = string.format("%s  |  %s", tostring(data.itemName or data.DisplayName or "Item"), comma(data.power or data.Power or 0))
		descText.Text = tostring(data.description or data.Description or "")
		local slotText = data.slot or data.Slot
		slotLabel.Visible = slotText ~= nil and tostring(slotText) ~= ""
		if slotLabel.Visible then slotLabel.Text = "Slot: " .. tostring(slotText) end
		valueLabel.Text = "Value: " .. tostring(data.value or data.Value or "-")
		typeLabel.Text = "Type: " .. tostring(data.itemType or data.type or data.Type or "Item")
		updateActionButton(data)
		local infoVisible = setInfoSection(data.info or data.Info or {})
		local statsVisible = setStatsSection(data.stats or data.Stats or {})
		local abilitiesVisible = populateAbilitiesGrid(data)
		local recipeVisible = populateRecipeGallery(data)
		right.Visible = infoVisible or statsVisible or abilitiesVisible or recipeVisible
		applyQuality(qualityName, purityKey)
		reapplySelectedAbilityStrokes()
	end

	_G.OpenItemDetail = openDetail
	_G.CloseItemDetail = closeDetail
	closeDetail()

	close.Activated:Connect(closeDetail)
	if close:IsA("TextButton") or close:IsA("ImageButton") then
		close.MouseButton1Click:Connect(closeDetail)
		close.MouseButton1Down:Connect(closeDetail)
	end
	close.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeDetail()
		end
	end)
	updateActionButton(nil)
	local function useCoinSack(amount, sourceButton)
		if actionBusy or not activeDetailData then return end
		local itemType = tostring(activeDetailData.itemType or activeDetailData.type or activeDetailData.Type or "")
		local inventorySlot = activeDetailData.inventorySlot or activeDetailData.InventorySlot
		if itemType ~= "CoinSack" or inventorySlot == nil then return end
		actionBusy = true
		if sourceButton and sourceButton:IsA("TextButton") then sourceButton.Text = "..." end
		local ok, result = pcall(function()
			return inventoryRequest:InvokeServer("UseInventory", { Slot = inventorySlot, Amount = amount })
		end)
		actionBusy = false
		if ok and result and result.Ok then
			closeDetail()
		else
			updateActionButton(activeDetailData)
		end
	end
	if equipButton and equipButton:IsA("GuiButton") then
		equipButton.Activated:Connect(function()
			useCoinSack(1, equipButton)
		end)
	end
	if useAllButton and useAllButton:IsA("GuiButton") then
		useAllButton.Activated:Connect(function()
			useCoinSack(activeDetailData and (activeDetailData.amount or activeDetailData.Amount) or nil, useAllButton)
		end)
	end

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = card.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			card.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

return Controller
