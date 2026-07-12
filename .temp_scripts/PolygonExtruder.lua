local PolygonExtruder = {}

function PolygonExtruder.extrude(points, height, color, material, folder)
	if #points < 3 then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = "ExtrudedPolygon"
	model.Parent = folder

	for i = 1, #points do
		local p1 = points[i]
		local p2 = points[(i % #points) + 1]

		local dist = (p2 - p1).Magnitude
		if dist > 0.1 then
			local wall = Instance.new("Part")
			wall.Name = "Wall_" .. i
			wall.Anchored = true
			wall.CanTouch = false
			wall.CanQuery = false
			wall.CanCollide = true
			wall.Color = color
			wall.Material = material

			wall.Size = Vector3.new(0.5, height, dist)

			local midPoint = p1 + (p2 - p1) / 2
			local lookAt = CFrame.lookAt(midPoint, p2)

			wall.CFrame = CFrame.new(midPoint.X, height / 2, midPoint.Z) * lookAt.Rotation
			wall.Parent = model
		end
	end

	local roof = Instance.new("Part")
	roof.Name = "RoofFallback"
	roof.Anchored = true
	roof.CanTouch = false
	roof.CanQuery = false
	roof.CanCollide = true
	roof.Color = color
	roof.Material = material

	local minX, minZ = math.huge, math.huge
	local maxX, maxZ = -math.huge, -math.huge

	for _, p in ipairs(points) do
		if p.X < minX then
			minX = p.X
		end
		if p.X > maxX then
			maxX = p.X
		end
		if p.Z < minZ then
			minZ = p.Z
		end
		if p.Z > maxZ then
			maxZ = p.Z
		end
	end

	local w = maxX - minX
	local d = maxZ - minZ
	local cx = minX + w / 2
	local cz = minZ + d / 2

	roof.Size = Vector3.new(w, 0.5, d)
	roof.CFrame = CFrame.new(cx, height, cz)
	roof.Parent = model

	return model
end

return PolygonExtruder
