local World = {}
function World.part(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, position
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
function World.build()
	local root = Instance.new("Folder", workspace)
	root.Name = "GodGame"
	World.root = root
	local map = Instance.new("Folder", workspace)
	map.Name = "ActiveMap"
	map:SetAttribute("TargetMin", Vector3.new(-90, -10, -90))
	map:SetAttribute("TargetMax", Vector3.new(90, 30, 90))
	World.map = map
	World.effects = Instance.new("Folder", root)
	World.effects.Name = "Disasters"
	local part = World.part
	part(map, "Island", Vector3.new(180, 8, 180), Vector3.new(0, -4, 0), Color3.fromRGB(69, 128, 97))
	part(root, "Ocean", Vector3.new(1500, 2, 1500), Vector3.new(0, -25, 0), Color3.fromRGB(31, 90, 130))
	for x = -1, 1 do
		for z = -1, 1 do
			if x ~= 0 or z ~= 0 then
				local base = Vector3.new(x * 52, 0, z * 52)
				part(map, "Refuge", Vector3.new(24, 14, 24), base + Vector3.new(0, 7, 0), Color3.fromRGB(208, 180, 141))
				part(map, "Roof", Vector3.new(28, 2, 28), base + Vector3.new(0, 15, 0), Color3.fromRGB(50, 65, 83))
				for step = 1, 7 do
					part(map, "Stair", Vector3.new(10, step * 2, 3), base + Vector3.new(0, step, 36 - step * 3), Color3.fromRGB(164, 152, 134))
				end
			end
		end
	end
	part(root, "Lobby", Vector3.new(70, 3, 70), Vector3.new(0, 65, 230), Color3.fromRGB(35, 43, 65))
	for _, pos in ipairs({Vector3.new(35, 71, 230), Vector3.new(-35, 71, 230)}) do
		part(root, "Rail", Vector3.new(2, 10, 70), pos, Color3.fromRGB(89, 111, 145))
	end
	for _, z in ipairs({195, 265}) do
		part(root, "Rail", Vector3.new(70, 10, 2), Vector3.new(0, 71, z), Color3.fromRGB(89, 111, 145))
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.Position = "LobbySpawn", Vector3.new(12, 1, 12), Vector3.new(0, 67, 230)
	spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
	spawn.Parent = root
	World.spawn = spawn
	part(root, "GodThrone", Vector3.new(20, 3, 20), Vector3.new(0, 100, 0), Color3.fromRGB(255, 205, 92), Enum.Material.Neon)
	game:GetService("Lighting").ClockTime = 14
end
return World

