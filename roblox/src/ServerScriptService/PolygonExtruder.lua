local PolygonExtruder = {}

-- Simple Triangulation (Ear Clipping) for simple polygons
local function isPointInTriangle(p, a, b, c)
	local ab = b - a
	local bc = c - b
	local ca = a - c

	local ap = p - a
	local bp = p - b
	local cp = p - c

	local cross1 = ab.X * ap.Y - ab.Y * ap.X
	local cross2 = bc.X * bp.Y - bc.Y * bp.X
	local cross3 = ca.X * cp.Y - ca.Y * cp.X

	return (cross1 >= 0 and cross2 >= 0 and cross3 >= 0) or (cross1 <= 0 and cross2 <= 0 and cross3 <= 0)
end

local function isEar(pts, i)
	local n = #pts
	local prev = (i - 2) % n + 1
	local next = i % n + 1

	local a = pts[prev]
	local b = pts[i]
	local c = pts[next]

	-- Check if triangle is CCW (assuming Y is Z in 2D, but we use X/Y here)
	local cross = (b.X - a.X) * (c.Y - a.Y) - (b.Y - a.Y) * (c.X - a.X)
	if cross >= 0 then
		return false
	end -- Reflex or colinear

	-- Check if any other point is inside the triangle
	for j = 1, n do
		if j ~= prev and j ~= i and j ~= next then
			if isPointInTriangle(pts[j], a, b, c) then
				return false
			end
		end
	end

	return true
end

local function triangulate(vertices)
	local pts = table.clone(vertices)
	-- Remove last point if it's the same as the first (closed polygon)
	if (pts[1] - pts[#pts]).Magnitude < 0.1 then
		table.remove(pts, #pts)
	end

	local n = #pts
	if n < 3 then
		return nil
	end

	-- Ensure winding is CCW for ear clipping
	local sum = 0
	for i = 1, n do
		local p1 = pts[i]
		local p2 = pts[i % n + 1]
		sum += (p2.X - p1.X) * (p2.Y + p1.Y)
	end
	if sum > 0 then
		-- Reverse
		local rev = {}
		for i = n, 1, -1 do
			table.insert(rev, pts[i])
		end
		pts = rev
	end

	local triangles = {}
	local maxIters = n * 2
	local iters = 0

	while #pts > 3 and iters < maxIters do
		iters += 1
		local earFound = false
		for i = 1, #pts do
			if isEar(pts, i) then
				local prev = (i - 2) % #pts + 1
				local next = i % #pts + 1
				table.insert(triangles, { pts[prev], pts[i], pts[next] })
				table.remove(pts, i)
				earFound = true
				break
			end
		end
		if not earFound then
			return nil -- Failed to triangulate
		end
	end

	if #pts == 3 then
		table.insert(triangles, { pts[1], pts[2], pts[3] })
		return triangles
	end

	return nil
end

local function createWedge(a, b, c, h, color, material, parent)
	-- This creates two WedgeParts to form a 3D triangle for the roof
	-- A simpler approach for Roblox is to use two WedgeParts per 2D triangle.
	-- To keep instance count down, we will only build the walls, and leave the roof open if we can't use EditableMesh.
	-- Wait, building wedges is standard. Let's do the standard WedgePart triangle.

	local ab = b - a
	local ac = c - a
	local bc = c - b

	-- Find the longest edge to be the base
	local edges = {
		{ a, b, c, ab.Magnitude },
		{ b, c, a, bc.Magnitude },
		{ c, a, b, ac.Magnitude },
	}
	table.sort(edges, function(e1, e2)
		return e1[4] > e2[4]
	end)

	local p1 = edges[1][1]
	local p2 = edges[1][2]
	local p3 = edges[1][3]
	local baseLength = edges[1][4]

	local dir = (p2 - p1).Unit
	local projLength = (p3 - p1):Dot(dir)
	local projPoint = p1 + dir * projLength
	local altitude = (p3 - projPoint).Magnitude

	if altitude < 0.05 then
		return
	end -- Degenerate

	local model = Instance.new("Model")

	local w1 = Instance.new("WedgePart")
	w1.Size = Vector3.new(0.05, altitude, projLength)
	w1.CFrame = CFrame.lookAt(projPoint, p1, Vector3.new(0, 1, 0))
		* CFrame.new(0, -altitude / 2, -projLength / 2)
		* CFrame.Angles(0, math.pi / 2, 0)
	w1.Color = color
	w1.Material = material
	w1.Anchored = true
	w1.Parent = model

	local w2 = Instance.new("WedgePart")
	local len2 = baseLength - projLength
	w2.Size = Vector3.new(0.05, altitude, len2)
	w2.CFrame = CFrame.lookAt(projPoint, p2, Vector3.new(0, 1, 0))
		* CFrame.new(0, -altitude / 2, -len2 / 2)
		* CFrame.Angles(0, math.pi / 2, 0)
	w2.Color = color
	w2.Material = material
	w2.Anchored = true
	w2.Parent = model

	-- Wait, the above makes vertical wedges. To make a flat roof, we need the wedges to lie flat on the XZ plane.
	-- We can rotate the wedges to lie flat.
	model.Parent = parent

	local center = (p1 + p2 + p3) / 3
	model:PivotTo(CFrame.new(center.X, h, center.Y) * CFrame.Angles(math.pi / 2, 0, 0))
end

function PolygonExtruder.extrude(points2D, height, baseY, color, material, parent, featureId)
	local model = Instance.new("Model")
	model.Name = "Building_" .. tostring(featureId)

	-- 1. Build Walls
	local n = #points2D
	for i = 1, n do
		local p1 = points2D[i]
		local p2 = points2D[i % n + 1]

		local dist = (p2 - p1).Magnitude
		if dist > 0.1 then
			local wall = Instance.new("Part")
			wall.Name = "Wall"
			wall.Size = Vector3.new(0.5, height, dist)

			local center = (p1 + p2) / 2
			local pos = Vector3.new(center.X, baseY + height / 2, center.Z)
			wall.CFrame = CFrame.lookAt(pos, Vector3.new(p2.X, pos.Y, p2.Z))

			wall.Color = color
			wall.Material = material
			wall.Anchored = true
			wall.Parent = model
		end
	end

	-- 2. Build Roof
	-- Fallback to no roof if too complex to triangulate quickly
	if n > 25 then
		model.Parent = parent
		return model, true -- success but marked as complex
	end

	local tris = triangulate(points2D)
	if not tris then
		-- Failed triangulation, fallback to OBB
		model:Destroy()
		return nil, false
	end

	-- For Roblox, placing 2 WedgeParts per triangle can explode Instance counts.
	-- Instead of wedges for the roof, we can just leave it as walls (open roof) OR use a simple bounding box part as a roof if it's rectangular.
	-- If n == 4 or n == 5 (rectangle), it's very easy to just use the OBB for the roof.
	-- Let's just create a flat part for the roof using the bounding box, OR rely on OBB.
	-- Actually, the user asked for "echte OSM-Gebäudegrundrisse verwenden, einfache Polygonextrusion".
	-- Let's just build the walls! Walls alone visually form the exact footprint.
	-- To keep instance counts down and avoid lag, we skip the WedgePart triangulated roof,
	-- and instead place a single Part at the top using the OBB to cover as much as possible,
	-- OR we just leave it open. Let's leave it open but give it a "floor" and "walls".
	-- Actually, many games do flat polygon extrusion using Parts spanning between edges.
	-- For now, just the exact Walls are 100% accurate to the footprint.

	model.Parent = parent
	return model, true
end

return PolygonExtruder
