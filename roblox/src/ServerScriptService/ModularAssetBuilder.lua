local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent:WaitForChild("RoadStyleConfig"))

local ModularAssetBuilder = {}

-- Helper to create a basic part
local function createPart(name, parent, color, material, size, cframe)
	local p = Instance.new("Part")
	p.Name = name
	p.Parent = parent
	p.Color = color
	p.Material = material
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = true
	return p
end

-- Builds a highly polished 90-degree Cross Junction Prefab
local function buildCrossJunction(assetName, roadWidth)
	local model = Instance.new("Model")
	model.Name = assetName
	
	local swWidth = Config.Sidewalks.DefaultWidth
	local totalWidth = roadWidth + (swWidth * 2)
	
	-- 1. Base (Sidewalk Level)
	-- We create a large square base for the sidewalk
	local base = createPart("SidewalkBase", model, Config.Colors.Pavement, Config.Materials.Pavement, Vector3.new(totalWidth, Config.Sidewalks.Height, totalWidth), CFrame.new(0, Config.Sidewalks.Height/2, 0))
	
	-- 2. Asphalt Surface (Cross)
	-- The central asphalt square
	local asphalt = createPart("AsphaltSurface", model, Config.Colors.Asphalt, Config.Materials.Asphalt, Vector3.new(roadWidth, 0.4, roadWidth), CFrame.new(0, 0.4/2 + 0.05, 0))
	
	-- 3. Pedestrian Crosswalks (White Stripes)
	-- We paint crosswalks on all 4 entries
	for i = 0, 3 do
		local angle = math.rad(i * 90)
		local offset = (roadWidth / 2) - 2 -- 2 studs inward from the edge
		local cframe = CFrame.new(0, 0.4/2 + 0.1, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, offset)
		
		local crosswalk = createPart("Crosswalk_"..i, model, Config.Colors.MarkingWhite, Enum.Material.SmoothPlastic, Vector3.new(roadWidth - 4, 0.1, 4), cframe)
		crosswalk.CanCollide = false
	end
	
	-- Set Primary Part
	model.PrimaryPart = asphalt
	
	return model
end

-- Builds a 90-degree T-Junction Prefab
local function buildTJunction(assetName, roadWidth)
	local model = Instance.new("Model")
	model.Name = assetName
	
	local swWidth = Config.Sidewalks.DefaultWidth
	local totalWidth = roadWidth + (swWidth * 2)
	
	-- Base
	local base = createPart("SidewalkBase", model, Config.Colors.Pavement, Config.Materials.Pavement, Vector3.new(totalWidth, Config.Sidewalks.Height, totalWidth), CFrame.new(0, Config.Sidewalks.Height/2, 0))
	
	-- Asphalt Surface (T-Shape)
	-- Instead of a full cross, we just need a T. But a square asphalt piece is fine, the non-road side will just look like a driveway or we can cover it.
	local asphalt = createPart("AsphaltSurface", model, Config.Colors.Asphalt, Config.Materials.Asphalt, Vector3.new(roadWidth, 0.4, roadWidth), CFrame.new(0, 0.4/2 + 0.05, 0))
	
	-- Set Primary Part
	model.PrimaryPart = asphalt
	
	return model
end

function ModularAssetBuilder.buildAll()
	print("[ModularAssetBuilder] Generating Procedural Road Prefabs...")
	
	local assetsFolder = ReplicatedStorage:FindFirstChild("RoadAssets")
	if assetsFolder then
		assetsFolder:Destroy()
	end
	
	assetsFolder = Instance.new("Folder")
	assetsFolder.Name = "RoadAssets"
	assetsFolder.Parent = ReplicatedStorage
	
	-- Define our standard widths based on Config/Python bounds
	-- Normal Residential: 28 studs
	-- Normal Primary: ~60 studs
	
	local prefabs = {
		buildCrossJunction("CrossJunction_90_28", 28),
		buildCrossJunction("CrossJunction_90_60", 60),
		buildTJunction("TJunction_90_28", 28),
		buildTJunction("TJunction_90_60", 60)
	}
	
	for _, prefab in ipairs(prefabs) do
		prefab.Parent = assetsFolder
	end
	
	print("[ModularAssetBuilder] Built " .. #prefabs .. " Prefabs.")
end

return ModularAssetBuilder
