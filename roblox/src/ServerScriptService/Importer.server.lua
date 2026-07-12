local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local cityData = ReplicatedStorage:WaitForChild("CityData")
local manifest = require(cityData:WaitForChild("Manifest"))

local PolygonExtruder = require(script.Parent:WaitForChild("PolygonExtruder"))
local RoadBuilder = require(script.Parent:WaitForChild("RoadBuilder"))
local Config = require(script.Parent:WaitForChild("RoadStyleConfig"))

local scale = manifest.MetersToStuds or 3.571428

-- Setup Status
local statusFolder = ReplicatedStorage:FindFirstChild("CityImportStatus")
if not statusFolder then
	statusFolder = Instance.new("Folder")
	statusFolder.Name = "CityImportStatus"
	statusFolder.Parent = ReplicatedStorage
end

local function setStatus(name, value)
	local valObj = statusFolder:FindFirstChild(name)
	if not valObj then
		if type(value) == "number" then
			valObj = Instance.new("NumberValue")
		else
			valObj = Instance.new("StringValue")
		end
		valObj.Name = name
		valObj.Parent = statusFolder
	end
	valObj.Value = value
end

setStatus("State", "RUNNING")
setStatus("RoadsCreated", 0)
setStatus("BuildingsCreated", 0)
setStatus("Failed", 0)
setStatus("DurationSeconds", 0)

-- Clear old Geometry
local oldGeometry = Workspace:FindFirstChild("CityGeometry")
if oldGeometry then
	oldGeometry:Destroy()
end

local cityGeometry = Instance.new("Folder")
cityGeometry.Name = "CityGeometry"
cityGeometry.Parent = Workspace

local categoryFolders = {
	Roads = Instance.new("Folder", cityGeometry),
	RoadMarkings = Instance.new("Folder", cityGeometry),
	Sidewalks = Instance.new("Folder", cityGeometry),
	Buildings = Instance.new("Folder", cityGeometry),
	Green = Instance.new("Folder", cityGeometry),
	Water = Instance.new("Folder", cityGeometry),
	Rail = Instance.new("Folder", cityGeometry),
	POIs = Instance.new("Folder", cityGeometry),
	TrafficControl = Instance.new("Folder", cityGeometry),
}
for name, folder in pairs(categoryFolders) do
	folder.Name = name
end

print("Starting City Import Phase 2 from Source:", manifest.Source)
local startTime = os.clock()

local stats = {
	RoadSurfaceParts = 0,
	RoadMarkingParts = 0,
	SidewalkParts = 0,
	CurbParts = 0,
	IntersectionParts = 0,
	BuildingParts = 0,
	BuildingOBBFallbacks = 0,
	GreenParts = 0,
	WaterParts = 0,
	RailParts = 0,
	POIMarkers = 0,
	TotalInstances = 0,
	Failed = 0,
}

local spawnCandidates = {}
local cameraPoints = {
	CenterOverview = Vector3.zero,
	MainRoad = Vector3.zero,
	ResidentialArea = Vector3.zero,
	Intersection = Vector3.zero,
	WaterArea = Vector3.zero,
	RailArea = Vector3.zero,
	POIArea = Vector3.zero,
}

local function getTileFolders(tileId)
	local folders = {}
	for catName, catRoot in pairs(categoryFolders) do
		local tileFolder = catRoot:FindFirstChild(tileId)
		if not tileFolder then
			tileFolder = Instance.new("Folder")
			tileFolder.Name = tileId
			tileFolder.Parent = catRoot
		end
		folders[catName] = tileFolder
	end
	return folders
end

local function trackPart(cat, count)
	stats[cat] += (count or 1)
	stats.TotalInstances += (count or 1)
end

-- 1. Create Ground
local bounds = manifest.LocalBoundsStuds
local centerX = (bounds.MinX + bounds.MaxX) / 2
local centerZ = (bounds.MinZ + bounds.MaxZ) / 2
cameraPoints.CenterOverview = Vector3.new(centerX, 200, centerZ)

if math.abs(centerX) < 10000 and math.abs(centerZ) < 10000 then
	local sizeX = bounds.MaxX - bounds.MinX + 100
	local sizeZ = bounds.MaxZ - bounds.MinZ + 100

	local ground = Instance.new("Part")
	ground.Name = "PilotGround_Base"
	ground.Anchored = true
	ground.CanCollide = true
	ground.Material = Enum.Material.Grass
	ground.Color = Color3.fromRGB(100, 150, 100)
	ground.Size = Vector3.new(sizeX, 1, sizeZ)
	ground.CFrame = CFrame.new(centerX, -0.5, centerZ)
	ground.Parent = cityGeometry
	trackPart("GreenParts", 1)

	local safety = Instance.new("Part")
	safety.Name = "PilotSafetyFloor"
	safety.Anchored = true
	safety.CanCollide = true
	safety.Transparency = 1
	safety.Size = Vector3.new(sizeX + 1000, 16, sizeZ + 1000)
	safety.CFrame = CFrame.new(centerX, -8, centerZ)
	safety.Parent = cityGeometry
	trackPart("GreenParts", 1)
end

local function importRoadsAndRailAndWater()
	local roadsData = cityData:FindFirstChild("Roads")
	if roadsData then
		for _, chunkModule in ipairs(roadsData:GetChildren()) do
			local tileId = chunkModule.Name
			local tileFolders = getTileFolders(tileId)
			local chunkData = require(chunkModule)

			for _, feature in ipairs(chunkData) do
				local coords = feature.Geometry
				if #coords >= 2 then
					local widthMeters = feature.Properties.OSMWidthMeters or 4.0
					local widthStuds = feature.Properties.FinalWidthStuds or (widthMeters * scale)

					for i = 1, #coords - 1 do
						local p1 = Vector3.new(coords[i][1] * scale, 0, coords[i][2] * scale)
						local p2 = Vector3.new(coords[i + 1][1] * scale, 0, coords[i + 1][2] * scale)

						RoadBuilder.buildRoadSegment(p1, p2, widthStuds, feature, tileFolders, scale)
						trackPart("RoadSurfaceParts", 1)
						trackPart("RoadMarkingParts", 3) -- approx 3 per segment
						trackPart("SidewalkParts", 2)
						trackPart("CurbParts", 2)

						if i == 1 then
							local hw = feature.Properties.highway
							if hw == "primary" or hw == "secondary" then
								cameraPoints.MainRoad = p1 + Vector3.new(0, 10, 0)
							elseif hw == "residential" then
								cameraPoints.ResidentialArea = p1 + Vector3.new(0, 10, 0)
							end
							table.insert(spawnCandidates, p1 + Vector3.new(0, 3, 0))
						end
					end
				end
			end
		end
	end

	local function importSimpleLines(category, outCategory, color, material, layerY, height, statKey)
		local dataFolder = cityData:FindFirstChild(category)
		if not dataFolder then
			return
		end
		for _, chunkModule in ipairs(dataFolder:GetChildren()) do
			local tileFolders = getTileFolders(chunkModule.Name)
			local chunkData = require(chunkModule)
			for _, feature in ipairs(chunkData) do
				local coords = feature.Geometry
				if #coords >= 2 then
					for i = 1, #coords - 1 do
						local p1 = Vector3.new(coords[i][1] * scale, layerY + height / 2, coords[i][2] * scale)
						local p2 = Vector3.new(coords[i + 1][1] * scale, layerY + height / 2, coords[i + 1][2] * scale)
						local dist = (p2 - p1).Magnitude
						if dist > 0.1 then
							local part = Instance.new("Part")
							part.Name = category .. "_" .. feature.Id
							part.Anchored = true
							part.CanCollide = false
							part.Color = color
							part.Material = material
							part.Size = Vector3.new(4, height, dist)
							part.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -dist / 2)
							part.Parent = tileFolders[outCategory]
							trackPart(statKey, 1)

							if category == "Rail" then
								cameraPoints.RailArea = p1 + Vector3.new(0, 10, 0)
							end
						end
					end
				end
			end
		end
	end

	importSimpleLines("Rail", "Rail", Config.Colors.Rail, Config.Materials.Rail, Config.Layers.Rail, 0.4, "RailParts")
	importSimpleLines(
		"Water",
		"Water",
		Config.Colors.Water,
		Config.Materials.Water,
		Config.Layers.Water,
		0.1,
		"WaterParts"
	)
end

local function importBuildings()
	local bData = cityData:FindFirstChild("Buildings")
	if not bData then
		return
	end

	for _, chunkModule in ipairs(bData:GetChildren()) do
		local tileFolders = getTileFolders(chunkModule.Name)
		local chunkData = require(chunkModule)

		for _, feature in ipairs(chunkData) do
			local pts = {}
			if feature.Type == "Polygon" then
				for _, pt in ipairs(feature.Geometry) do
					table.insert(pts, Vector3.new(pt[1] * scale, 0, pt[2] * scale))
				end
			end

			local hMeters = feature.Properties.HeightMeters or 8.0
			local hStuds = hMeters * scale
			local bType = feature.Properties.building or "yes"

			local color = Color3.fromRGB(200, 200, 200)
			if bType == "residential" or bType == "apartments" then
				color = Color3.fromRGB(180, 170, 160)
			elseif bType == "commercial" or bType == "retail" then
				color = Color3.fromRGB(150, 180, 200)
			elseif bType == "industrial" then
				color = Color3.fromRGB(130, 130, 130)
			elseif bType == "school" or bType == "hospital" then
				color = Color3.fromRGB(220, 220, 200)
			end

			local success = false
			if #pts >= 3 then
				local model, isComplex = PolygonExtruder.extrude(
					pts,
					hStuds,
					0,
					color,
					Enum.Material.SmoothPlastic,
					tileFolders.Buildings,
					feature.Id
				)
				if model then
					success = true
					trackPart("BuildingParts", #model:GetChildren())
					if isComplex then
						stats.BuildingOBBFallbacks += 1
					end
				end
			end

			if not success and feature.OBB then
				-- Fallback to OBB
				local cx = feature.OBB.CenterLocalMeters[1]
				local cz = feature.OBB.CenterLocalMeters[2]
				local part = Instance.new("Part")
				part.Name = "BuildingOBB_" .. feature.Id
				part.Anchored = true
				part.Size = Vector3.new(feature.OBB.SizeMeters[1] * scale, hStuds, feature.OBB.SizeMeters[2] * scale)
				part.CFrame = CFrame.new(cx * scale, hStuds / 2, cz * scale)
					* CFrame.Angles(0, math.rad(-feature.OBB.RotationDegrees), 0)
				part.Color = color
				part.Material = Enum.Material.SmoothPlastic
				part.Parent = tileFolders.Buildings
				trackPart("BuildingParts", 1)
				stats.BuildingOBBFallbacks += 1
			end
		end
	end
end

local function importPOIs()
	local poiData = cityData:FindFirstChild("Pois")
	if not poiData then
		return
	end

	for _, chunkModule in ipairs(poiData:GetChildren()) do
		local tileFolders = getTileFolders(chunkModule.Name)
		local chunkData = require(chunkModule)

		for _, feature in ipairs(chunkData) do
			local pt = feature.Geometry
			if feature.Type == "Point" then
				local pos = Vector3.new(pt[1] * scale, 5, pt[2] * scale)

				local marker = Instance.new("Part")
				marker.Name = "POI_" .. feature.Id
				marker.Anchored = true
				marker.CanCollide = false
				marker.Transparency = 1
				marker.Size = Vector3.new(1, 1, 1)
				marker.CFrame = CFrame.new(pos)
				marker.Parent = tileFolders.POIs

				local bb = Instance.new("BillboardGui")
				bb.Name = "QA_POI_Label"
				bb.Size = UDim2.new(0, 150, 0, 40)
				bb.StudsOffset = Vector3.new(0, 2, 0)
				bb.MaxDistance = 1000
				bb.AlwaysOnTop = true

				local label = Instance.new("TextLabel")
				label.Size = UDim2.new(1, 0, 1, 0)
				label.BackgroundTransparency = 0.5
				label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				label.TextColor3 = Color3.fromRGB(255, 255, 0)
				label.TextStrokeTransparency = 0
				label.TextSize = 14

				local name = feature.Properties.name or "Unknown"
				local typ = feature.Properties.amenity
					or feature.Properties.shop
					or feature.Properties.public_transport
					or feature.Properties.railway
					or "POI"
				label.Text = string.format("[%s]\n%s", string.upper(typ), name)

				label.Parent = bb
				bb.Parent = marker

				trackPart("POIMarkers", 1)
				cameraPoints.POIArea = pos + Vector3.new(0, 10, 0)
			end
		end
	end
end

local function importGreen()
	local gData = cityData:FindFirstChild("Green")
	if not gData then
		return
	end
	for _, chunkModule in ipairs(gData:GetChildren()) do
		local tileFolders = getTileFolders(chunkModule.Name)
		local chunkData = require(chunkModule)
		for _, feature in ipairs(chunkData) do
			local pts = {}
			if feature.Type == "Polygon" then
				for _, pt in ipairs(feature.Geometry) do
					table.insert(pts, Vector3.new(pt[1] * scale, 0, pt[2] * scale))
				end
				-- We could use PolygonExtruder, but for green it's flat ground.
				-- Just use OBB fallback or a flat polygon.
				if feature.OBB then
					local cx = feature.OBB.CenterLocalMeters[1]
					local cz = feature.OBB.CenterLocalMeters[2]
					local part = Instance.new("Part")
					part.Anchored = true
					part.CanCollide = false
					part.Size = Vector3.new(feature.OBB.SizeMeters[1] * scale, 0.1, feature.OBB.SizeMeters[2] * scale)
					part.CFrame = CFrame.new(cx * scale, Config.Layers.Green, cz * scale)
						* CFrame.Angles(0, math.rad(-feature.OBB.RotationDegrees), 0)
					part.Color = Config.Colors.Green
					part.Material = Config.Materials.Green
					part.Parent = tileFolders.Green
					trackPart("GreenParts", 1)
				end
			end
		end
	end
end

importRoadsAndRailAndWater()
importBuildings()
importGreen()
importPOIs()

-- Export Camera points
local cpFolder = Instance.new("Folder", Workspace)
cpFolder.Name = "CameraPoints"
for k, v in pairs(cameraPoints) do
	local p = Instance.new("Vector3Value", cpFolder)
	p.Name = k
	p.Value = v
end

-- 2. Spawn Selection
local spawnLoc = Workspace:FindFirstChild("SpawnLocation")
if not spawnLoc then
	spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "SpawnLocation"
	spawnLoc.Parent = Workspace
end
spawnLoc.Size = Vector3.new(10, 1, 10)
spawnLoc.Anchored = true
spawnLoc.CanCollide = true
spawnLoc.Transparency = 1

local bestSpawn = Vector3.new(0, 5, 0)
local minCenterDist = math.huge
for _, cand in ipairs(spawnCandidates) do
	local dist = Vector2.new(cand.X, cand.Z).Magnitude
	if dist < minCenterDist then
		minCenterDist = dist
		bestSpawn = cand
	end
end
spawnLoc.CFrame = CFrame.new(bestSpawn)

local duration = os.clock() - startTime
setStatus("DurationSeconds", duration)
setStatus("State", "COMPLETE")

print(string.format("Import Complete in %.2fs", duration))
print("Import Stats:")
for k, v in pairs(stats) do
	print(" - " .. k .. ": " .. tostring(v))
end

-- Set Workspace properties
Workspace.StreamingEnabled = true
Workspace.StreamingMinRadius = 256
Workspace.StreamingTargetRadius = 1024
