local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local cityData = ReplicatedStorage:WaitForChild("CityData")
local manifest = require(cityData:WaitForChild("Manifest"))
local scale = manifest.MetersToStuds

local RoadBuilder = require(ServerScriptService:WaitForChild("RoadBuilder"))
local PolygonExtruder = require(ServerScriptService:WaitForChild("PolygonExtruder"))
local BuildingRenderConfig = require(ServerScriptService:WaitForChild("BuildingRenderConfig"))
local Config = require(ServerScriptService:WaitForChild("RoadStyleConfig"))

local startTime = os.clock()

local statusFolder = ReplicatedStorage:FindFirstChild("ImportStatus")
if not statusFolder then
	statusFolder = Instance.new("Folder")
	statusFolder.Name = "ImportStatus"
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
	Intersections = Instance.new("Folder", cityGeometry),
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

local tileFoldersMap = {}
local function getTileFolders(tileId)
	if not tileFoldersMap[tileId] then
		tileFoldersMap[tileId] = {}
		for catName, catRoot in pairs(categoryFolders) do
			local f = Instance.new("Folder")
			f.Name = tileId
			f.Parent = catRoot
			tileFoldersMap[tileId][catName] = f
		end
	end
	return tileFoldersMap[tileId]
end

local stats = {
	BuildingsExpected = 0,
	BuildingsCreated = 0,
	BuildingsOBB = 0,
	BuildingsPolygon = 0,
	BuildingsFallback = 0,
	BuildingsRejected = 0,
	MaxBuildingExtentStuds = 0,
	UniqueRoundedXCenters = {},
	UniqueRoundedZCenters = {},
	RoadSegments = 0,
	JunctionNodes = 0,
	TJunctions = 0,
	CrossJunctions = 0,
	ComplexJunctions = 0,
	FlyModeIncluded = 0,
	BuildingParts = 0,
	BuildingOBBFallbacks = 0,
	GreenParts = 0,
	WaterParts = 0,
	RailParts = 0,
	POIParts = 0,
	RoadSurfaceParts = 0,
	RoadMarkingParts = 0,
	SidewalkParts = 0,
	CurbParts = 0,
	IntersectionParts = 0
}

local function trackPart(statKey, count)
	if stats[statKey] ~= nil then
		stats[statKey] += count
	end
end

local cameraPoints = Instance.new("Folder")
cameraPoints.Name = "CameraPoints"
cameraPoints.Parent = Workspace

local function addCameraPoint(name, pos)
	local v = Instance.new("Vector3Value")
	v.Name = name
	v.Value = pos
	v.Parent = cameraPoints
end

local bounds = manifest.LocalBoundsStuds
local minX = bounds.MinX
local minZ = bounds.MinZ
local maxX = bounds.MaxX
local maxZ = bounds.MaxZ
local centerX = (minX + maxX) / 2
local centerZ = (minZ + maxZ) / 2
local sizeX = math.max(1, maxX - minX)
local sizeZ = math.max(1, maxZ - minZ)

addCameraPoint("CenterOverview", Vector3.new(centerX, 2500, centerZ))

do
	local ground = Instance.new("Part")
	ground.Name = "PilotGround"
	ground.Anchored = true
	ground.CanCollide = true
	ground.Color = Color3.fromRGB(50, 100, 50)
	ground.Material = Enum.Material.Grass
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

local spawnCandidates = {}

local function loadJunctions()
	local junctionMap = {}
	local jData = cityData:FindFirstChild("Junctions")
	if not jData then return junctionMap end

	for _, chunkModule in ipairs(jData:GetChildren()) do
		local tileId = chunkModule.Name
		local tileFolders = getTileFolders(tileId)
		local chunkData = require(chunkModule)

		for _, node in ipairs(chunkData) do
			stats.JunctionNodes += 1
			if node.JunctionType == "TJunction" then stats.TJunctions += 1
			elseif node.JunctionType == "CrossJunction" then stats.CrossJunctions += 1
			elseif node.JunctionType == "ComplexJunction" then stats.ComplexJunctions += 1
			end

			local cx = math.floor(node.LocalPositionMeters[1] * scale * 10) / 10
			local cz = math.floor(node.LocalPositionMeters[2] * scale * 10) / 10
			local key = cx .. "_" .. cz
			junctionMap[key] = node

			if node.Degree > 2 and not node.IsBridge and not node.IsTunnel then
				local maxW = 5
				for _, w in ipairs(node.WidthsStuds) do
					if w * scale > maxW then maxW = w * scale end
				end
				-- Radius exactly matches road half-width plus sidewalk width to bridge the gap
				local rad = (maxW / 2) + Config.Sidewalks.DefaultWidth
				
				local rad = (maxW / 2) + Config.Sidewalks.DefaultWidth
				
				local part = Instance.new("Part")
				part.Name = "Junction_" .. node.NodeId
				part.Shape = Enum.PartType.Cylinder
				part.Size = Vector3.new(0.4, rad * 2, rad * 2)
				part.CFrame = CFrame.new(node.LocalPositionMeters[1] * scale, Config.Layers.Road, node.LocalPositionMeters[2] * scale) * CFrame.Angles(0, 0, math.pi/2)
				part.Color = Config.Colors.Asphalt
				part.Material = Config.Materials.Asphalt
				part.Anchored = true
				part.Parent = tileFolders.Intersections
				trackPart("IntersectionParts", 1)
				
				if node.JunctionType == "TJunction" then addCameraPoint("TJunction", part.Position + Vector3.new(0, 15, 0))
				elseif node.JunctionType == "CrossJunction" then addCameraPoint("CrossJunction", part.Position + Vector3.new(0, 15, 0))
				elseif node.JunctionType == "ComplexJunction" then addCameraPoint("Intersection", part.Position + Vector3.new(0, 15, 0))
				end
			end
		end
	end
	return junctionMap
end

local function importRoadsAndRailAndWater(junctionMap)
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

					local cumulativeDist = 0
					for i = 1, #coords - 1 do
						local p1 = Vector3.new(coords[i][1] * scale, 0, coords[i][2] * scale)
						local p2 = Vector3.new(coords[i + 1][1] * scale, 0, coords[i + 1][2] * scale)

						RoadBuilder.buildRoadSegment(p1, p2, widthStuds, feature, tileFolders, scale, junctionMap, cumulativeDist)
						cumulativeDist += (p2 - p1).Magnitude
						trackPart("RoadSurfaceParts", 1)
						trackPart("RoadMarkingParts", 3)
						trackPart("SidewalkParts", 2)
						trackPart("CurbParts", 2)

						if i == 1 then
							local hw = feature.Properties.highway
							if hw == "primary" or hw == "secondary" then
								addCameraPoint("MainRoad", p1 + Vector3.new(0, 10, 0))
							elseif hw == "residential" then
								addCameraPoint("ResidentialArea", p1 + Vector3.new(0, 10, 0))
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
							part.CanCollide = true
							part.Color = color
							part.Material = material
							part.Size = Vector3.new(4, height, dist)
							local lookAt = CFrame.lookAt(p1, p2)
							part.CFrame = CFrame.new(p1.X, layerY + height / 2, p1.Z) * lookAt.Rotation * CFrame.new(0, 0, -dist / 2)
							part.Parent = tileFolders[outCategory]
							trackPart(statKey, 1)
						end
					end
				end
			end
		end
	end

	importSimpleLines("Rail", "Rail", Color3.fromRGB(80, 80, 80), Enum.Material.Metal, 0.2, 0.6, "RailParts")
	importSimpleLines("Water", "Water", Color3.fromRGB(50, 150, 255), Enum.Material.Glass, -0.5, 0.5, "WaterParts")
end

local function buildOBB(feature, tileFolders)
	local obb = feature.OBB
	local x = obb.CenterLocalMeters[1] * scale
	local z = obb.CenterLocalMeters[2] * scale
	local w = obb.SizeMeters[1] * scale
	local d = obb.SizeMeters[2] * scale
	local h = BuildingRenderConfig.DefaultHeightStuds
	local rot = math.rad(obb.RotationDegrees)

	local part = Instance.new("Part")
	part.Name = "Bldg_" .. feature.Id
	part.Anchored = true
	part.CanCollide = true
	part.Color = BuildingRenderConfig.DefaultColor
	part.Material = Enum.Material.SmoothPlastic
	part.Size = Vector3.new(w, h, d)
	part.CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, -rot, 0)
	part.Parent = tileFolders.Buildings
	trackPart("BuildingParts", 1)
	return true
end

local function buildPolygon(feature, tileFolders)
	local coords = feature.Geometry
	if not coords or #coords < 3 then return false end

	local points = {}
	for _, c in ipairs(coords) do
		table.insert(points, Vector3.new(c[1] * scale, 0, c[2] * scale))
	end

	local h = BuildingRenderConfig.DefaultHeightStuds
	local col = BuildingRenderConfig.DefaultColor
	local mat = Enum.Material.SmoothPlastic

	local model = PolygonExtruder.extrude(points, h, col, mat, tileFolders.Buildings)
	if model then
		model.Name = "BldgPoly_" .. feature.Id
		trackPart("BuildingParts", #model:GetChildren())
		return true
	end
	return false
end

local function importBuildings()
	local bData = cityData:FindFirstChild("Buildings")
	if not bData then return end

	for _, chunkModule in ipairs(bData:GetChildren()) do
		local tileId = chunkModule.Name
		local tileFolders = getTileFolders(tileId)
		local chunkData = require(chunkModule)

		for _, feature in ipairs(chunkData) do
			stats.BuildingsExpected += 1

			local success = false

			if BuildingRenderConfig.UseOBB and feature.OBB then
				success = buildOBB(feature, tileFolders)
				if success then stats.BuildingsOBB += 1 end
			elseif BuildingRenderConfig.UsePolygon and feature.Geometry then
				success = buildPolygon(feature, tileFolders)
				if success then stats.BuildingsPolygon += 1 end
			end

			if not success and BuildingRenderConfig.FallbackToOBB and feature.OBB then
				success = buildOBB(feature, tileFolders)
				if success then
					stats.BuildingsFallback += 1
					stats.BuildingOBBFallbacks += 1
				end
			end

			if success then
				stats.BuildingsCreated += 1
				
				if feature.OBB then
					local w = feature.OBB.SizeMeters[1] * scale
					local d = feature.OBB.SizeMeters[2] * scale
					if w > stats.MaxBuildingExtentStuds then stats.MaxBuildingExtentStuds = w end
					if d > stats.MaxBuildingExtentStuds then stats.MaxBuildingExtentStuds = d end

					local xRound = math.floor(feature.OBB.CenterLocalMeters[1] / 100)
					local zRound = math.floor(feature.OBB.CenterLocalMeters[2] / 100)
					stats.UniqueRoundedXCenters[tostring(xRound)] = true
					stats.UniqueRoundedZCenters[tostring(zRound)] = true
				end
			else
				stats.BuildingsRejected += 1
			end
		end
	end
end

local function importPOIs()
	local pData = cityData:FindFirstChild("POIs")
	if not pData then return end

	for _, chunkModule in ipairs(pData:GetChildren()) do
		local tileId = chunkModule.Name
		local tileFolders = getTileFolders(tileId)
		local chunkData = require(chunkModule)

		for _, feature in ipairs(chunkData) do
			local p1 = feature.Geometry
			if type(p1) == "table" and #p1 == 2 then
				local part = Instance.new("Part")
				part.Name = "POI_" .. feature.Id
				part.Anchored = true
				part.CanCollide = false
				part.Shape = Enum.PartType.Ball
				part.Size = Vector3.new(3, 3, 3)
				part.Color = Color3.fromRGB(255, 100, 100)
				part.Material = Enum.Material.Neon
				part.CFrame = CFrame.new(p1[1] * scale, 10, p1[2] * scale)
				part.Parent = tileFolders.POIs
				
				if feature.Properties and feature.Properties.name then
					local bg = Instance.new("BillboardGui")
					bg.Name = "POILabel"
					bg.Size = UDim2.new(0, 250, 0, 50)
					bg.StudsOffset = Vector3.new(0, 10, 0)
					bg.AlwaysOnTop = true
					bg.MaxDistance = 1500
					
					local label = Instance.new("TextLabel")
					label.Parent = bg
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.Text = feature.Properties.name
					label.TextColor3 = Color3.fromRGB(255, 255, 0)
					label.TextStrokeTransparency = 0
					label.TextScaled = true
					label.Font = Enum.Font.GothamBold
					bg.Parent = part
				end
				
				trackPart("POIParts", 1)
			end
		end
	end
end

local junctionMap = loadJunctions()
importRoadsAndRailAndWater(junctionMap)
importBuildings()

local uniqueXCount = 0
for _ in pairs(stats.UniqueRoundedXCenters) do uniqueXCount += 1 end
local uniqueZCount = 0
for _ in pairs(stats.UniqueRoundedZCenters) do uniqueZCount += 1 end

if uniqueXCount <= 5 or uniqueZCount <= 5 then
	warn(string.format("Sanity Check Failed: Unique X clusters=%d, Z clusters=%d. The map is likely crushed or partial.", uniqueXCount, uniqueZCount))
	error("Map distribution sanity check failed! Halting importer.")
end
if stats.MaxBuildingExtentStuds > 2000 then
	warn(string.format("Sanity Check Failed: Maximum building extent is %.1f Studs. Coordinate mapping is likely broken.", stats.MaxBuildingExtentStuds))
	error("Building dimension sanity check failed! Halting importer.")
end

importPOIs()

local spawnLoc = Workspace:FindFirstChild("SpawnLocation")
if not spawnLoc then
	spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "SpawnLocation"
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = true
	spawnLoc.Size = Vector3.new(8, 1, 8)
	spawnLoc.Color = Color3.fromRGB(200, 200, 200)
	spawnLoc.Parent = Workspace
end

local bestSpawn = Vector3.new(centerX, 2, centerZ)
if #spawnCandidates > 0 then
	bestSpawn = spawnCandidates[1]
	for _, c in ipairs(spawnCandidates) do
		if (c - Vector3.new(centerX, 0, centerZ)).Magnitude < (bestSpawn - Vector3.new(centerX, 0, centerZ)).Magnitude then
			bestSpawn = c
		end
	end
end
spawnLoc.CFrame = CFrame.new(bestSpawn)

print("========== ROBO ROBLOX IMPORT STATS ==========")
local duration = os.clock() - startTime
print(string.format("Duration: %.2fs", duration))
for k, v in pairs(stats) do
	if type(v) == "table" then
		local c = 0
		for _ in pairs(v) do c += 1 end
		print(k .. ": " .. c)
	else
		print(k .. ": " .. tostring(v))
	end
end
print("==============================================")

setStatus("DurationSeconds", math.floor(duration))
setStatus("State", "COMPLETED")
print("City Import Phase 2 completed successfully!")
