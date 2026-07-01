--[[
Name: PackageManifest
Class: ModuleScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.WorldTemplate.PackageManifest
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Clean source lines: 45
]]
return {
	ReadMe = [[
Package only the MMO_*Package roots below. They are intentionally coarse so every map place only needs a few shared packages instead of dozens of script packages.

Recommended workflow:
1. In the development experience, right-click each PackageRoots entry below and choose Convert to Package.
2. Keep package names stable. Insert the same package assets into every Dev map place.
3. Edit real scripts, UI templates, remotes, bindables, and visual assets inside the MMO_*Package roots.
4. When scripts or assets change, publish/update the package from the source place, then update package instances in every map place.
5. For production, copy or update the same package versions into the production experience after Dev testing.
6. Keep map-only content out of packages: terrain, generated buildings, authored roads, authored decorations, spawn markers, exit placement, and per-map generated Workspace content stay unique per place.
]],

	PackageRoots = {
		{ Path = "ReplicatedStorage.MMO_ReplicatedPackage", Name = "MMO_ReplicatedPackage", Purpose = "Shared config, catalogs, client modules, world config, remotes, replicated bindables, visual assets, horse template, NPC rigs, node art, and death sack assets." },
		{ Path = "ServerScriptService.MMO_ServerPackage", Name = "MMO_ServerPackage", Purpose = "Server scripts, services, combat, NPCs, progression, gathering, parties, world runtime, and packaged UI installer." },
		{ Path = "ServerStorage.MMO_ServerStoragePackage", Name = "MMO_ServerStoragePackage", Purpose = "Server-only bindables, UI installers, packaged StarterGui templates, template tools, and package manifest." },
		{ Path = "StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage", Name = "MMO_StarterPlayerPackage", Purpose = "Player LocalScripts: camera, input, client boot, status HUD, party HUD, build UI, market UI, and CoreGui overrides." },
		{ Path = "StarterPlayer.StarterCharacterScripts.MMO_StarterCharacterPackage", Name = "MMO_StarterCharacterPackage", Purpose = "Character LocalScripts and per-character visuals." },
	},

	ArchivedCompatibilityAliases = {
		Path = "ServerStorage.MMO_Archive.CompatibilityAliases_20260610",
		Purpose = "Old root-level require shims kept only for reference/recovery. Current runtime code uses package roots directly.",
	},

	KeepDirectOrMapOwned = {
		"Workspace.* map content",
		"ReplicatedFirst.MapTeleportLoadingController",
		"ServerStorage.RBX_ANIMSAVES",
	},

	MapOnlyContent = {
		"Workspace.Terrain",
		"Workspace.GeneratedMap",
		"Workspace.WorldSpawns",
		"Workspace.WorldPortals",
		"Workspace.WorldMapMarkers",
		"Workspace.GatheringZones",
		"Workspace.SpawnNPC",
		"Workspace.WorldCities",
		"Workspace.Exit*",
	},
}
