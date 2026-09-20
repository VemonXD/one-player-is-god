local Players = game:GetService("Players")
local player = Players.LocalPlayer
local shared = game.ReplicatedStorage:WaitForChild("GodGame")
local state, remote = shared:WaitForChild("State"), shared:WaitForChild("UseGodAbility")
local Geometry = require(shared.TargetingGeometry)
local spec = require(shared.AbilityDefinitions).Lightning
local inactiveSent, survivorSent = false, false
while state:GetAttribute("TestStage") ~= "Complete" do
	task.wait(0.2)
	local phase = state:GetAttribute("Phase")
	if phase == "Intermission" and not inactiveSent then
		remote:FireServer("Lightning", Vector3.zero)
		inactiveSent = true
	end
	if phase == "RoundActive" and player:GetAttribute("Role") == "Survivor" and not survivorSent then
		remote:FireServer("Lightning", player.Character.HumanoidRootPart.Position)
		survivorSent = true
	end
	local stage = state:GetAttribute("TestStage")
	if phase == "RoundActive" and player:GetAttribute("Role") == "God"
		and (stage == "Lightning" or stage == "PendingCancellation")
		and (player:GetAttribute("LightningReadyAt") or 0) <= workspace:GetServerTimeNow() then
		for _, victim in ipairs(Players:GetPlayers()) do
			if victim:GetAttribute("Role") == "Survivor" and victim.Character then
				local target = victim.Character:FindFirstChild("HumanoidRootPart")
				if target then
					local resolved = Geometry.Resolve(workspace.ActiveMap, target.Position, spec, player.Character.HumanoidRootPart.Position)
					if resolved then for _ = 1, 20 do remote:FireServer("Lightning", resolved) end end
					break
				end
			end
		end
	end
end

