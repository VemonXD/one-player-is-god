local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Shared = game.ReplicatedStorage.GodGame
local Definitions = require(Shared.AbilityDefinitions)
local Geometry = require(Shared.TargetingGeometry)
local Controller = {}
Controller.__index = Controller
local function visual(parent, name, size)
	local p = Instance.new("Part")
	p.Name, p.Size = name, size
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.CastShadow, p.Material = false, Enum.Material.Neon
	p.Parent = parent
	return p
end
function Controller.new(player, state, remote, gui)
	local self = setmetatable({player = player, state = state, remote = remote, gui = gui, connections = {}}, Controller)
	local function connect(signal, callback) table.insert(self.connections, signal:Connect(callback)) end
	connect(player:GetAttributeChangedSignal("Role"), function() self:CancelTargeting() end)
	connect(state:GetAttributeChangedSignal("Phase"), function() self:CancelTargeting() end)
	connect(player.CharacterRemoving, function() self:CancelTargeting() end)
	connect(gui.Destroying, function() self:Destroy() end)
	connect(gui.AncestryChanged, function() if not gui:IsDescendantOf(player.PlayerGui) then self:Destroy() end end)
	connect(Input.WindowFocusReleased, function() self:CancelTargeting() end)
	connect(GuiService.MenuOpened, function() self:CancelTargeting() end)
	connect(Input.InputBegan, function(input, processed)
		-- Escape can be consumed by the Roblox menu; cancel before checking processed.
		if input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:CancelTargeting()
		elseif not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:ConfirmTarget()
		end
	end)
	return self
end
function Controller:Allowed()
	local char = self.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return not self.destroyed and self.gui.Enabled and self.state:GetAttribute("Phase") == "RoundActive"
		and self.player:GetAttribute("Role") == "God" and hum and hum.Health > 0
end
function Controller:BeginTargeting(name)
	self:CancelTargeting()
	local spec = Definitions[name]
	if not spec or spec.PreviewShape ~= "Circle" or not self:Allowed() then return false end
	if (self.player:GetAttribute(name .. "ReadyAt") or 0) > workspace:GetServerTimeNow() then return false end
	self.map = workspace:FindFirstChild("ActiveMap")
	if not self.map then return false end
	self.name, self.spec, self.active = name, spec, true
	self.folder = Instance.new("Folder", workspace)
	self.folder.Name = "GodTargetingPreview"
	self.disc = visual(self.folder, "Radius", Vector3.new(0.12, spec.Radius * 2, spec.Radius * 2))
	self.disc.Shape, self.disc.Transparency = Enum.PartType.Cylinder, 0.65
	self.center = visual(self.folder, "Center", Vector3.new(0.7, 2.5, 0.7))
	-- Lightning uses spherical distance. This faint volume makes its vertical extent explicit.
	self.volume = visual(self.folder, "DamageVolume", Vector3.one * spec.Radius * 2)
	self.volume.Shape, self.volume.Transparency = Enum.PartType.Ball, 0.94
	self:ShowGrid()
	self.render = RunService.RenderStepped:Connect(function() self:UpdatePreview() end)
	self:UpdatePreview()
	return true
end
function Controller:ShowGrid()
	self:HideGrid()
	local min, max = self.map:GetAttribute("TargetMin"), self.map:GetAttribute("TargetMax")
	local width, depth = max.X - min.X, max.Z - min.Z
	local plane = visual(self.folder, "Grid", Vector3.new(width, 0.01, depth))
	plane.Position, plane.Transparency = Vector3.new((min.X + max.X) / 2, 0.03, (min.Z + max.Z) / 2), 1
	self.grid = plane
	local surface = Instance.new("SurfaceGui", plane)
	surface.Face, surface.AlwaysOnTop, surface.LightInfluence = Enum.NormalId.Top, true, 0
	surface.CanvasSize = Vector2.new(width * 4, depth * 4)
	local function line(position, size)
		local f = Instance.new("Frame", surface)
		f.Position, f.Size, f.BorderSizePixel = position, size, 0
		f.BackgroundColor3, f.BackgroundTransparency = Color3.fromRGB(139, 204, 224), 0.72
	end
	-- A single client part plus 38 thin GUI lines at 10-stud spacing.
	for x = math.ceil(min.X / self.spec.GridSpacing) * self.spec.GridSpacing, max.X, self.spec.GridSpacing do
		line(UDim2.fromScale((x - min.X) / width, 0), UDim2.new(0, 1, 1, 0))
	end
	for z = math.ceil(min.Z / self.spec.GridSpacing) * self.spec.GridSpacing, max.Z, self.spec.GridSpacing do
		line(UDim2.fromScale(0, (z - min.Z) / depth), UDim2.new(1, 0, 0, 1))
	end
end
function Controller:HideGrid()
	if self.grid then self.grid:Destroy(); self.grid = nil end
end
function Controller:SetPointerPosition(position)
	-- Input adapter for touch/gamepad; coordinates are viewport pixels, as with GetMouseLocation.
	self.pointer = position
end
function Controller:OverUI(position)
	for _, item in ipairs(self.player.PlayerGui:GetGuiObjectsAtPosition(position.X, position.Y)) do
		if item.Visible and (item:IsA("GuiButton") or item:IsA("TextBox") or item:IsDescendantOf(self.gui)) then return true end
	end
	return GuiService.MenuIsOpen
end
function Controller:UpdatePreview()
	if not self.active then return end
	if not self:Allowed() or (self.player:GetAttribute(self.name .. "ReadyAt") or 0) > workspace:GetServerTimeNow() then
		self:CancelTargeting(); return
	end
	local camera = workspace.CurrentCamera
	local root = self.player.Character and self.player.Character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then self:CancelTargeting(); return end
	local pointer = self.pointer or Input:GetMouseLocation()
	local ray = camera:ViewportPointToRay(pointer.X, pointer.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, Geometry.Parameters(self.map))
	local target, reason
	if self:OverUI(pointer) then reason = "Move the cursor onto the island"
	elseif not hit then reason = "Outside playable map"
	elseif hit.Normal.Y < 0.5 then reason = "Aim at ground or a roof"
	else target, reason = Geometry.Resolve(self.map, hit.Position, self.spec, root.Position) end
	self.target, self.valid, self.reason = target, target ~= nil, reason
	-- Red indicator on the map plane when the cursor is outside the map.
	local display = target or (hit and hit.Position)
	if not display and ray.Direction.Y < -0.001 then display = ray.Origin + ray.Direction * (-ray.Origin.Y / ray.Direction.Y) end
	if display and Geometry.IsFinite(display) then
		self.disc.CFrame = CFrame.new(display + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		self.center.Position = display + Vector3.new(0, 1.25, 0)
		self.volume.Position = display
		local color = self.valid and Color3.fromRGB(70, 237, 191) or Color3.fromRGB(255, 65, 81)
		self.disc.Color, self.center.Color, self.volume.Color = color, color, color
		self.disc.Transparency, self.center.Transparency, self.volume.Transparency = 0.65, 0, 0.94
	else
		self.disc.Transparency, self.center.Transparency, self.volume.Transparency = 1, 1, 1
	end
end
function Controller:ConfirmTarget()
	if not self.active or not self:Allowed() or not self.valid or not self.target then return false end
	if self:OverUI(self.pointer or Input:GetMouseLocation()) then return false end
	if (self.player:GetAttribute(self.name .. "ReadyAt") or 0) > workspace:GetServerTimeNow() then return false end
	-- Use exactly the last rendered target, never reraycast a different point at click time.
	local name, target = self.name, self.target
	self:CancelTargeting()
	self.remote:FireServer(name, target)
	return true, target
end
function Controller:DestroyPreview()
	if self.folder then self.folder:Destroy(); self.folder = nil end
	self.disc, self.center, self.volume, self.grid = nil, nil, nil, nil
end
function Controller:CancelTargeting()
	self.active, self.valid, self.target, self.pointer = false, false, nil, nil
	if self.render then self.render:Disconnect(); self.render = nil end
	self:DestroyPreview()
end
function Controller:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	self:CancelTargeting()
	for _, c in ipairs(self.connections) do c:Disconnect() end
	table.clear(self.connections)
end
return Controller

