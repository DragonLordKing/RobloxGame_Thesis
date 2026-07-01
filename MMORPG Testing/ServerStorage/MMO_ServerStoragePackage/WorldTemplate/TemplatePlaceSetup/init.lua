--[[
Name: TemplatePlaceSetup
Class: ModuleScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.WorldTemplate.TemplatePlaceSetup
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage, ServerScriptService, ServerStorage, Workspace
Requires:
  - local PackageManifest = require(script.Parent:WaitForChild("PackageManifest"))
  - table.insert(lines, "return require(target)")
Functions: ensure, resolvePath, escapeString, aliasSource, copySegments, ensureAliasModule, ensureAliasFolder, hasModuleDescendant, mirrorAliases, TemplatePlaceSetup.GetPackageRoots, TemplatePlaceSetup.ValidatePackageRoots, TemplatePlaceSetup.EnsureCompatibilityAliases, TemplatePlaceSetup.EnsureWorkspaceFolders, TemplatePlaceSetup.EnsureTemplatePlace, TemplatePlaceSetup.SetMapIdentity
Clean source lines: 247
]]
local TemplatePlaceSetup = {}

local PackageManifest = require(script.Parent:WaitForChild("PackageManifest"))

TemplatePlaceSetup.ReadMe = [[MMO multi-place template checklist

Use the central Dev place as the source-of-truth package editor. Save/copy new map places inside the same experience, then insert/update the five shared package roots.

1. Shared packages to insert/update in every map place:
   - ReplicatedStorage.MMO_ReplicatedPackage: shared config, item catalogs, remotes, client modules, visual assets, NPC rigs, node art, mount assets, and WorldPlaceConfig.
   - ServerScriptService.MMO_ServerPackage: server services for combat, NPCs, gathering, chests, parties, teleport, persistence, and world runtime.
   - ServerStorage.MMO_ServerStoragePackage: server-only bindables, UI templates/installers, template helpers, package manifest, and examples.
   - StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage: client controllers, HUD scripts, CoreGui overrides, map UI controllers, and background terrain streaming warmup.
   - StarterPlayer.StarterCharacterScripts.MMO_StarterCharacterPackage: character-local scripts and visuals.
   ReplicatedFirst.MapTeleportLoadingController stays direct, not packaged, because Roblox loading/teleport GUI code must run early.

2. Place identity:
   - Set game attribute MapKey to the key in WorldPlaceConfig.Maps, for example template_zone.
   - Set ZoneType in WorldPlaceConfig.Maps for that key: Safe, Warn, Danger, or Death.
   - Set RegionKey for gameplay timers only; physical Roblox server region is not selectable.
   - After publishing the new place, copy its numeric place id into WorldPlaceConfig.Maps[mapKey].PlaceIdDev for Dev and PlaceIdProd for Prod.

3. Workspace folders this helper creates:
   - Workspace.WorldSpawns: arrival spawn markers. Set SpawnId or name them Spawn1, Spawn_WestRoad, etc.
   - Workspace.WorldPortals: optional organization folder for exit parts.
   - Workspace.WorldMapMarkers: optional designer markers for map materials when needed.
   - Workspace.GatheringZones: optional simple gathering node spawn markers. Tagged gathering marker parts can also live inside structures.
   - Workspace.SpawnNPC: optional simple NPC spawn markers. Tagged NPC marker parts can also live inside structures.
   - Workspace.WorldCities: runtime city models.

4. Map generation:
   - Run the world generation plugin in Studio for each map place.
   - The current generator does not need Workspace.GeneratedMap.MapConfig. The local N map bakes visible terrain directly; GeneratedMap/MapConfig is only legacy data if an old generator creates it.
   - Map-only content stays unique per place: terrain, generated buildings, authored roads, decorations, exit parts, NPC/gathering markers, and WorldSpawns.

5. Connecting two places:
   - In the west/central map, make ExitEast and set WorldExit = true, TargetMapKey = the east map key, TargetSpawnId = the spawn id in the east map.
   - In the east map, make ExitWest and set WorldExit = true, TargetMapKey = the west map key, TargetSpawnId = the spawn id in the west map.
   - Optional: PortalId, TargetZoneType. If TargetMapKey exists, TargetZoneType can come from WorldPlaceConfig.
   - The exit may have an ObjectValue named Spawn or TargetSpawn for authoring convenience, but teleport uses TargetSpawnId across places.

6. N and M maps:
   - N bakes local terrain, crops Void, shows player/party dots, and labels exits.
   - The top-left header shows map name and a purity chip. Purity odds come from ResourceTierMin/ResourceTierMax and GatheringConfig tier weights.
   - M reads WorldPlaceConfig.Maps: WorldX, WorldY, DominantMaterial, Ocean, Desert, Mountains, Roads, RegionKey.

7. Gathering nodes:
   - Add BasePart markers under Workspace.GatheringZones named after GatheringConfig.Zones keys, or tag any BasePart anywhere in Workspace with GatheringZone, GatheringSpawn, or MMO_GatheringZone.
   - For tagged markers inside structures, set GatherZoneKey, ZoneKey, or GatheringZoneKey if the part name is not the GatheringConfig.Zones key.
   - Optional marker attribute NodesPerSpawn overrides the zone config count for that marker.
   - Default Tier 3-5 marker names exist for Ore/Wood/Stone/Fiber/Hide, such as OreT5Spawn1 and StoneT4Spawn1.
   - Tier 1 defaults: 20 max ticks, 2 ticks consumed per 6-second gather, 2 resources awarded, and 2 ticks restored per tick-respawn pulse.
   - TickRespawnSeconds only restores missing ticks while the node is still alive. RerollSeconds controls the periodic purity reroll whether the node is full, partly used, or depleted. TickRespawnSeconds restores missing ticks, even from 0.
   - Tier 1-3 do not roll purity. Tier 4-5 normal maps roll Faint, Kindled, or Ignited only. Ashen Forged is reserved for special/manual places using custom weights.
   - Purity emitter templates live in ReplicatedStorage.MMO_ReplicatedPackage.Assets.PurityEmitters.

8. NPCs and structures:
   - Put NPC spawn markers in Workspace.SpawnNPC, or tag any BasePart anywhere in Workspace with NPCSpawn, NPCSpawnMarker, or MMO_NPCSpawn.
   - Tagged NPC markers use the same attributes: Archetype, Count, Radius, Tier, TierMin, TierMax, and RespawnSeconds.
   - Build structures directly in Workspace as map-only content; marker parts can be children of those structures.

9. Smart chests:
   - Mark chest models/parts with LootChest = true or name them TreasureChestType*.
   - Attribute requirements: RequiredNpcKills, RequiredValorNearby, RequiredValorType = PvE/PvP/Gathering, RequirementRadius, RequirementScope, RequirementMode.
   - Server-scope requirements can light the chest with the white ChestUnlocked emitter when complete.
   - For custom logic, copy ChestRequirementExamples under the chest and edit it.

]]

local function ensure(parent, className, name)
	local inst = parent:FindFirstChild(name)
	if inst and inst.ClassName == className then return inst end
	if inst then inst:Destroy() end
	inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function resolvePath(path)
	local current = game
	for segment in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(segment)
		if not current then
			return nil
		end
	end
	return current
end

local function escapeString(value)
	return tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"')
end

local function aliasSource(serviceName, packageRootName, relSegments)
	local lines = {
		"-- Compatibility alias. Edit the source under " .. packageRootName .. ", not this shim.",
		"local packageRoot = game:GetService(\"" .. escapeString(serviceName) .. "\"):WaitForChild(\"" .. escapeString(packageRootName) .. "\")",
		"local target = packageRoot",
	}
	for _, segment in ipairs(relSegments) do
		table.insert(lines, "target = target:WaitForChild(\"" .. escapeString(segment) .. "\")")
	end
	table.insert(lines, "return require(target)")
	return table.concat(lines, "\n")
end

local function copySegments(segments)
	local copy = {}
	for i, segment in ipairs(segments) do
		copy[i] = segment
	end
	return copy
end

local function ensureAliasModule(aliasParent, aliasName, serviceName, packageRootName, relSegments, report)
	local existing = aliasParent:FindFirstChild(aliasName)
	if existing and not existing:IsA("ModuleScript") then
		if existing:GetAttribute("PackageAliasFolder") then
			existing:Destroy()
		else
			table.insert(report.skipped, aliasParent:GetFullName() .. "." .. aliasName .. " already exists as " .. existing.ClassName)
			return
		end
	end
	local module = aliasParent:FindFirstChild(aliasName)
	if not module then
		module = Instance.new("ModuleScript")
		module.Name = aliasName
		module.Parent = aliasParent
	end
	module:SetAttribute("PackageAlias", true)
	module.Source = aliasSource(serviceName, packageRootName, relSegments)
	report.aliases += 1
end

local function ensureAliasFolder(aliasParent, aliasName, report)
	local existing = aliasParent:FindFirstChild(aliasName)
	if existing and not existing:IsA("Folder") then
		if existing:GetAttribute("PackageAlias") then
			existing:Destroy()
		else
			table.insert(report.skipped, aliasParent:GetFullName() .. "." .. aliasName .. " already exists as " .. existing.ClassName)
			return nil
		end
	end
	local folder = aliasParent:FindFirstChild(aliasName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = aliasName
		folder.Parent = aliasParent
	end
	folder:SetAttribute("PackageAliasFolder", true)
	return folder
end

local function hasModuleDescendant(folder)
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("ModuleScript") then
			return true
		end
	end
	return false
end

local function mirrorAliases(realParent, aliasParent, serviceName, packageRootName, relPrefix, report)
	for _, child in ipairs(realParent:GetChildren()) do
		if child.Name ~= "README" then
			local rel = copySegments(relPrefix)
			table.insert(rel, child.Name)
			if child:IsA("ModuleScript") then
				ensureAliasModule(aliasParent, child.Name, serviceName, packageRootName, rel, report)
			elseif child:IsA("Folder") and hasModuleDescendant(child) then
				local aliasFolder = ensureAliasFolder(aliasParent, child.Name, report)
				if aliasFolder then
					mirrorAliases(child, aliasFolder, serviceName, packageRootName, rel, report)
				end
			end
		end
	end
end

function TemplatePlaceSetup.GetPackageRoots()
	return PackageManifest.PackageRoots
end

function TemplatePlaceSetup.ValidatePackageRoots()
	local missing = {}
	for _, rootInfo in ipairs(PackageManifest.PackageRoots) do
		if not resolvePath(rootInfo.Path) then
			table.insert(missing, rootInfo.Path)
		end
	end
	return #missing == 0, missing
end

function TemplatePlaceSetup.EnsureCompatibilityAliases()
	local specs = {
		{ Service = game:GetService("ReplicatedStorage"), ServiceName = "ReplicatedStorage", PackageRootName = "MMO_ReplicatedPackage" },
		{ Service = game:GetService("ServerScriptService"), ServiceName = "ServerScriptService", PackageRootName = "MMO_ServerPackage" },
		{ Service = game:GetService("ServerStorage"), ServiceName = "ServerStorage", PackageRootName = "MMO_ServerStoragePackage" },
	}
	local report = { aliases = 0, missing = {}, skipped = {} }
	for _, spec in ipairs(specs) do
		local root = spec.Service:FindFirstChild(spec.PackageRootName)
		if root then
			mirrorAliases(root, spec.Service, spec.ServiceName, spec.PackageRootName, {}, report)
		else
			table.insert(report.missing, spec.ServiceName .. "." .. spec.PackageRootName)
		end
	end
	return report
end

function TemplatePlaceSetup.EnsureWorkspaceFolders()
	local Workspace = game:GetService("Workspace")
	ensure(Workspace, "Folder", "WorldSpawns")
	ensure(Workspace, "Folder", "WorldPortals")
	ensure(Workspace, "Folder", "WorldMapMarkers")
	ensure(Workspace, "Folder", "GatheringZones")
	ensure(Workspace, "Folder", "SpawnNPC")
	ensure(Workspace, "Folder", "WorldCities")
end

function TemplatePlaceSetup.EnsureTemplatePlace(mapKey, options)
	options = options or {}
	TemplatePlaceSetup.EnsureWorkspaceFolders()
	TemplatePlaceSetup.SetMapIdentity(mapKey or game:GetAttribute("MapKey") or "testing_grounds")

	local aliasReport = nil
	if options.CreateCompatibilityAliases == true then
		aliasReport = TemplatePlaceSetup.EnsureCompatibilityAliases()
	end

	local rootsValid, missingRoots = TemplatePlaceSetup.ValidatePackageRoots()
	return rootsValid and (not aliasReport or #aliasReport.missing == 0), {
		MissingPackageRoots = missingRoots,
		AliasReport = aliasReport,
	}
end

function TemplatePlaceSetup.SetMapIdentity(mapKey)
	game:SetAttribute("MapKey", tostring(mapKey or "testing_grounds"))
end

return TemplatePlaceSetup
