--[[
Name: README
Class: ModuleScript
Original path: game.ServerScriptService.GenerationStudioPlugin.README
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Clean source lines: 251
]]
return [[
Generation Map Tools

Generation Map Tools is a Roblox Studio plugin for building large terrain maps, city claim areas, edge borders, decorations, structures, ports, tunnels, bridges, and generated road networks. It was made for procedural RPG-style world building where the terrain is generated first, then roads are planned around the finished map.

The plugin runs as a Studio editor tool. It does not add runtime scripts to your place, and it does not create any assets before you press a generation button. The generation code is bundled inside the plugin itself.

What the plugin changes

When you generate terrain, the plugin writes to:
- Workspace.GeneratedWorld
- The terrain voxels inside the generated map area

When you generate roads, the plugin writes road objects inside the generated world and restores any generated decorations that were temporarily removed from the previous road attempt.

The plugin does not create or install SpawnLocations, game scripts, RemoteEvents, RemoteFunctions, server systems, decoration assets, or structure assets. Player spawning, gameplay logic, claiming systems, economy systems, and asset libraries should be created by the game developer.

Basic workflow

1. Save the GenerationStudioPlugin script as a local plugin.
2. Open a place in Roblox Studio.
3. Open the plugin from Generation > Map Tools.
4. Add optional Decoration and Structures folders in ReplicatedStorage.
5. Choose City or Main on the Terrain tab.
6. Adjust the terrain settings.
7. Press Generate.
8. Use the Roads tab to place exits and anchors.
9. Press Generate Roads.
10. Use Undo if you need to restore the previous generated terrain state.

Undo

Undo restores the last terrain generation made during the current plugin session. It restores the terrain snapshot from before generation and brings back the previous Workspace.GeneratedWorld folder if one existed.

Undo is intentionally scoped to generated output. It should not remove unrelated Workspace objects that existed outside Workspace.GeneratedWorld before generation.

Required and optional assets

The plugin can generate terrain without any custom assets. Decorations and structures are optional, but maps will look better if you provide them.

If no structure assets are found, the plugin shows a warning before generation. If no decoration assets are found and decorations are enabled, the plugin shows a second warning. If both are missing, the structure warning appears first.

Decoration setup

Default decoration layout:

ReplicatedStorage
  Decoration
    Rocks
    Trees
    Bushes
    MiniRocks

Biome-specific decoration layout:

ReplicatedStorage
  Decoration
    Grass
      Rocks
      Trees
      Bushes
      MiniRocks
    Desert
      Rocks
      Trees
      Bushes
      MiniRocks
    Snow
      Rocks
      Trees
      Bushes
      MiniRocks

If a biome folder exists for the selected biome, the plugin uses that folder. For example, a snow map uses ReplicatedStorage.Decoration.Snow. If the selected biome folder does not exist, the plugin falls back to ReplicatedStorage.Decoration.Rocks, Trees, Bushes, and MiniRocks.

Decoration category folders may contain Models or BaseParts. Keep templates anchored or built as normal Studio models. The generator clones those templates into Workspace.GeneratedWorld.Decorations.

Structure setup

Random structure templates go in:

ReplicatedStorage
  Structures
    YourStructureModel
      Base --> Base is the ENTIRE preimeter of the structure, it can be non-collidable,

Each random structure should be a Model. It should include a Base part somewhere inside the model. The Base part is used as the footprint for placement checks, spacing, and collision avoidance.

City maps do not place random structures in the city building area. The middle of a city map is kept clean for future player-built city content.

Custom city monolith setup

City maps can use a custom monolith template from:

ReplicatedStorage
  Structures
    Monolith
      YourMonolithModel

The Monolith folder may contain Models or BaseParts. If a valid template is found, the plugin places one at the center of the city and marks it with CityClaimMonolith attributes. If no custom monolith is found, the plugin creates a simple built-in monolith using the Monolith H and Monolith R settings.

Spawn setup

The plugin does not need a SpawnLocation and does not create one. Add your own spawn system in the target game if players need to spawn on the generated map.

Terrain profiles

City: Creates a smaller, flatter map with a clean central city building area. Lakes, rivers, canyons, mesas, and random structures are disabled in the city area. Decoration is pushed to the outskirts, and roads route around the reserved city zone.

Main: Creates a larger natural map with terrain variation, optional water features, mesas, canyons, random structures, decorations, borders, and road exits.

Terrain settings reference

Seed: Controls the random result. Use the same seed and settings to reproduce a similar map. Leave blank to use the default seed.

Biome: Controls the main terrain material style and which decoration folder is preferred. Supported values are grass, desert, and snow.

Scale: Multiplies the overall size of the generated map. Higher values create a larger playable area and wider border region.

Base Height: The general terrain height used as the starting point for the map.

Water Level: The height used for water surfaces, ocean borders, river water, lake water, and water exits.

Main Relief: Large terrain height variation. Higher values create broader hills and height changes.

Small Relief: Smaller terrain variation. Higher values make the ground less flat and more uneven.

Lakes: Number of lakes to attempt on Main maps. City maps force this to 0.

Lake Min: Minimum lake radius.

Lake Max: Maximum lake radius.

Lake Depth: How far lake basins cut down into the terrain.

Lake Water: Depth of water placed inside lakes.

Lake Shape: Shoreline irregularity. Higher values make lake shapes less circular.

Rivers: Number of rivers to attempt on Main maps. City maps force this to 0.

River Width: Width of the river bed.

River Depth: How far rivers cut into the terrain.

River Water: Depth of water inside rivers.

River Wobble: How much river paths bend from side to side.

Canyons: Number of canyons to attempt on Main maps. City maps force this to 0.

Canyon Width: Width of canyon openings.

Canyon Depth: Depth of canyon cuts.

Mesas: Number of mesas to attempt on Main maps. City maps force this to 0.

Mesa Min: Minimum mesa radius.

Mesa Max: Maximum mesa radius.

Mesa Rise: Height added to mesa tops.

Random Structures: Number of random structure placements to attempt. City maps force this to 0.

Rocks: Number of rock decorations to attempt.

Trees: Number of tree decorations to attempt.

Bushes: Number of bush decorations to attempt.

Mini Rocks: Number of small rock decorations to attempt.

Feature Mix: Controls how major natural features share space. both allows features to be attempted together. exclusive keeps major features more separated.

North Side, South Side, East Side, West Side: Border style for each side of the map. Available styles include ocean, mountains, mountains_heavy, cliff_grasslands, desert_abandoned, and none.

Edge Ring: City profile setting. Controls the width of the outer decoration and road band around the clean city area.

Monolith H: Height of the built-in city monolith when no custom monolith template is provided.

Monolith R: Radius of the built-in city monolith when no custom monolith template is provided.

Decor: Enables or disables decoration placement.

Road editor overview

The road editor appears after terrain generation. It uses a grid to choose exits and optional anchor points.

Edge cells are map exits. Click an edge cell once to mark it as a road exit. Click it again to mark it as a tunnel exit. Click it a third time to clear it.

Interior cells are anchors. Roads try to connect through anchors when possible, which is useful for forcing routes toward a middle hub or through a specific region.

Blocked cells represent city areas, structures, water, mesas, steep slopes, or other areas that roads should avoid. City roads are designed to stay around the reserved city building area rather than cutting through it.

Road buttons

Clear: Clears the current road editor selection. It does not delete generated roads by itself.

Refresh: Rebuilds the road mask from the current generated world. Use this if the terrain or generated content changed.

Generate Roads: Builds roads from the selected exits and anchors. If roads were generated before, the previous generated road objects are removed first and affected generated decorations are restored before the new road attempt is built.

Road settings reference

pathCellSize: Planning grid size for road pathfinding. Smaller values are more precise but slower.

roadWidth: Width of generated roads.

roadThickness: Thickness of road parts.

roadLift: Height offset that keeps roads slightly above terrain.

roadShoulder: Extra clearance around roads for decoration and collision removal.

exitStraightLength: Distance exits travel straight inward before the road is allowed to curve.

outOfMapDistance: Distance roads extend beyond the map edge at exits.

wiggleAmplitude: Strength of natural road curves.

wiggleScale: Scale of the curve noise used to vary road shape.

maxSlope: Maximum slope roads prefer to use while pathfinding.

reuseBonus: Preference for connecting to or following existing road runs.

bridgeDeckLift: Height offset for bridge decks above the crossed surface.

bridgeExtraWidth: Extra bridge width beyond the normal road width.

bridgePostGap: Distance between bridge support posts.

portLength: Length of the small port platform created at water exits.

portWidth: Width of water-exit ports.

portDeckLift: Height of port platforms above the water.

tunnelRadius: Radius of tunnel openings.

tunnelDepth: How far tunnel entrances extend into the map edge.

tunnelLip: Extra border size around tunnel openings.

Notes for creators

Generated content is placed under Workspace.GeneratedWorld so it is easy to inspect, move, or delete. Custom assets stay in ReplicatedStorage and are only cloned into the generated world when used.

For best results, keep structure Base parts sized to the actual footprint of the building, keep decoration models reasonably lightweight, and test road generation after changing large terrain settings.
]]