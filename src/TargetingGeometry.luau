-- Shared deterministic geometry, independently evaluated by the server.
local Geometry = {}
function Geometry.IsFinite(position)
	if typeof(position) ~= "Vector3" then return false end
	for _, n in ipairs({position.X, position.Y, position.Z}) do
		if n ~= n or math.abs(n) == math.huge then return false end
	end
	return true
end
function Geometry.Parameters(map)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {map}
	return params
end
function Geometry.Snap(value, spacing)
	return math.floor(value / spacing + 0.5) * spacing
end
function Geometry.Resolve(map, position, spec, origin)
	if not map or not Geometry.IsFinite(position) then return nil, "Invalid target" end
	local min = map:GetAttribute("TargetMin")
	local max = map:GetAttribute("TargetMax")
	if not min or not max then return nil, "Map is loading" end
	if position.X < min.X or position.X > max.X or position.Z < min.Z or position.Z > max.Z then return nil, "Target must be on the island" end
	local x, z = position.X, position.Z
	if spec.SnapToGrid then x, z = Geometry.Snap(x, spec.GridSpacing), Geometry.Snap(z, spec.GridSpacing) end
	if x < min.X or x > max.X or z < min.Z or z > max.Z then return nil, "Grid point is outside the island" end
	local hit = workspace:Raycast(Vector3.new(x, max.Y, z), Vector3.new(0, min.Y - max.Y, 0), Geometry.Parameters(map))
	if not hit or hit.Normal.Y < 0.5 then return nil, "Surface is not targetable" end
	if origin and (origin - hit.Position).Magnitude > spec.MaxCastDistance then return nil, "Target is out of range" end
	return hit.Position
end
return Geometry

