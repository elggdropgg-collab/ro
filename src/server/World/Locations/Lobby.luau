-- The depot where every run starts: a quiet foggy platform and a few service buildings.

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server
local Builder = require(Server.World.Builder)

local P = Builder.Palette

local Lobby = {}

function Lobby.generate(ctx: any): any
	local folder: Instance = ctx.Folder
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(70, 64, 58))
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(500, 12, 500), Enum.Material.Ground)

	local buildings = Builder.folder(folder, "Buildings")
	Builder.house(buildings, CFrame.lookAt(Vector3.new(-40, 0, -46), Vector3.new(-40, 0, 0)), Vector3.new(26, 12, 16), {
		WallMaterial = Enum.Material.Brick,
		WallColor = P.Brick,
		RoofColor = P.MetalDark,
	})
	Builder.house(buildings, CFrame.lookAt(Vector3.new(36, 0, -50), Vector3.new(36, 0, 0)), Vector3.new(18, 9, 12), {
		WallMaterial = Enum.Material.Concrete,
		WallColor = P.ConcreteDark,
		RoofColor = P.RustMetal,
	})
	-- Parked dead wagons on a siding
	for i = 0, 2 do
		local cf = CFrame.new(-90 + i * 30, 0, 34)
		Builder.part(
			buildings,
			cf * CFrame.new(0, 5.5, 0),
			Vector3.new(26, 8, 9),
			Enum.Material.CorrodedMetal,
			P.RustMetal
		)
		Builder.part(buildings, cf * CFrame.new(0, 1, 0), Vector3.new(22, 2, 7), Enum.Material.Metal, P.MetalDark)
	end
	return {
		Name = "Lobby",
		Radius = 240,
		CellSize = 16,
		Concealed = {},
		WheatCells = {},
		POIs = {},
		Paths = {},
		Resources = {},
		Reanimators = {},
		Monsters = { Nests = {} },
	}
end

return Lobby
