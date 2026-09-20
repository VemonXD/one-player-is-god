-- Only a lethal hit through this service can earn elimination credit.
-- Nonlethal damage followed by a reset or environmental death earns no credit.
local DamageService = {}
DamageService.__index = DamageService
function DamageService.new(isSurvivor)
	return setmetatable({isSurvivor = isSurvivor, records = {}}, DamageService)
end
function DamageService:DamagePlayer(victim, amount, attacker, source, window)
	if not self.isSurvivor(victim) or type(amount) ~= "number" or amount <= 0 or amount ~= amount then return false end
	local char = victim.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or char:FindFirstChildOfClass("ForceField") then return false end
	self.records[victim] = nil
	if amount >= hum.Health then
		self.records[victim] = {character = char, attacker = attacker, source = source,
			expires = workspace:GetServerTimeNow() + (window or 2)}
	end
	hum:TakeDamage(amount)
	return true
end
function DamageService:ConsumeElimination(victim, character)
	local hit = self.records[victim]
	self.records[victim] = nil
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hit and hit.character == character and hum and hum.Health <= 0
		and workspace:GetServerTimeNow() <= hit.expires then return hit end
	return nil
end
function DamageService:Clear(player)
	if player then self.records[player] = nil else table.clear(self.records) end
end
return DamageService

