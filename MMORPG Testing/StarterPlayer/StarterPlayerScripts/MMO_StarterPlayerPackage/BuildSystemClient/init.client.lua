--[[
Name: BuildSystemClient
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.BuildSystemClient
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, UserInputService, ContextActionService, RunService, ReplicatedStorage, TweenService, ProximityPromptService, Workspace
Requires:
  - local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("BuildSystemConfig"))
  - local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
  - local ImageCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ImageCatalog"))
  - local GameState = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util"):WaitFor...
Functions: mk, addCorner, addStroke, addGradient, toVector3, costText, itemDisplayName, setPlacementActive, showNotice, isMouseOverGui, getMouseRaycast, getSlotFromState, getSlotFromWorldPosition, findSlotPart, setMenuOpen, destroyGhost, stopPlacement, updatePlacementGhost, startPlacement, handlePlacementClick, clearMenuButtons, makeMenuButton, makeRecipeCard, sortedBuildingKeys, showBuildingInBuildMenu, formatCoin, clearContainer, findBuildingInstance, setManageTooltip, makeRequirementCard, costRequirements, costProgressComplete, costProgressPercent, makeCostRequirementCards, closeLeftPanelsForManage, closeManagePanel, refreshManagePanel, openCityManagePanel, openBuildingManagePanel, refreshPromptText, updatePromptButton, refreshMenu, buildGui, applyState, showPrompt, hidePrompt, openMonolithPanel, toggleMenuAction, onInputBegan, manageActionCallback
Clean source lines: 1420
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("BuildSystemConfig"))
local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local ImageCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ImageCatalog"))
local GameState = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util"):WaitForChild("GameState"))
local remotesFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("BuildSystemRemotes")
local actionRemote = remotesFolder:WaitForChild("Action")
local stateRemote = remotesFolder:WaitForChild("State")
local requestStateRemote = remotesFolder:WaitForChild("RequestState")
local openMonolithRemote = remotesFolder:WaitForChild("OpenMonolithPanel")

local Theme = {
	panelBg = Color3.fromRGB(14, 10, 10),
	panelTop = Color3.fromRGB(28, 20, 18),
	slotOuter = Color3.fromRGB(26, 18, 16),
	slotInner = Color3.fromRGB(38, 26, 22),
	gilt = Color3.fromRGB(232, 176, 64),
	text = Color3.fromRGB(242, 228, 198),
	subtleText = Color3.fromRGB(210, 196, 166),
	success = Color3.fromRGB(88, 188, 116),
	danger = Color3.fromRGB(190, 72, 68),
}

local localState
local gui
local menuFrame
local menuList
local statusLabel
local hintLabel
local promptFrame
local promptTitle
local promptStatus
local promptOwner
local promptTaxes
local promptTaxClaimButton
local promptUpkeep
local promptNameBox
local promptCost
local promptClaimButton
local promptRenameButton
local promptManageButton
local manageFrame
local manageTitle
local manageStatus
local manageList
local manageActionButton
local manageTooltip
local manageActionCallback
local activeManage
local activePrompt
local menuOpen = false
local placementKey
local placementGhost
local placementConn
local currentSlotId
local currentPlacementValid = false
local noticeToken = 0

local function mk(className, props, children)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do
		obj[key] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	return obj
end

local function addCorner(parent, radius)
	mk("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function addStroke(parent, color, thickness, transparency)
	mk("UIStroke", {
		Color = color or Theme.gilt,
		Thickness = thickness or 1.2,
		Transparency = transparency or 0.15,
		Parent = parent,
	})
end

local function addGradient(parent)
	mk("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.panelTop),
			ColorSequenceKeypoint.new(1, Theme.panelBg),
		}),
		Parent = parent,
	})
end

local function toVector3(t)
	if typeof(t) == "Vector3" then
		return t
	end
	if type(t) ~= "table" then
		return nil
	end
	local x = tonumber(t.x or t.X or t[1])
	local y = tonumber(t.y or t.Y or t[2])
	local z = tonumber(t.z or t.Z or t[3])
	if x and y and z then
		return Vector3.new(x, y, z)
	end
	return nil
end

local function costText(cost)
	return Config.CostToText and Config.CostToText(cost) or "Cost unavailable"
end

local function itemDisplayName(itemId)
	local def = ItemCatalog.Get and ItemCatalog.Get(itemId)
	return (def and def.DisplayName) or tostring(itemId)
end

local function setPlacementActive(active)
	GameState.buildPlacementActive = active == true
	player:SetAttribute("BuildPlacementActive", active == true)
end

local function showNotice(text)
	if not hintLabel or not text or text == "" then
		return
	end
	noticeToken += 1
	local token = noticeToken
	hintLabel.Text = tostring(text)
	hintLabel.Visible = true
	task.delay(3, function()
		if noticeToken == token and hintLabel then
			hintLabel.Visible = placementKey ~= nil
			if placementKey then
				local cfg = Config.Buildings[placementKey]
				hintLabel.Text = cfg and (cfg.DisplayName .. "  |  Left click slot to place  |  Q cancel") or ""
			end
		end
	end)
end

local function isMouseOverGui()
	local pos = UserInputService:GetMouseLocation()
	local objects = player.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
	return #objects > 0
end

local function getMouseRaycast(exclude)
	camera = Workspace.CurrentCamera
	local pos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}
	params.IgnoreWater = true
	return Workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
end

local function getSlotFromState(slotId)
	if not localState or type(localState.slots) ~= "table" then
		return nil
	end
	for _, slot in ipairs(localState.slots) do
		if slot.id == slotId then
			return slot
		end
	end
	return nil
end

local function getSlotFromWorldPosition(position)
	if typeof(position) ~= "Vector3" or not localState or type(localState.slots) ~= "table" then
		return nil
	end
	for _, slot in ipairs(localState.slots) do
		if not slot.occupied then
			local slotPos = toVector3(slot.position)
			local slotSize = toVector3(slot.size)
			if slotPos and slotSize then
				local insideX = math.abs(position.X - slotPos.X) <= slotSize.X * 0.5
				local insideZ = math.abs(position.Z - slotPos.Z) <= slotSize.Z * 0.5
				if insideX and insideZ then
					return slot
				end
			end
		end
	end
	return nil
end

local function findSlotPart(instance)
	local current = instance
	while current and current ~= Workspace do
		if current:GetAttribute("BuildSlot") == true then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function setMenuOpen(open)
	menuOpen = open == true
	if not menuFrame then
		return
	end
	local target = menuOpen and UDim2.new(1, -16, 0.5, 0) or UDim2.new(1, 340, 0.5, 0)
	TweenService:Create(menuFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target }):Play()
end

local function destroyGhost()
	if placementGhost then
		placementGhost:Destroy()
		placementGhost = nil
	end
end

local function stopPlacement()
	placementKey = nil
	currentSlotId = nil
	currentPlacementValid = false
	setPlacementActive(false)
	destroyGhost()
	if placementConn then
		placementConn:Disconnect()
		placementConn = nil
	end
	if hintLabel then
		hintLabel.Visible = false
	end
end

local function updatePlacementGhost()
	if not placementKey or not placementGhost then
		return
	end
	local cfg = Config.Buildings[placementKey]
	if not cfg then
		stopPlacement()
		return
	end
	currentSlotId = nil
	currentPlacementValid = false
	local exclude = { placementGhost }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local result = getMouseRaycast(exclude)
	if not result then
		placementGhost.Color = Theme.danger
		return
	end
	local slotPart = findSlotPart(result.Instance)
	local slot = nil
	if slotPart and slotPart:GetAttribute("OwnerUserId") == player.UserId then
		slot = getSlotFromState(slotPart:GetAttribute("CitySlotId"))
	end
	slot = slot or getSlotFromWorldPosition(result.Position)
	if slot and not slot.occupied then
		local slotPos = toVector3(slot.position)
		local slotSize = toVector3(slot.size)
		if slotPos and slotSize then
			local topY = slotPos.Y + slotSize.Y * 0.5
			placementGhost.Size = cfg.Size
			placementGhost.CFrame = CFrame.new(slotPos.X, topY + cfg.Size.Y * 0.5, slotPos.Z)
			placementGhost.Color = Theme.success
			currentSlotId = slot.id
			currentPlacementValid = true
			return
		end
	end
	local p = result.Position
	placementGhost.Size = cfg.Size
	placementGhost.CFrame = CFrame.new(p.X, p.Y + cfg.Size.Y * 0.5, p.Z)
	placementGhost.Color = Theme.danger
end

local function startPlacement(buildingKey)
	local cfg = Config.Buildings[buildingKey]
	if not cfg or not localState or not localState.cityPlaced then
		showNotice("Found a city before placing buildings.")
		return
	end
	stopPlacement()
	placementKey = buildingKey
	placementGhost = Instance.new("Part")
	placementGhost.Name = "BuildPlacementGhost"
	placementGhost.Anchored = true
	placementGhost.CanCollide = false
	placementGhost.CanQuery = false
	placementGhost.Material = Enum.Material.ForceField
	placementGhost.Color = Theme.success
	placementGhost.Transparency = 0.42
	placementGhost.Size = cfg.Size
	placementGhost.Parent = Workspace
	if hintLabel then
		hintLabel.Text = cfg.DisplayName .. "  |  Left click slot to place  |  Q cancel"
		hintLabel.Visible = true
	end
	setPlacementActive(true)
	setMenuOpen(false)
	placementConn = RunService.RenderStepped:Connect(updatePlacementGhost)
end

local function handlePlacementClick()
	if not placementKey or not currentPlacementValid or not currentSlotId then
		showNotice("Choose an empty unlocked city slot.")
		return
	end
	actionRemote:FireServer("PlaceBuilding", {
		BuildingKey = placementKey,
		SlotId = currentSlotId,
	})
	stopPlacement()
end

local function clearMenuButtons()
	if not menuList then
		return
	end
	for _, child in ipairs(menuList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function makeMenuButton(text, callback, subtle, bookStyle)
	local btn = mk("TextButton", {
		BackgroundColor3 = subtle and Theme.slotInner or Theme.slotOuter,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(1, 0, 0, bookStyle and 78 or 72),
		AutoButtonColor = callback ~= nil,
		Text = "",
		Parent = menuList,
	})
	addCorner(btn, 8)
	addStroke(btn, Theme.gilt, 1.2, subtle and 0.35 or 0.15)
	if bookStyle then
		local badge = mk("Frame", {
			BackgroundColor3 = Theme.panelTop,
			BackgroundTransparency = 0.04,
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.fromOffset(48, 54),
			Parent = btn,
		})
		addCorner(badge, 6)
		addStroke(badge, Theme.gilt, 1, 0.22)
		mk("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold,
			TextColor3 = Theme.gilt,
			TextScaled = true,
			Text = "BOOK",
			Parent = badge,
		})
	end
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = bookStyle and UDim2.fromOffset(68, 8) or UDim2.fromOffset(12, 8),
		Size = bookStyle and UDim2.new(1, -80, 1, -16) or UDim2.new(1, -24, 1, -16),
		Font = Enum.Font.GothamBold,
		TextColor3 = callback and Theme.text or Theme.subtleText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		TextScaled = true,
		Text = text,
		Parent = btn,
	})
	if callback then
		btn.Activated:Connect(callback)
	end
	return btn
end

local function makeRecipeCard(buildingKey, cfg, data)
	local recipe = (data and data.recipe and data.recipe.Items) or (cfg.Recipe and cfg.Recipe.Items) or {}
	local progress = (data and data.recipeProgress) or {}
	local keys = {}
	for itemId in pairs(recipe) do table.insert(keys, itemId) end
	table.sort(keys)
	local height = data.completed and 86 or (104 + #keys * 34)
	local card = mk("Frame", {
		BackgroundColor3 = Theme.slotInner,
		BackgroundTransparency = 0.04,
		Size = UDim2.new(1, 0, 0, height),
		Parent = menuList,
	})
	addCorner(card, 8)
	addStroke(card, Theme.gilt, 1.1, data.completed and 0.32 or 0.16)
	local badge = mk("Frame", {
		BackgroundColor3 = Theme.panelTop,
		BackgroundTransparency = 0.04,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(48, 52),
		Parent = card,
	})
	addCorner(badge, 6)
	addStroke(badge, Theme.gilt, 1, 0.22)
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.gilt,
		TextScaled = true,
		Text = "BOOK",
		Parent = badge,
	})
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(68, 8),
		Size = UDim2.new(1, -80, 0, 44),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextScaled = true,
		Text = cfg.DisplayName .. "\n" .. (data.completed and "Complete" or "Recipe"),
		Parent = card,
	})
	if data.completed then
		return card
	end
	for index, itemId in ipairs(keys) do
		local required = math.max(1, math.floor(tonumber(recipe[itemId]) or 1))
		local added = math.clamp(math.floor(tonumber(progress[itemId]) or 0), 0, required)
		local row = mk("Frame", {
			BackgroundColor3 = Theme.panelBg,
			BackgroundTransparency = 0.18,
			Position = UDim2.fromOffset(10, 66 + (index - 1) * 34),
			Size = UDim2.new(1, -20, 0, 30),
			Parent = card,
		})
		addCorner(row, 6)
		mk("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -52, 1, 0),
			Font = Enum.Font.GothamMedium,
			TextColor3 = Theme.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
			Text = itemDisplayName(itemId) .. "  " .. tostring(added) .. "/" .. tostring(required),
			Parent = row,
		})
		local plus = mk("TextButton", {
			BackgroundColor3 = added >= required and Theme.slotOuter or Theme.success,
			BackgroundTransparency = added >= required and 0.35 or 0.08,
			Position = UDim2.new(1, -38, 0, 4),
			Size = UDim2.fromOffset(30, 22),
			AutoButtonColor = added < required,
			Font = Enum.Font.GothamBold,
			TextColor3 = Theme.text,
			TextScaled = true,
			Text = "+",
			Parent = row,
		})
		addCorner(plus, 5)
		if added < required then
			plus.Activated:Connect(function()
				actionRemote:FireServer("ContributeRecipe", { BuildingKey = buildingKey, ItemId = itemId })
			end)
		end
	end
	return card
end

local function sortedBuildingKeys()
	local keys = {}
	for key in pairs(Config.Buildings) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local ca = Config.Buildings[a]
		local cb = Config.Buildings[b]
		return (ca.Order or 999) < (cb.Order or 999)
	end)
	return keys
end

local function showBuildingInBuildMenu(key, cfg)
	if not cfg then return false end
	if cfg.ShowInBuildMenu == false or cfg.IsMonolith == true then return false end
	local text = string.lower(tostring(key or "") .. " " .. tostring(cfg.DisplayName or ""))
	if text:find("monolith", 1, true) then return false end
	return true
end

local function formatCoin(value)
	if Config.FormatCurrency then
		return Config.FormatCurrency(value)
	end
	return tostring(math.max(0, math.floor(tonumber(value) or 0)))
end

local function clearContainer(container)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function findBuildingInstance(target)
	local instanceId
	local buildingKey
	if typeof(target) == "Instance" then
		instanceId = target:GetAttribute("BuildingInstanceId")
		buildingKey = target:GetAttribute("BuildingKey")
	else
		instanceId = target
	end
	instanceId = instanceId and tostring(instanceId) or ""
	buildingKey = buildingKey and tostring(buildingKey) or ""
	for _, building in ipairs((localState and localState.buildingInstances) or {}) do
		if instanceId ~= "" and tostring(building.id) == instanceId then
			return building
		end
		if instanceId ~= "" and tostring(building.buildingKey) == instanceId then
			return building
		end
		if buildingKey ~= "" and tostring(building.buildingKey) == buildingKey then
			return building
		end
	end
	return nil
end

local function setManageTooltip(text)
	if manageTooltip then
		manageTooltip.Text = tostring(text or "")
		manageTooltip.Visible = text ~= nil and text ~= ""
	end
end

local function makeRequirementCard(itemId, required, added, onAdd)
	local def = ItemCatalog.Get and ItemCatalog.Get(itemId)
	local displayName = (def and def.DisplayName) or tostring(itemId)
	local iconKey = (def and def.Icon) or tostring(itemId)
	local card = mk("Frame", {
		Size = UDim2.fromOffset(92, 128),
		BackgroundColor3 = Theme.slotInner,
		BackgroundTransparency = 0.04,
		Parent = manageList,
	})
	addCorner(card, 8)
	addStroke(card, Theme.gilt, 1, 0.2)
	local icon = mk("ImageButton", {
		Position = UDim2.fromOffset(13, 9),
		Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.06,
		AutoButtonColor = false,
		Image = "",
		Parent = card,
	})
	addCorner(icon, 7)
	ImageCatalog.SetImage(icon, iconKey)
	icon.MouseEnter:Connect(function()
		setManageTooltip(displayName .. "  " .. tostring(math.floor(added or 0)) .. "/" .. tostring(math.floor(required or 0)))
	end)
	icon.MouseLeave:Connect(function()
		setManageTooltip(nil)
	end)
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 72),
		Size = UDim2.new(1, -16, 0, 16),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = tostring(math.floor(added or 0)) .. "/" .. tostring(math.floor(required or 0)),
		Parent = card,
	})
	local plus = mk("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(60, 26),
		BackgroundColor3 = onAdd and Theme.success or Theme.slotOuter,
		BackgroundTransparency = onAdd and 0.08 or 0.32,
		AutoButtonColor = onAdd ~= nil,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "+",
		Parent = card,
	})
	addCorner(plus, 6)
	if onAdd then
		plus.Activated:Connect(onAdd)
	end
	return card
end

local function costRequirements(cost)
	local requirements = {}
	cost = type(cost) == "table" and cost or {}
	local coin = math.max(0, math.floor(tonumber(cost.Coin) or 0))
	if coin > 0 then
		requirements.Coin = coin
	end
	for itemId, amount in pairs(cost.Items or {}) do
		amount = math.max(0, math.floor(tonumber(amount) or 0))
		if amount > 0 then
			requirements[tostring(itemId)] = (requirements[tostring(itemId)] or 0) + amount
		end
	end
	return requirements
end

local function costProgressComplete(cost, progress)
	progress = type(progress) == "table" and progress or {}
	for itemId, required in pairs(costRequirements(cost)) do
		if math.floor(tonumber(progress[itemId]) or 0) < required then
			return false
		end
	end
	return true
end

local function costProgressPercent(cost, progress)
	progress = type(progress) == "table" and progress or {}
	local total = 0
	local filled = 0
	for itemId, required in pairs(costRequirements(cost)) do
		total += required
		filled += math.clamp(math.floor(tonumber(progress[itemId]) or 0), 0, required)
	end
	if total <= 0 then
		return 100
	end
	return math.floor(math.clamp(filled / total, 0, 1) * 100 + 0.5)
end

local function makeCostRequirementCards(cost, progress, locked, onAdd)
	progress = type(progress) == "table" and progress or {}
	local requirements = costRequirements(cost)
	if requirements.Coin then
		local added = math.clamp(math.floor(tonumber(progress.Coin) or 0), 0, requirements.Coin)
		makeRequirementCard("Coin", requirements.Coin, added, (not locked and added < requirements.Coin and onAdd) and function()
			onAdd("Coin")
		end or nil)
	end
	local keys = {}
	for itemId in pairs(requirements) do
		if itemId ~= "Coin" then
			table.insert(keys, itemId)
		end
	end
	table.sort(keys)
	for _, itemId in ipairs(keys) do
		local required = requirements[itemId]
		local added = math.clamp(math.floor(tonumber(progress[itemId]) or 0), 0, required)
		makeRequirementCard(itemId, required, added, (not locked and added < required and onAdd) and function()
			onAdd(itemId)
		end or nil)
	end
end

local function closeLeftPanelsForManage()
	if promptFrame then
		promptFrame.Visible = false
		activePrompt = nil
	end
	if type(_G.CloseCraftingStationPanel) == "function" then
		_G.CloseCraftingStationPanel()
	end
	setMenuOpen(false)
end

local function closeManagePanel()
	if manageFrame then
		manageFrame.Visible = false
	end
	activeManage = nil
	manageActionCallback = nil
	setManageTooltip(nil)
end

local function refreshManagePanel()
	if not manageFrame or not activeManage then
		return
	end
	clearContainer(manageList)
	setManageTooltip(nil)
	manageActionCallback = nil
	manageActionButton.Visible = false
	local kind = activeManage.kind
	if kind == "City" then
		local claimed = localState and localState.cityPlaced
		manageTitle.Text = claimed and ((localState.cityName or "City") .. " Management") or "City Management"
		if not claimed then
			manageStatus.Text = "Found the city before upgrading."
			return
		end
		local atMax = (localState.cityLevel or 0) >= (localState.cityMaxLevel or Config.City.MaxLevel)
		local cost = localState.upgradeCost or Config.City.UpgradeCost
		local progress = localState.upgradeProgress or {}
		local started = math.floor(tonumber(localState.upgradeStartedAt) or 0) > 0
		local filled = costProgressPercent(cost, progress)
		manageStatus.Text = atMax and string.format("Level %d / %d  |  Max", localState.cityLevel or 1, localState.cityMaxLevel or Config.City.MaxLevel) or string.format("Level %d / %d  |  Upgrade %d%% filled", localState.cityLevel or 1, localState.cityMaxLevel or Config.City.MaxLevel, filled)
		if not atMax then
			makeCostRequirementCards(cost, progress, started, function(itemId)
				actionRemote:FireServer("ContributeCityUpgrade", { ItemId = itemId })
			end)
		end
		local complete = costProgressComplete(cost, progress)
		manageActionButton.Visible = true
		manageActionButton.Text = atMax and "Max Level" or (started and "Upgrading" or (complete and "Start" or "Upgrade"))
		manageActionButton.AutoButtonColor = not atMax and not started
		manageActionButton.BackgroundColor3 = (atMax or started) and Theme.slotOuter or Theme.success
		manageActionCallback = function()
			if atMax then
				return
			end
			if started then
				showNotice("City upgrade is already in progress.")
			elseif complete then
				actionRemote:FireServer("UpgradeCity")
			else
				showNotice("Press + under each requirement before starting the upgrade.")
			end
		end
		return
	end
	local building = findBuildingInstance(activeManage.instanceId or activeManage.target)
	if not building then
		manageTitle.Text = "Building Management"
		manageStatus.Text = "Building no longer exists."
		return
	end
	activeManage.instanceId = building.id
	local cfg = Config.Buildings[building.buildingKey]
	if not cfg then
		manageTitle.Text = "Building Management"
		manageStatus.Text = "Unknown building."
		return
	end
	manageTitle.Text = cfg.DisplayName or building.displayName or "Building"
	manageStatus.Text = string.format("Tier %d / %d  |  %s", building.tier or 1, building.maxTier or localState.buildingMaxTier or Config.Building.MaxTier, building.completed and "Ready" or "Fill Recipe")
	if building.completed then
		local atMax = (building.tier or 1) >= (building.maxTier or localState.buildingMaxTier or Config.Building.MaxTier)
		local cost = building.upgradeCost or Config.GetBuildingUpgradeCost(building.tier or 1)
		local progress = building.upgradeProgress or {}
		local started = math.floor(tonumber(building.upgradeStartedAt) or 0) > 0
		local filled = costProgressPercent(cost, progress)
		manageStatus.Text = atMax and string.format("Tier %d / %d  |  Max", building.tier or 1, building.maxTier or localState.buildingMaxTier or Config.Building.MaxTier) or string.format("Tier %d / %d  |  Upgrade %d%% filled", building.tier or 1, building.maxTier or localState.buildingMaxTier or Config.Building.MaxTier, filled)
		if not atMax then
			makeCostRequirementCards(cost, progress, started, function(itemId)
				actionRemote:FireServer("ContributeBuildingUpgrade", { BuildingInstanceId = building.id, BuildingKey = building.buildingKey, ItemId = itemId })
			end)
		end
		local complete = costProgressComplete(cost, progress)
		manageActionButton.Visible = true
		manageActionButton.Text = atMax and "Max Tier" or (started and "Upgrading" or (complete and "Start" or "Upgrade"))
		manageActionButton.AutoButtonColor = not atMax and not started
		manageActionButton.BackgroundColor3 = (atMax or started) and Theme.slotOuter or Theme.success
		manageActionCallback = function()
			if atMax then
				return
			end
			if started then
				showNotice(cfg.DisplayName .. " upgrade is already in progress.")
			elseif complete then
				actionRemote:FireServer("UpgradeBuilding", { BuildingInstanceId = building.id })
			else
				showNotice("Press + under each requirement before starting the upgrade.")
			end
		end
	else
		local recipe = (building.recipe and building.recipe.Items) or (cfg.Recipe and cfg.Recipe.Items) or {}
		local progress = building.recipeProgress or {}
		local keys = {}
		for itemId in pairs(recipe) do table.insert(keys, itemId) end
		table.sort(keys)
		for _, itemId in ipairs(keys) do
			local required = math.max(1, math.floor(tonumber(recipe[itemId]) or 1))
			local added = math.clamp(math.floor(tonumber(progress[itemId]) or 0), 0, required)
			makeRequirementCard(itemId, required, added, added < required and function()
				actionRemote:FireServer("ContributeRecipe", { BuildingInstanceId = building.id, BuildingKey = building.buildingKey, ItemId = itemId })
			end or nil)
		end
	end
end

local function openCityManagePanel()
	closeLeftPanelsForManage()
	activeManage = { kind = "City" }
	if manageFrame then
		manageFrame.Visible = true
		refreshManagePanel()
	end
end

local function openBuildingManagePanel(target)
	closeLeftPanelsForManage()
	activeManage = { kind = "Building", target = target, instanceId = typeof(target) == "Instance" and target:GetAttribute("BuildingInstanceId") or target }
	if manageFrame then
		manageFrame.Visible = true
		refreshManagePanel()
	end
	return true
end

_G.OpenBuildingManagePanel = openBuildingManagePanel
_G.CloseBuildManagePanel = closeManagePanel

local function refreshPromptText()
	if not promptStatus then
		return
	end
	local claimed = localState and localState.cityPlaced
	local upkeep = (localState and localState.upkeep) or {}
	local taxes = (localState and localState.taxes) or {}
	local cityName = (localState and localState.cityName) or "Unfounded City"
	if promptTitle then
		promptTitle.Text = claimed and cityName or "Unfounded City"
	end
	if promptNameBox and not promptNameBox:IsFocused() then
		promptNameBox.Text = claimed and cityName or ""
		promptNameBox.PlaceholderText = claimed and "City name" or "Found city first"
	end
	promptStatus.Text = claimed and string.format("Level %d / %d", localState.cityLevel or 1, localState.cityMaxLevel or Config.City.MaxLevel) or "No owner yet"
	if promptOwner then
		promptOwner.Text = "Owner: " .. (claimed and tostring(localState.ownerName or player.Name) or "None")
	end
	if promptTaxes then
		promptTaxes.Text = "Taxes Available\n" .. formatCoin(taxes.Available or taxes.Collected or 0) .. " Coin"
	end
	if promptUpkeep then
		promptUpkeep.Text = "Upkeep Due\n" .. formatCoin(upkeep.Due or 0) .. " Coin"
	end
	if promptCost then
		promptCost.Text = claimed and "Founded" or ("Founding Cost: " .. costText((localState and localState.claimCost) or Config.City.ClaimCost))
	end
	if promptTaxClaimButton then
		local amount = math.max(0, math.floor(tonumber(taxes.Available or 0) or 0))
		promptTaxClaimButton.Visible = claimed == true
		promptTaxClaimButton.Active = claimed == true and amount > 0
		promptTaxClaimButton.AutoButtonColor = promptTaxClaimButton.Active
		promptTaxClaimButton.BackgroundColor3 = amount > 0 and Theme.success or Theme.slotOuter
	end
	if promptRenameButton then
		promptRenameButton.Active = claimed == true
		promptRenameButton.AutoButtonColor = claimed == true
		promptRenameButton.BackgroundColor3 = claimed and Theme.success or Theme.slotInner
	end
end

local function updatePromptButton()
	if not promptClaimButton then
		return
	end
	local claimed = localState and localState.cityPlaced
	promptClaimButton.Visible = not claimed
	promptClaimButton.Text = "Found City"
	promptClaimButton.Active = not claimed
	promptClaimButton.AutoButtonColor = not claimed
	promptClaimButton.BackgroundColor3 = Theme.success
	if promptManageButton then
		promptManageButton.Visible = claimed == true
		promptManageButton.Active = claimed == true
		promptManageButton.AutoButtonColor = claimed == true
	end
	refreshPromptText()
end

local function refreshMenu()
	clearMenuButtons()
	if not statusLabel or not menuList then
		return
	end
	if not localState or not localState.cityPlaced then
		statusLabel.Text = "City not founded | catalog only"
	else
		statusLabel.Text = string.format("City Level %d / %d", localState.cityLevel or 1, localState.cityMaxLevel or Config.City.MaxLevel)
	end
	for _, key in ipairs(sortedBuildingKeys()) do
		local cfg = Config.Buildings[key]
		if showBuildingInBuildMenu(key, cfg) then
			local data = localState and localState.buildings and localState.buildings[key]
			local cost = (data and data.costs) or cfg.PlaceCost or cfg.Costs
			makeMenuButton(cfg.DisplayName .. "\n" .. costText(cost), function()
				startPlacement(key)
			end, false, true)
		end
	end
	updatePromptButton()
end

local function buildGui()
	gui = mk("ScreenGui", {
		Name = "BuildSystemUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 8000,
		Parent = player:WaitForChild("PlayerGui"),
	})
	menuFrame = mk("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 340, 0.5, 0),
		Size = UDim2.new(0.92, 0, 0, 486),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.08,
		Parent = gui,
	})
	addCorner(menuFrame, 12)
	addStroke(menuFrame, Theme.gilt, 1.5, 0.12)
	addGradient(menuFrame)
	mk("UISizeConstraint", { MaxSize = Vector2.new(312, 486), MinSize = Vector2.new(280, 420), Parent = menuFrame })

	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.new(1, -28, 0, 32),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "BUILD",
		Parent = menuFrame,
	})
	statusLabel = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 48),
		Size = UDim2.new(1, -28, 0, 24),
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.subtleText,
		TextScaled = true,
		Text = "",
		Parent = menuFrame,
	})
	menuList = mk("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 82),
		Size = UDim2.new(1, -28, 1, -96),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		Parent = menuFrame,
	})
	mk("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menuList,
	})

	hintLabel = mk("TextLabel", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.new(0.9, 0, 0, 42),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "",
		Parent = gui,
	})
	addCorner(hintLabel, 8)
	addStroke(hintLabel, Theme.gilt, 1.3, 0.15)
	mk("UISizeConstraint", { MaxSize = Vector2.new(620, 42), MinSize = Vector2.new(260, 36), Parent = hintLabel })

	manageFrame = mk("Frame", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.92, 0, 0, 222),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.05,
		Parent = gui,
	})
	addCorner(manageFrame, 12)
	addStroke(manageFrame, Theme.gilt, 1.5, 0.12)
	addGradient(manageFrame)
	mk("UISizeConstraint", { MaxSize = Vector2.new(640, 222), MinSize = Vector2.new(300, 196), Parent = manageFrame })
	manageTitle = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -124, 0, 28),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Management",
		Parent = manageFrame,
	})
	manageStatus = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -124, 0, 20),
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.subtleText,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = manageFrame,
	})
	local closeManage = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "X",
		Parent = manageFrame,
	})
	addCorner(closeManage, 7)
	addStroke(closeManage, Theme.gilt, 1, 0.2)
	closeManage.Activated:Connect(function()
		closeManagePanel()
	end)
	manageList = mk("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(1, -154, 1, -94),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		Parent = manageFrame,
	})
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = manageList })
	manageActionButton = mk("TextButton", {
		Visible = false,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(124, 42),
		BackgroundColor3 = Theme.success,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "Upgrade",
		Parent = manageFrame,
	})
	addCorner(manageActionButton, 8)
	addStroke(manageActionButton, Theme.gilt, 1.1, 0.18)
	manageActionButton.Activated:Connect(function()
		if manageActionCallback then
			manageActionCallback()
		end
	end)
	manageTooltip = mk("TextLabel", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -250),
		Size = UDim2.fromOffset(360, 30),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.06,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "",
		Parent = gui,
	})
	addCorner(manageTooltip, 7)
	addStroke(manageTooltip, Theme.gilt, 1, 0.16)

	promptFrame = mk("Frame", {
		Visible = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(0.92, 0, 0, 520),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.05,
		Parent = gui,
	})
	addCorner(promptFrame, 12)
	addStroke(promptFrame, Theme.gilt, 1.5, 0.12)
	addGradient(promptFrame)
	mk("UISizeConstraint", { MaxSize = Vector2.new(348, 520), MinSize = Vector2.new(300, 470), Parent = promptFrame })
	promptTitle = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -56, 0, 34),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Unfounded City",
		Parent = promptFrame,
	})
	local closePanel = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "X",
		Parent = promptFrame,
	})
	addCorner(closePanel, 7)
	addStroke(closePanel, Theme.gilt, 1, 0.2)
	closePanel.Activated:Connect(function()
		promptFrame.Visible = false
		activePrompt = nil
	end)
	promptStatus = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, 24),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.gilt,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "No owner yet",
		Parent = promptFrame,
	})
	promptOwner = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 78),
		Size = UDim2.new(1, -32, 0, 24),
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.subtleText,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Owner: None",
		Parent = promptFrame,
	})
	promptNameBox = mk("TextBox", {
		Position = UDim2.fromOffset(16, 116),
		Size = UDim2.new(1, -118, 0, 36),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.text,
		PlaceholderColor3 = Theme.subtleText,
		TextScaled = true,
		Text = "",
		PlaceholderText = "Found city first",
		Parent = promptFrame,
	})
	addCorner(promptNameBox, 8)
	addStroke(promptNameBox, Theme.gilt, 1, 0.25)
	promptRenameButton = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 116),
		Size = UDim2.fromOffset(82, 36),
		BackgroundColor3 = Theme.slotInner,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "Rename",
		Parent = promptFrame,
	})
	addCorner(promptRenameButton, 8)
	addStroke(promptRenameButton, Theme.gilt, 1, 0.22)
	promptRenameButton.Activated:Connect(function()
		if not (localState and localState.cityPlaced) then
			showNotice("Found a city before renaming it.")
			return
		end
		actionRemote:FireServer("RenameCity", { CityName = promptNameBox and promptNameBox.Text or "" })
	end)
	promptTaxes = mk("TextLabel", {
		Position = UDim2.fromOffset(16, 170),
		Size = UDim2.new(1, -124, 0, 58),
		BackgroundColor3 = Theme.slotInner,
		BackgroundTransparency = 0.06,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextWrapped = true,
		Text = "Taxes Available\n0 Coin",
		Parent = promptFrame,
	})
	addCorner(promptTaxes, 8)
	addStroke(promptTaxes, Theme.gilt, 1, 0.2)
	promptTaxClaimButton = mk("TextButton", {
		Visible = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 170),
		Size = UDim2.fromOffset(92, 58),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "Claim",
		Parent = promptFrame,
	})
	addCorner(promptTaxClaimButton, 8)
	addStroke(promptTaxClaimButton, Theme.gilt, 1, 0.2)
	promptTaxClaimButton.Activated:Connect(function()
		actionRemote:FireServer("ClaimCityTaxes")
	end)
	local upkeepCard = mk("Frame", {
		Position = UDim2.fromOffset(16, 244),
		Size = UDim2.new(1, -32, 0, 122),
		BackgroundColor3 = Theme.slotInner,
		BackgroundTransparency = 0.06,
		Parent = promptFrame,
	})
	addCorner(upkeepCard, 8)
	addStroke(upkeepCard, Theme.gilt, 1, 0.2)
	local itemSlot = mk("Frame", {
		Position = UDim2.fromOffset(14, 16),
		Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.04,
		Parent = upkeepCard,
	})
	addCorner(itemSlot, 8)
	addStroke(itemSlot, Theme.gilt, 1, 0.16)
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.subtleText,
		TextScaled = true,
		Text = "Item",
		Parent = itemSlot,
	})
	promptUpkeep = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(92, 16),
		Size = UDim2.new(1, -106, 0, 66),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Upkeep Due\n0 Coin",
		Parent = upkeepCard,
	})
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 88),
		Size = UDim2.new(1, -28, 0, 24),
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.subtleText,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Upkeep item slot",
		Parent = upkeepCard,
	})
	promptCost = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 396),
		Size = UDim2.new(1, -32, 0, 34),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.gilt,
		TextScaled = true,
		TextWrapped = true,
		Text = "Founding Cost: " .. costText(Config.City.ClaimCost),
		Parent = promptFrame,
	})
	promptManageButton = mk("TextButton", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -32, 0, 44),
		BackgroundColor3 = Theme.success,
		BackgroundTransparency = 0.12,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "Manage",
		Parent = promptFrame,
	})
	addCorner(promptManageButton, 8)
	addStroke(promptManageButton, Theme.gilt, 1.1, 0.18)
	promptManageButton.Activated:Connect(openCityManagePanel)
	promptClaimButton = mk("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -32, 0, 44),
		BackgroundColor3 = Theme.success,
		BackgroundTransparency = 0.12,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "Found City",
		Parent = promptFrame,
	})
	addCorner(promptClaimButton, 8)
	addStroke(promptClaimButton, Theme.gilt, 1.1, 0.18)
	promptClaimButton.Activated:Connect(function()
		if localState and localState.cityPlaced then
			showNotice("You already founded a city.")
			return
		end
		actionRemote:FireServer("ClaimCity")
	end)

	refreshMenu()
end

local function applyState(packet)
	if type(packet) ~= "table" then
		return
	end
	localState = packet
	refreshMenu()
	if packet.message then
		showNotice(packet.message)
		local message = string.lower(tostring(packet.message))
		if message:find("upgraded to", 1, true) then
			closeManagePanel()
		end
	end
	if placementKey and not packet.cityPlaced then
		stopPlacement()
	end
	updatePromptButton()
	if manageFrame and manageFrame.Visible and activeManage then
		refreshManagePanel()
	end
end

local function showPrompt(prompt)
	if not prompt or prompt:GetAttribute("CityClaimPrompt") ~= true or not promptFrame then
		return
	end
	closeManagePanel()
	setMenuOpen(false)
	if type(_G.CloseCraftingStationPanel) == "function" then
		_G.CloseCraftingStationPanel()
	end
	activePrompt = prompt
	promptTitle.Text = prompt.ObjectText ~= "" and prompt.ObjectText or "City Claim Monolith"
	if promptCost and not (localState and localState.cityPlaced) then
		promptCost.Text = "Founding Cost: " .. (prompt:GetAttribute("ClaimCostText") or costText(Config.City.ClaimCost))
	end
	promptFrame.Visible = true
	updatePromptButton()
end

local function hidePrompt(prompt)
	if prompt == activePrompt and promptFrame then
		promptFrame.Visible = false
		activePrompt = nil
	end
end

local function openMonolithPanel()
	closeManagePanel()
	setMenuOpen(false)
	if type(_G.CloseCraftingStationPanel) == "function" then
		_G.CloseCraftingStationPanel()
	end
	activePrompt = nil
	if promptFrame then
		promptFrame.Visible = true
		updatePromptButton()
	end
end

_G.OpenCityMonolithPanel = openMonolithPanel

local function toggleMenuAction(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if placementKey then
		showNotice("Press Q to cancel placement.")
		return Enum.ContextActionResult.Sink
	end
	refreshMenu()
	setMenuOpen(not menuOpen)
	return Enum.ContextActionResult.Sink
end

local function onInputBegan(input, processed)
	if placementKey then
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not isMouseOverGui() then
			handlePlacementClick()
		elseif input.KeyCode == Enum.KeyCode.Q then
			stopPlacement()
		end
		return
	end
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		setMenuOpen(false)
	end
end

local ok, initialState = pcall(function()
	return requestStateRemote:InvokeServer()
end)
localState = ok and initialState or { cityPlaced = false, cityLevel = 0, buildings = {}, slots = {} }

buildGui()
applyState(localState)
stateRemote.OnClientEvent:Connect(applyState)
openMonolithRemote.OnClientEvent:Connect(openMonolithPanel)
ContextActionService:BindAction("ToggleBuildMenu", toggleMenuAction, false, Enum.KeyCode.B)
UserInputService.InputBegan:Connect(onInputBegan)
ProximityPromptService.PromptShown:Connect(showPrompt)
ProximityPromptService.PromptHidden:Connect(hidePrompt)
