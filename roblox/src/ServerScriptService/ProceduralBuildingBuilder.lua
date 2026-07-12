local ProceduralBuildingBuilder = {}

-- Color Palettes for typical Norderstedt architecture
local brickColors = {
	Color3.fromRGB(139, 69, 19),   -- Dark Red Brick
	Color3.fromRGB(165, 42, 42),   -- Red Brick
	Color3.fromRGB(205, 133, 63),  -- Sandy Brick
	Color3.fromRGB(245, 245, 220), -- White/Beige Plaster
	Color3.fromRGB(211, 211, 211)  -- Light Grey Plaster
}

local roofColors = {
	Color3.fromRGB(100, 20, 20),   -- Dark Red Roof
	Color3.fromRGB(50, 50, 50),    -- Anthracite / Black Roof
	Color3.fromRGB(139, 69, 19)    -- Brown Roof
}

local modernColors = {
	Color3.fromRGB(230, 230, 230), -- White Concrete
	Color3.fromRGB(100, 100, 100), -- Dark Concrete
	Color3.fromRGB(150, 150, 150)  -- Grey Concrete
}

-- Simple pseudo-random generator based on a seed (like feature ID)
local function getSeededRandom(seed, max)
	-- Use a simple hash of the seed string to get a number
	local hash = 0
	for i = 1, #seed do
		hash = (hash * 31 + string.byte(seed, i)) % 1000000
	end
	return (hash % max) + 1
end

function ProceduralBuildingBuilder.buildOBB(feature, folder, scale, scaleFactor)
	local obb = feature.OBB
	local x = obb.CenterLocalMeters[1] * scale
	local z = obb.CenterLocalMeters[2] * scale
	local w = obb.SizeMeters[1] * scale * scaleFactor
	local d = obb.SizeMeters[2] * scale * scaleFactor
	local rot = math.rad(obb.RotationDegrees)

	local model = Instance.new("Model")
	model.Name = "Bldg_" .. feature.Id
	model.Parent = folder

	-- Determine Building Type based on footprint area
	local area = w * d
	local isResidential = area < 500 -- Studs squared (roughly 500 sqm)
	
	-- Height Variation
	local baseHeight = isResidential and 20 or 40
	-- Seeded random height variation (+0 to +20 studs)
	local h = baseHeight + (getSeededRandom(feature.Id, 20))

	-- 1. Base Building Block
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = true
	base.Size = Vector3.new(w, h, d)
	base.CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, -rot, 0)
	
	if isResidential then
		base.Color = brickColors[getSeededRandom(feature.Id .. "_color", #brickColors)]
		base.Material = Enum.Material.Brick
	else
		base.Color = modernColors[getSeededRandom(feature.Id .. "_color", #modernColors)]
		base.Material = Enum.Material.Concrete
	end
	
	base.Parent = model
	model.PrimaryPart = base

	-- 2. Roof Generation
	if isResidential then
		-- Pitched Roof (Satteldach)
		local roofH = 10 + getSeededRandom(feature.Id .. "_roof", 10)
		local rColor = roofColors[getSeededRandom(feature.Id .. "_rcolor", #roofColors)]
		local rMat = Enum.Material.Slate

		-- We orient the roof along the longer side
		local isWide = w > d
		local rW = isWide and w or d
		local rD = isWide and d or w

		local w1 = Instance.new("WedgePart")
		w1.Name = "RoofLeft"
		w1.Anchored = true
		w1.Color = rColor
		w1.Material = rMat
		w1.Size = Vector3.new(rW, roofH, rD/2)
		
		local w2 = Instance.new("WedgePart")
		w2.Name = "RoofRight"
		w2.Anchored = true
		w2.Color = rColor
		w2.Material = rMat
		w2.Size = Vector3.new(rW, roofH, rD/2)

		if isWide then
			-- Ridge along X axis
			w1.CFrame = base.CFrame * CFrame.new(0, h/2 + roofH/2, -rD/4) * CFrame.Angles(0, 0, 0)
			w2.CFrame = base.CFrame * CFrame.new(0, h/2 + roofH/2, rD/4) * CFrame.Angles(0, math.pi, 0)
		else
			-- Ridge along Z axis
			w1.CFrame = base.CFrame * CFrame.new(-rD/4, h/2 + roofH/2, 0) * CFrame.Angles(0, -math.pi/2, 0)
			w2.CFrame = base.CFrame * CFrame.new(rD/4, h/2 + roofH/2, 0) * CFrame.Angles(0, math.pi/2, 0)
		end

		w1.Parent = model
		w2.Parent = model
	else
		-- Commercial: Flat roof with small rim
		local rim = Instance.new("Part")
		rim.Name = "RoofRim"
		rim.Anchored = true
		rim.Color = Color3.fromRGB(50, 50, 50)
		rim.Material = Enum.Material.Concrete
		rim.Size = Vector3.new(w + 1, 2, d + 1)
		rim.CFrame = base.CFrame * CFrame.new(0, h/2 + 1, 0)
		rim.Parent = model
	end

	-- 3. Simple Windows (Neon strips)
	if not isResidential then
		-- Commercial windows
		local win = Instance.new("Part")
		win.Name = "WindowStrip"
		win.Anchored = true
		win.Color = Color3.fromRGB(150, 200, 255)
		win.Material = Enum.Material.Neon
		-- Create a strip around the building
		win.Size = Vector3.new(w + 0.2, h * 0.4, d + 0.2)
		win.CFrame = base.CFrame * CFrame.new(0, h * 0.1, 0)
		win.Parent = model
	end

	return model
end

return ProceduralBuildingBuilder
