local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.GodGame
local Config = require(Shared.Config)
local World = require(script.Parent.World)
local AbilityService = require(script.Parent.AbilityService)
local DamageService = require(script.Parent.DamageService)
local Definitions = require(Shared.AbilityDefinitions)
local cast = Instance.new("RemoteEvent", Shared)
cast.Name = "UseGodAbility"
local state = Instance.new("Folder", Shared)
state.Name = "State"
state:SetAttribute("MinPlayers", Config.MinPlayers)
state:SetAttribute("Build", "v03 Phase 2")
local survivors, god, previousGod = {}, nil, nil
local generation = 0
local finishRound, damage, abilities
local roundWinner
local loading = {}
local function setState(name, seconds, message)
	print("[GodGame] " .. name .. " (" .. seconds .. "s)")
	state:SetAttribute("Phase", name)
	state:SetAttribute("EndsAt", workspace:GetServerTimeNow() + seconds)
	state:SetAttribute("Message", message or "")
end
local function alive(player)
	local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0 and player.Character:FindFirstChild("HumanoidRootPart")
end
local function readyPlayers()
	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if alive(player) then table.insert(result, player) end
	end
	state:SetAttribute("ConnectedPlayers", #Players:GetPlayers())
	state:SetAttribute("ReadyPlayers", #result)
	return result
end
local function count()
	local n = 0
	for _ in pairs(survivors) do n += 1 end
	state:SetAttribute("Survivors", n)
	return n
end
local function eliminate(player, character)
	if not survivors[player] then return end
	survivors[player] = nil
	player:SetAttribute("Role", "Spectator")
	local hit = damage:ConsumeElimination(player, character)
	if hit and hit.attacker == god and god.Parent == Players then
		print(string.format("%s eliminated %s using %s", god.Name, player.Name, Definitions[hit.source].DisplayName))
		-- Retain existing session currency; only attributed kills receive it.
		god.leaderstats.Coins.Value += Config.EliminationCoins
	end
	if count() == 0 and state:GetAttribute("Phase") == "RoundActive" then finishRound("God", "God wins!") end
end
finishRound = function(winner, message)
	if state:GetAttribute("Phase") ~= "RoundActive" then return end
	roundWinner = winner
	setState("RoundEnd", Config.RoundEndDuration, message)
	generation += 1 -- Cancels pending warnings immediately.
	state:SetAttribute("Winner", winner)
end
damage = DamageService.new(function(player)
	return state:GetAttribute("Phase") == "RoundActive" and survivors[player] == true
		and player.Parent == Players and player:GetAttribute("Role") == "Survivor"
end)
abilities = AbilityService.new({
	isActive = function() return state:GetAttribute("Phase") == "RoundActive" end,
	god = function() return god end,
	generation = function() return generation end,
	survivors = function()
		local result = {}
		for player in pairs(survivors) do table.insert(result, player) end
		return result
	end,
}, damage)
local function respawn(player)
	if loading[player] or player.Parent ~= Players then return end
	loading[player] = true
	task.spawn(function()
		local ok, err = pcall(function() player:LoadCharacterAsync() end)
		loading[player] = nil
		if not ok and player.Parent == Players then warn("Respawn failed: " .. tostring(err)) end
	end)
end
local function setup(player)
	player:SetAttribute("Role", "Spectator")
	player.RespawnLocation = World.spawn
	local stats = Instance.new("Folder", player)
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue", stats)
	coins.Name = "Coins"
	local function characterAdded(char)
		eliminate(player, nil)
		damage:Clear(player)
		if player == god then finishRound("Survivors", "God reset. Survivors win!") end
		player:SetAttribute("Role", "Spectator")
		local hum = char:WaitForChild("Humanoid", 10)
		local root = char:WaitForChild("HumanoidRootPart", 10)
		if hum then hum.Died:Connect(function()
			if player.Character ~= char then return end
			eliminate(player, char)
			if player == god then finishRound("Survivors", "God is gone. Survivors win!") end
		end) end
		if root and player.Character == char and player:GetAttribute("Role") == "Spectator" then
			char:PivotTo(CFrame.new(0, 71, 230))
		end
	end
	player.CharacterAdded:Connect(characterAdded)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if player:GetAttribute("Role") ~= "Survivor" then eliminate(player, nil) end
		count()
	end)
	if player.Character then task.spawn(characterAdded, player.Character) end
	readyPlayers()
end
cast.OnServerEvent:Connect(function(player, name, target)
	local accepted, result = abilities:Use(player, name, target)
	-- Avoid amplifying spam with a reply to every rate-limited request.
	if result ~= "Rate limited" then cast:FireClient(player, accepted, result) end
end)
setState("Loading", 0, "Building the island...")
World.build()
Players.PlayerAdded:Connect(setup)
for _, player in ipairs(Players:GetPlayers()) do setup(player) end
Players.PlayerRemoving:Connect(function(player)
	if player == god then finishRound("Survivors", "God left. Survivors win!") end
	eliminate(player, nil)
	damage:Clear(player)
	abilities:RemovePlayer(player)
	loading[player] = nil
	state:SetAttribute("ConnectedPlayers", math.max(0, #Players:GetPlayers() - 1))
end)
-- Keep spectators physically separated even if they jump out of the lobby.
game:GetService("RunService").Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("Role") == "Spectator" then
			local root = alive(player)
			if root and (root.Position - Vector3.new(0, 71, 230)).Magnitude > 42 then
				root.AssemblyLinearVelocity = Vector3.zero
				player.Character:PivotTo(CFrame.new(0, 71, 230))
			end
		end
	end
end)
print("[GodGame] Server initialized, v03 Phase 2")
while true do
	setState("WaitingForPlayers", 0, "Waiting for at least " .. Config.MinPlayers .. " players")
	while #readyPlayers() < Config.MinPlayers do
		local connected = #Players:GetPlayers()
		state:SetAttribute("Message", connected >= Config.MinPlayers
			and "Waiting for player avatars to finish loading..."
			or "Invite another player or start a 2-client test.")
		task.wait(0.25)
	end
	setState("Intermission", Config.Intermission, "Get ready! God will be selected when the countdown ends.")
	local deadline = os.clock() + Config.Intermission
	local interrupted = false
	repeat
		task.wait(0.25)
		readyPlayers()
		if #Players:GetPlayers() < Config.MinPlayers then interrupted = true; break end
	until os.clock() >= deadline
	if interrupted then continue end
	-- Preserve the completed countdown while a resetting avatar returns.
	local eligible = readyPlayers()
	if #eligible < Config.MinPlayers then
		setState("PreparingPlayers", 0, "Countdown complete. Waiting for avatars to respawn...")
		repeat
			task.wait(0.25)
			eligible = readyPlayers()
		until #eligible >= Config.MinPlayers or #Players:GetPlayers() < Config.MinPlayers
	end
	if #eligible < Config.MinPlayers then continue end
	setState("SelectingGod", 2, "Choosing God...")
	local candidates = {}
	for _, player in ipairs(eligible) do
		if player.UserId ~= previousGod then table.insert(candidates, player) end
	end
	if #candidates == 0 then candidates = eligible end
	god = candidates[math.random(#candidates)]
	previousGod = god.UserId
	survivors = {}
	roundWinner = nil
	damage:Clear()
	abilities:Reset()
	state:SetAttribute("Winner", "")
	generation += 1
	state:SetAttribute("GodName", god.DisplayName)
	for i, player in ipairs(eligible) do
		local char = player.Character
		local hum = char:FindFirstChildOfClass("Humanoid")
		hum.Health = hum.MaxHealth
		local force = char:FindFirstChildOfClass("ForceField")
		if force then force:Destroy() end
		if player == god then
			player:SetAttribute("Role", "God")
			char:PivotTo(CFrame.new(0, 105, 0))
			char.HumanoidRootPart.Anchored = true
			for name in pairs(Definitions) do player:SetAttribute(name .. "ReadyAt", 0) end
		else
			player:SetAttribute("Role", "Survivor")
			survivors[player] = true
			local angle = i * math.pi * 2 / #eligible
			char:PivotTo(CFrame.new(math.cos(angle) * 30, 5, math.sin(angle) * 30))
		end
	end
	count()
	task.wait(2)
	setState("RoundActive", Config.RoundDuration, "Dodge the red warning markers to survive Lightning Strike.")
	deadline = os.clock() + Config.RoundDuration
	if god.Parent ~= Players or not alive(god) or god:GetAttribute("Role") ~= "God" then
		finishRound("Survivors", "God is gone. Survivors win!")
	elseif count() == 0 then finishRound("God", "God wins!") end
	while state:GetAttribute("Phase") == "RoundActive" do
		task.wait(0.25)
		for player in pairs(survivors) do
			local root = alive(player)
			if not root then eliminate(player, player.Character)
			elseif math.abs(root.Position.X) > 95 or math.abs(root.Position.Z) > 95 or root.Position.Y < -5 then
				player.Character:FindFirstChildOfClass("Humanoid").Health = 0
			end
		end
		if state:GetAttribute("Phase") == "RoundActive" then
			if god.Parent ~= Players or not alive(god) or god:GetAttribute("Role") ~= "God" then
				finishRound("Survivors", "God is gone. Survivors win!")
			elseif count() == 0 then finishRound("God", "God wins!")
			elseif os.clock() >= deadline then finishRound("Survivors", "Survivors win!") end
		end
	end
	if roundWinner == "Survivors" then
		for player in pairs(survivors) do
			if player.Parent == Players then player.leaderstats.Coins.Value += Config.SurvivalCoins end
		end
	end
	-- Leave the brief impact visible, while longer warning effects expire by Debris.
	survivors, god = {}, nil
	damage:Clear()
	count()
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("Role", "Spectator")
		respawn(player)
	end
	task.wait(Config.RoundEndDuration)
	World.effects:ClearAllChildren()
end

