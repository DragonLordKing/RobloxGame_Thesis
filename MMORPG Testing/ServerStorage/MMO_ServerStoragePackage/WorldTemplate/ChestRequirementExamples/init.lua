--[[
Name: ChestRequirementExamples
Class: ModuleScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.WorldTemplate.ChestRequirementExamples
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: CanOpen
Clean source lines: 28
]]
return {
	Requirements = {
		{
			Id = "nearby_npc_kills",
			Type = "NpcKillsNearby",
			Count = 15,
			Radius = 140,
			Scope = "Server",
			Label = "Nearby NPC kills",
		},
		{
			Id = "nearby_valor",
			Type = "ValorNearby",
			Amount = 2000,
			Radius = 140,
			Scope = "Player",
			Bucket = "PvE",
			Label = "Personal PvE Valor earned nearby",
		},
	},

	CanOpen = function(player, chest, context)


		return true
	end,
}
