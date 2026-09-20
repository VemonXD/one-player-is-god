local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local player = Players.LocalPlayer
local previous = player:WaitForChild("PlayerGui"):FindFirstChild("GodHUD")
if previous then previous:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "GodHUD", false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")
local function label(size, pos, text)
	local l = Instance.new("TextLabel", gui)
	l.Size, l.Position = size, pos
	l.BackgroundColor3, l.BackgroundTransparency = Color3.fromRGB(18, 24, 39), 0.12
	l.TextColor3, l.Font, l.TextSize = Color3.fromRGB(240, 244, 255), Enum.Font.GothamBold, 18
	l.Text, l.TextWrapped = text, true
	Instance.new("UICorner", l).CornerRadius = UDim.new(0, 12)
	return l
end
local header = label(UDim2.new(0.8, 0, 0, 65), UDim2.new(0.1, 0, 0, 12), "ONE PLAYER IS GOD")
local hint = label(UDim2.new(0.8, 0, 0, 48), UDim2.new(0.1, 0, 0, 82), "")
local countdown = label(UDim2.new(0.8, 0, 0, 56), UDim2.new(0.1, 0, 0, 136), "Connecting to game server...")
countdown.TextSize = 26
countdown.TextColor3 = Color3.fromRGB(255, 212, 112)
local shared = game.ReplicatedStorage:WaitForChild("GodGame", 15)
local state = shared and shared:WaitForChild("State", 15)
local cast = shared and shared:WaitForChild("UseGodAbility", 15)
if not state or not cast then
	countdown.Text = "Game server did not start"
	hint.Text = "Reopen the updated place and restart the test. Check Output for errors."
	return
end
local bar = Instance.new("Frame", gui)
bar.Size, bar.Position = UDim2.new(0.94, 0, 0, 64), UDim2.new(0.03, 0, 1, -80)
bar.BackgroundTransparency = 1
bar.Visible = false
local names = {"Lightning"}
local Controller = require(script.Parent.TargetingController)
local targeting = Controller.new(player, state, cast, gui)
local connections = {}
local function connect(signal, callback) table.insert(connections, signal:Connect(callback)) end
gui.Destroying:Connect(function()
	targeting:Destroy()
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)
local feedback, feedbackUntil = "", 0
local buttons, selected = {}, "Lightning"
for i, name in ipairs(names) do
	local b = Instance.new("TextButton", bar)
	b.Size, b.Position = UDim2.new(0.5, 0, 1, 0), UDim2.new(0.25, 0, 0, 0)
	b.Font, b.TextSize, b.TextWrapped = Enum.Font.GothamBold, 15, true
	b.TextColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	b.Activated:Connect(function()
		targeting:BeginTargeting(name)
	end)
	buttons[name] = b
end
connect(cast.OnClientEvent, function(accepted, result)
	feedback = accepted and "Lightning incoming!" or tostring(result)
	feedbackUntil = workspace:GetServerTimeNow() + 2
end)
connect(Input.InputBegan, function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.One then targeting:BeginTargeting(selected) end
end)
connect(RunService.RenderStepped, function()
	local role = player:GetAttribute("Role") or "Spectator"
	local phase = state:GetAttribute("Phase") or "Loading"
	local now = workspace:GetServerTimeNow()
	local seconds = math.max(0, math.ceil((state:GetAttribute("EndsAt") or now) - now))
	local connected = state:GetAttribute("ConnectedPlayers") or #Players:GetPlayers()
	local minimum = state:GetAttribute("MinPlayers") or 2
	if phase == "WaitingForPlayers" then
		countdown.Text = string.format("WAITING FOR PLAYERS  %d / %d", connected, minimum)
	elseif phase == "Intermission" then
		countdown.Text = string.format("ROUND STARTS IN %d", seconds)
	elseif phase == "SelectingGod" then
		countdown.Text = "CHOOSING GOD... " .. seconds
	elseif phase == "RoundActive" then
		countdown.Text = string.format("%s  %d:%02d", role == "Spectator" and "SPECTATING" or (role == "God" and "UNLEASH LIGHTNING" or "SURVIVE"), math.floor(seconds / 60), seconds % 60)
	elseif phase == "RoundEnd" then
		countdown.Text = "NEXT ROUND IN " .. seconds
	else
		countdown.Text = "PREPARING PLAYERS..."
	end
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	header.Text = string.format("ONE PLAYER IS GOD • PHASE 2  |  %s  |  %d:%02d\n%s  •  %d alive  •  %d coins", phase, math.floor(seconds / 60), seconds % 60, role == "Spectator" and "SPECTATING" or role, state:GetAttribute("Survivors") or 0, coins and coins.Value or 0)
	bar.Visible = role == "God" and phase == "RoundActive"
	if not bar.Visible then targeting:CancelTargeting() end
	hint.Text = bar.Visible and (now < feedbackUntil and feedback or (targeting.active
		and (targeting.valid and "Click to strike � Right-click / Esc to cancel" or ((targeting.reason or "Aim at the island") .. " � Right-click / Esc to cancel"))
		or "Select Lightning Strike or press 1 to preview your target.")) or (role == "Spectator" and phase == "RoundActive"
		and "SPECTATING — wait in the lobby for the next round." or (state:GetAttribute("Message") or ""))
	for i, name in ipairs(names) do
		local remaining = math.max(0, math.ceil((player:GetAttribute(name .. "ReadyAt") or 0) - now))
		buttons[name].Text = "Lightning Strike" .. (remaining > 0 and (" (" .. remaining .. ")") or (targeting.active and "\nSELECT TARGET" or "\nREADY • Click or press 1"))
		buttons[name].AutoButtonColor = remaining == 0
		buttons[name].BackgroundColor3 = remaining > 0 and Color3.fromRGB(66, 69, 78) or Color3.fromRGB(162, 102, 37)
	end
	local camera = workspace.CurrentCamera
	if not camera then return end
	if role == "God" then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 210, 130), Vector3.zero)
	elseif camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then camera.CameraSubject = hum end
	end
end)

