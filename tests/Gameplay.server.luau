-- Included only in the separate Studio test place; never in the playable v03.
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage:WaitForChild("GodGame")
local state = Shared:WaitForChild("State")
local function waitFor(predicate, label, limit)
	local deadline = os.clock() + (limit or 40)
	repeat
		if predicate() then return end
		task.wait(0.05)
	until os.clock() > deadline
	error("[Phase2Test] Timeout: " .. label)
end
local function role(name)
	for _, p in ipairs(Players:GetPlayers()) do if p:GetAttribute("Role") == name then return p end end
end
waitFor(function() return state:GetAttribute("Phase") == "RoundActive" and #Players:GetPlayers() == 3 end, "first round")
local god = role("God")
local victim = role("Survivor")
local AbilityService = require(game.ServerScriptService.GodGame.AbilityService)
local DamageService = require(game.ServerScriptService.GodGame.DamageService)
local active = false
local validator = AbilityService.new({isActive = function() return active end, god = function() return god end}, {})
local Geometry = require(Shared.TargetingGeometry)
local spec = require(Shared.AbilityDefinitions).Lightning
local target = assert(Geometry.Resolve(workspace.ActiveMap, victim.Character.HumanoidRootPart.Position, spec, god.Character.HumanoidRootPart.Position))
local function rejected(who, name, pos, reason)
	task.wait(0.16)
	local ok, why = validator:Validate(who, name, pos)
	assert(not ok and why == reason, "Expected " .. reason .. ", got " .. tostring(why))
end
rejected(god, "Lightning", target, "Round is not active")
active = true
rejected(victim, "Lightning", target, "Only God can cast")
rejected(god, "Meteor", target, "Unknown ability")
rejected(god, "Lightning", "bad", "Invalid target")
rejected(god, "Lightning", Vector3.new(0/0, 0, 0), "Invalid target")
rejected(god, "Lightning", Vector3.new(math.huge, 0, 0), "Invalid target")
rejected(god, "Lightning", Vector3.new(1000, 0, 0), "Target is out of range")
rejected(god, "Lightning", Vector3.new(95, 0, 0), "Target must be on the island")
rejected(god, "Lightning", target + Vector3.new(1, 0, 0), "Target changed. Aim again.")
rejected(god, "Lightning", target + Vector3.new(0, 2, 0), "Target changed. Aim again.")
assert(Geometry.Resolve(workspace.ActiveMap, Vector3.new(51, 0, 51), spec).Y == 16, "Roof height lost")
assert(Geometry.Snap(14, 10) == 10 and Geometry.Snap(-16, 10) == -20, "Grid snapping failed")
print("[TargetingTest] PASS server snap, roof height, off-grid and false-height rejection")
task.wait(0.16)
assert(validator:Validate(god, "Lightning", target))
local ok, reason = validator:Validate(god, "Lightning", target)
assert(not ok and reason == "Rate limited", "Spam was accepted")
validator.cooldowns[god] = {Lightning = workspace:GetServerTimeNow() + 8}
rejected(god, "Lightning", target, "Ability is cooling down")
print("[Phase2Test] PASS validation: phase, role, unknown ability, type, NaN, infinity, distance, bounds, spam, cooldown")

-- Verify nonlethal hits followed by unrelated death do not earn attribution.
local model = Instance.new("Model", workspace)
local hum = Instance.new("Humanoid", model)
local dummy = {Character = model}
local damage = DamageService.new(function() return true end)
damage:DamagePlayer(dummy, 10, god, "Lightning", 2)
hum.Health = 0
assert(damage:ConsumeElimination(dummy, model) == nil, "Unrelated death was credited")
model:Destroy()
print("[Phase2Test] PASS unrelated-death attribution")
state:SetAttribute("TestStage", "Lightning")
waitFor(function() return state:GetAttribute("Survivors") == 1 end, "first Lightning elimination")
local spectator = role("Spectator")
assert(spectator and god.leaderstats.Coins.Value == 15, "First kill attribution/reward failed")
assert(state:GetAttribute("Phase") == "RoundActive", "Round ended with a survivor remaining")
waitFor(function()
	local root = spectator.Character and spectator.Character:FindFirstChild("HumanoidRootPart")
	local h = spectator.Character and spectator.Character:FindFirstChildOfClass("Humanoid")
	return root and h and h.Health > 0 and root.Position.Z > 190
end, "spectator respawns in lobby", 7)
print("[Phase2Test] PASS first kill, spectator role, immediate count, lobby respawn")
waitFor(function() return state:GetAttribute("Phase") == "RoundEnd" end, "last survivor ends round", 20)
assert(state:GetAttribute("Winner") == "God" and god.leaderstats.Coins.Value == 30, "God win or elimination credit failed")
print("[Phase2Test] PASS last kill ends round and credits God")
state:SetAttribute("TestStage", "Paused")
waitFor(function() return state:GetAttribute("Phase") == "RoundActive" end, "second round")
local nextGod = role("God")
assert(nextGod ~= god, "God repeated")
local resetter = role("Survivor")
local before = nextGod.leaderstats.Coins.Value
resetter.Character:FindFirstChildOfClass("Humanoid").Health = 0
waitFor(function() return resetter:GetAttribute("Role") == "Spectator" end, "reset elimination", 3)
assert(nextGod.leaderstats.Coins.Value == before, "Reset awarded God credit")
assert(state:GetAttribute("Survivors") == 1, "Reset count failed")
state:SetAttribute("TestStage", "PendingCancellation")
waitFor(function() return (nextGod:GetAttribute("LightningReadyAt") or 0) > workspace:GetServerTimeNow() end, "pending warning")
local remaining = role("Survivor")
nextGod.Character:FindFirstChildOfClass("Humanoid").Health = 0
waitFor(function() return state:GetAttribute("Phase") == "RoundEnd" end, "God reset ends round", 3)
assert(state:GetAttribute("Winner") == "Survivors", "God reset did not award Survivor win")
task.wait(1)
assert(remaining.Character:FindFirstChildOfClass("Humanoid").Health > 0, "Cancelled warning damaged survivor")
print("[Phase2Test] PASS repeat round, reset without credit, pending warning cancellation")
state:SetAttribute("TestStage", "Paused")
waitFor(function() return state:GetAttribute("Phase") == "RoundActive" end, "third round")
local leavingGod = role("God")
leavingGod:Kick("Phase 2 local test: God leaving")
waitFor(function() return state:GetAttribute("Phase") == "RoundEnd" end, "God leaving ends round", 5)
assert(state:GetAttribute("Winner") == "Survivors", "God leaving did not award Survivor win")
print("[Phase2Test] PASS God leaving awards Survivor win")
print("[Phase2Test] ALL PASS")
state:SetAttribute("TestStage", "Complete")

