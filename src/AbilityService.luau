local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Definitions = require(game.ReplicatedStorage.GodGame.AbilityDefinitions)
local World = require(script.Parent.World)
local Geometry = require(game.ReplicatedStorage.GodGame.TargetingGeometry)
local AbilityService = {}
AbilityService.__index = AbilityService
function AbilityService.new(context, damage)
	return setmetatable({context = context, damage = damage, cooldowns = {}, requests = {}}, AbilityService)
end
function AbilityService:Reset()
	table.clear(self.cooldowns)
	for _, player in ipairs(Players:GetPlayers()) do
		for name in pairs(Definitions) do player:SetAttribute(name .. "ReadyAt", 0) end
	end
end
function AbilityService:RemovePlayer(player)
	self.requests[player] = nil
	self.cooldowns[player] = nil
end
function AbilityService:Validate(player, name, target)
	if not player or player.Parent ~= Players then return false, "Player unavailable" end
	local now = workspace:GetServerTimeNow()
	if now - (self.requests[player] or -math.huge) < 0.15 then return false, "Rate limited" end
	self.requests[player] = now
	if not self.context.isActive() then return false, "Round is not active" end
	if player ~= self.context.god() or player:GetAttribute("Role") ~= "God" then return false, "Only God can cast" end
	if typeof(name) ~= "string" or not Definitions[name] then return false, "Unknown ability" end
	local spec = Definitions[name]
	if typeof(target) ~= "Vector3" then return false, "Invalid target" end
	for _, n in ipairs({target.X, target.Y, target.Z}) do
		if n ~= n or math.abs(n) == math.huge then return false, "Invalid target" end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return false, "God is unavailable" end
	if (root.Position - target).Magnitude > spec.MaxCastDistance then return false, "Target is out of range" end
	if math.abs(target.X) > 90 or math.abs(target.Z) > 90 or target.Y < -1 or target.Y > 25 then
		return false, "Target must be on the island"
	end
	local ready = self.cooldowns[player] and self.cooldowns[player][name] or 0
	if now < ready then return false, "Ability is cooling down" end
	local resolved, reason = Geometry.Resolve(World.map, target, spec, root.Position)
	if not resolved then return false, reason end
	-- Reject a stale/forged preview instead of silently moving the strike.
	if (resolved - target).Magnitude > 0.05 then return false, "Target changed. Aim again." end
	return true, resolved
end
function AbilityService:Use(player, name, target)
	local valid, result = self:Validate(player, name, target)
	if not valid then return false, result end
	local spec = Definitions[name]
	local readyAt = workspace:GetServerTimeNow() + spec.Cooldown
	self.cooldowns[player] = self.cooldowns[player] or {}
	self.cooldowns[player][name] = readyAt
	player:SetAttribute(name .. "ReadyAt", readyAt)
	local token = self.context.generation()
	local marker = World.part(World.effects, "LightningWarning", Vector3.new(0.2, spec.Radius * 2, spec.Radius * 2), result + Vector3.new(0, 0.15, 0), Color3.fromRGB(255, 55, 65), Enum.Material.Neon)
	marker.Shape = Enum.PartType.Cylinder
	marker.CFrame = CFrame.new(marker.Position) * CFrame.Angles(0, 0, math.pi / 2)
	marker.Transparency = 0.35
	marker.CanCollide, marker.CanTouch, marker.CanQuery = false, false, false
	Debris:AddItem(marker, spec.Warning + 0.1)
	task.delay(spec.Warning, function()
		if not self.context.isActive() or token ~= self.context.generation() or player ~= self.context.god() then return end
		local beam = World.part(World.effects, "LightningStrike", Vector3.new(2, 100, 2), result + Vector3.new(0, 50, 0), Color3.fromRGB(255, 250, 200), Enum.Material.Neon)
		beam.CanCollide, beam.CanTouch, beam.CanQuery = false, false, false
		Debris:AddItem(beam, 0.35)
		-- A snapshot avoids skipping victims when death handlers remove them.
		local victims = self.context.survivors()
		for _, victim in ipairs(victims) do
			local root = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - result).Magnitude <= spec.Radius then
				self.damage:DamagePlayer(victim, spec.Damage, player, name, spec.AttributionWindow)
			end
		end
	end)
	return true, result
end
return AbilityService

