local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local cityData = ReplicatedStorage:WaitForChild("CityData")
local manifest = require(cityData:WaitForChild("Manifest"))

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

local cityGeometry = Workspace:FindFirstChild("CityGeometry")
if cityGeometry then
    cityGeometry:Destroy()
end
cityGeometry = Instance.new("Folder")
cityGeometry.Name = "CityGeometry"
cityGeometry.Parent = Workspace

print("Starting City Import Phase 1C from Source:", manifest.Source)
local startTime = os.clock()

local stats = {
    roads = 0,
    buildings = 0,
    rail = 0,
    water = 0,
    green = 0,
    failed = 0
}

local spawnCandidates = {}

-- 1. Create Ground
local bounds = manifest.LocalBoundsStuds
local centerX = (bounds.MinX + bounds.MaxX) / 2
local centerZ = (bounds.MinZ + bounds.MaxZ) / 2

if math.abs(centerX) > 10000 or math.abs(centerZ) > 10000 then
    warn("Ground center coordinates too large, aborting ground creation to prevent floating point issues!")
else
    local sizeX = bounds.MaxX - bounds.MinX + 100
    local sizeZ = bounds.MaxZ - bounds.MinZ + 100
    
    local TILE_SIZE = 1000
    local startX = centerX - sizeX/2
    local startZ = centerZ - sizeZ/2
    
    for tx = 0, math.ceil(sizeX / TILE_SIZE) - 1 do
        for tz = 0, math.ceil(sizeZ / TILE_SIZE) - 1 do
            local ground = Instance.new("Part")
            ground.Name = "PilotGround_" .. tx .. "_" .. tz
            ground.Anchored = true
            ground.CanCollide = true
            ground.Material = Enum.Material.Grass
            ground.Color = Color3.fromRGB(100, 150, 100)
            
            local w = math.min(TILE_SIZE, sizeX - tx * TILE_SIZE)
            local d = math.min(TILE_SIZE, sizeZ - tz * TILE_SIZE)
            
            ground.Size = Vector3.new(w, 1, d)
            ground.CFrame = CFrame.new(startX + tx * TILE_SIZE + w/2, -0.5, startZ + tz * TILE_SIZE + d/2)
            ground:SetAttribute("CoordinateSpace", "LocalStuds")
            ground.Parent = cityGeometry
        end
    end
    
    -- Safety Floor
    for tx = 0, math.ceil(sizeX / TILE_SIZE) - 1 do
        for tz = 0, math.ceil(sizeZ / TILE_SIZE) - 1 do
            local safety = Instance.new("Part")
            safety.Name = "PilotSafetyFloor_" .. tx .. "_" .. tz
            safety.Anchored = true
            safety.CanCollide = true
            safety.CanQuery = true
            safety.Transparency = 1
            
            local w = math.min(TILE_SIZE, sizeX - tx * TILE_SIZE)
            local d = math.min(TILE_SIZE, sizeZ - tz * TILE_SIZE)
            local posX = startX + tx * TILE_SIZE + w/2
            local posZ = startZ + tz * TILE_SIZE + d/2
            
            if tx == 0 then w += 500 posX -= 250 end
            if tx == math.ceil(sizeX / TILE_SIZE) - 1 then w += 500 posX += 250 end
            if tz == 0 then d += 500 posZ -= 250 end
            if tz == math.ceil(sizeZ / TILE_SIZE) - 1 then d += 500 posZ += 250 end
            
            safety.Size = Vector3.new(w, 16, d)
            safety.CFrame = CFrame.new(posX, -8, posZ) -- Oberkante -8, Dicke 16 -> Center Y = -16
            safety.Parent = cityGeometry
        end
    end
end

local function createPart(name, parent, color, material, canCollide)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanTouch = false
    part.CanQuery = false
    part.CanCollide = canCollide or false
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Parent = parent
    return part
end

local function processLineString(feature, folder, color, material, layerY, height, statKey)
    local coords = feature.Geometry
    if #coords < 2 then return end
    
    local featureId = tostring(feature.Id)
    local featureType = feature.Properties.highway or feature.Properties.railway or feature.Properties.water or "Unknown"
    local widthMeters = feature.Properties.OSMWidthMeters or feature.Properties.WidthMeters or 4.0
    local widthStuds = feature.Properties.FinalWidthStuds or (widthMeters * scale)
    
    -- Ensure widths are sane (e.g. 1m to 60m)
    if not feature.Properties.FinalWidthStuds and (widthMeters < 1.0 or widthMeters > 60.0) then
        widthStuds = math.clamp(widthMeters, 1.0, 60.0) * scale
    end
    
    for i = 1, #coords - 1 do
        local p1 = coords[i]
        local p2 = coords[i+1]
        
        local pos1 = Vector3.new(p1[1] * scale, layerY + height/2, p1[2] * scale)
        local pos2 = Vector3.new(p2[1] * scale, layerY + height/2, p2[2] * scale)
        
        local distance = (pos2 - pos1).Magnitude
        if distance > 0.1 then
            local part = createPart("Segment_" .. featureId, folder, color, material, true)
            part.Size = Vector3.new(widthStuds, height, distance)
            part.CFrame = CFrame.lookAt(pos1, pos2) * CFrame.new(0, 0, -distance/2)
            
            part:SetAttribute("OSMId", featureId)
            part:SetAttribute("FeatureType", featureType)
            part:SetAttribute("Source", manifest.Source)
            part:SetAttribute("WidthMeters", widthMeters)
            part:SetAttribute("WidthStuds", widthStuds)
            
            stats[statKey] += 1
            if statKey == "roads" then
                setStatus("RoadsCreated", stats.roads)
            end
            
            if statKey == "roads" and featureType ~= "motorway" and featureType ~= "motorway_link" then
                table.insert(spawnCandidates, pos1 + Vector3.new(0, 3, 0))
            end
        end
    end
end

local function processOBB(feature, folder, color, material, statKey)
    if not feature.OBB then return end
    
    local cx = feature.OBB.CenterLocalMeters[1]
    local cz = feature.OBB.CenterLocalMeters[2]
    local w = feature.OBB.SizeMeters[1]
    local d = feature.OBB.SizeMeters[2]
    local rot = feature.OBB.RotationDegrees
    local hMeters = feature.Properties.HeightMeters or 8.0
    
    if math.abs(cx) > 10000 or math.abs(cz) > 10000 then
        -- Skip buildings too far from origin
        return
    end
    
    local wStuds = w * scale
    local dStuds = d * scale
    local hStuds = hMeters * scale
    
    local part = createPart("Building_" .. tostring(feature.Id), folder, color, material, true)
    part.Size = Vector3.new(wStuds, hStuds, dStuds)
    
    local cframe = CFrame.new(cx * scale, hStuds/2, cz * scale) * CFrame.Angles(0, math.rad(-rot), 0)
    part.CFrame = cframe
    
    part:SetAttribute("OSMId", tostring(feature.Id))
    part:SetAttribute("FeatureType", feature.Properties.building or "Building")
    part:SetAttribute("Source", manifest.Source)
    part:SetAttribute("HeightMeters", hMeters)
    part:SetAttribute("HeightStuds", hStuds)
    part:SetAttribute("RotationDegrees", rot)
    part:SetAttribute("Representation", "MinimumRotatedRectangle")
    
    stats[statKey] += 1
    if statKey == "buildings" then
        setStatus("BuildingsCreated", stats.buildings)
    end
end

local function processGreen(feature, folder, color, material, statKey)
    local coords = feature.Geometry
    if #coords < 3 then return end
    
    local minX, minZ = math.huge, math.huge
    local maxX, maxZ = -math.huge, -math.huge
    for _, p in ipairs(coords) do
        if p[1] < minX then minX = p[1] end
        if p[1] > maxX then maxX = p[1] end
        if p[2] < minZ then minZ = p[2] end
        if p[2] > maxZ then maxZ = p[2] end
    end
    
    local sizeX = (maxX - minX) * scale
    local sizeZ = (maxZ - minZ) * scale
    if sizeX < 0.1 or sizeZ < 0.1 then return end
    
    local centerX = (minX + maxX) / 2 * scale
    local centerZ = (minZ + maxZ) / 2 * scale
    
    local part = createPart("Green_" .. tostring(feature.Id), folder, color, material, false)
    part.Size = Vector3.new(sizeX, 0.1, sizeZ)
    part.CFrame = CFrame.new(centerX, 0.03, centerZ)
    
    stats[statKey] += 1
end

local function importCategory(categoryName, processor, color, material, layerY, height, statKey)
    local categoryFolder = cityData:FindFirstChild(categoryName)
    if not categoryFolder then return end
    
    local targetFolder = Instance.new("Folder")
    targetFolder.Name = categoryName
    targetFolder.Parent = cityGeometry
    
    for _, chunkModule in ipairs(categoryFolder:GetChildren()) do
        if chunkModule:IsA("ModuleScript") then
            local chunkData = require(chunkModule)
            local chunkFolder = Instance.new("Folder")
            chunkFolder.Name = chunkModule.Name
            chunkFolder.Parent = targetFolder
            
            for _, feature in ipairs(chunkData) do
                local success, err = pcall(function()
                    processor(feature, chunkFolder, color, material, layerY, height, statKey)
                end)
                if not success then
                    stats.failed += 1
                    setStatus("Failed", stats.failed)
                    warn("Failed to import feature " .. tostring(feature.Id) .. ": " .. tostring(err))
                end
            end
        end
    end
end

-- Layers:
-- Ground      Y = 0
-- Green       Y = 0.03
-- Water       Y = 0.05
-- Roads       Y = 0.16 (height 0.4)
-- Rail        Y = 0.22 (height 0.4)
-- Buildings   bottom Y = 0

importCategory("Green", processGreen, Color3.fromRGB(80, 180, 80), Enum.Material.Grass, 0.03, 0.1, "green")
importCategory("Water", processLineString, Color3.fromRGB(50, 150, 250), Enum.Material.Glass, 0.05, 0.1, "water")
importCategory("Roads", processLineString, Color3.fromRGB(80, 80, 80), Enum.Material.Asphalt, 0.16, 0.4, "roads")
importCategory("Rail", processLineString, Color3.fromRGB(30, 30, 30), Enum.Material.Metal, 0.22, 0.4, "rail")
importCategory("Buildings", processOBB, Color3.fromRGB(200, 200, 200), Enum.Material.SmoothPlastic, 0, nil, "buildings")

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

-- QA Raycasts
setStatus("GroundSamples", 100)
local hits = 0
local misses = 0
local rng = Random.new(12345)
for i = 1, 100 do
    local rx = centerX + (rng:NextNumber() - 0.5) * (bounds.MaxX - bounds.MinX)
    local rz = centerZ + (rng:NextNumber() - 0.5) * (bounds.MaxZ - bounds.MinZ)
    local startPos = Vector3.new(rx, 1000, rz)
    local result = Workspace:Raycast(startPos, Vector3.new(0, -2000, 0))
    if result and result.Instance and result.Instance.Name:match("PilotGround") then
        hits += 1
    else
        misses += 1
    end
end
setStatus("GroundHits", hits)
setStatus("GroundMisses", misses)

-- Road Width Gauge
local qaFolder = Workspace:FindFirstChild("QA")
if not qaFolder then
    qaFolder = Instance.new("Folder")
    qaFolder.Name = "QA"
    qaFolder.Parent = Workspace
end
local gauge = qaFolder:FindFirstChild("RoadWidthGauge")
if gauge then gauge:Destroy() end

gauge = Instance.new("Model")
gauge.Name = "RoadWidthGauge"
local b1 = Instance.new("Part")
b1.Size = Vector3.new(8, 4, 16)
b1.CFrame = CFrame.new(bestSpawn + Vector3.new(4, 2, 0))
b1.Color = Color3.fromRGB(200, 50, 50)
b1.Anchored = true
b1.Parent = gauge

local b2 = Instance.new("Part")
b2.Size = Vector3.new(8, 4, 16)
b2.CFrame = CFrame.new(bestSpawn + Vector3.new(-4, 2, 0))
b2.Color = Color3.fromRGB(50, 50, 200)
b2.Anchored = true
b2.Parent = gauge

local line = Instance.new("Part")
line.Size = Vector3.new(0.5, 4.1, 16)
line.CFrame = CFrame.new(bestSpawn + Vector3.new(0, 2, 0))
line.Color = Color3.fromRGB(255, 255, 255)
line.Anchored = true
line.Parent = gauge
gauge.Parent = qaFolder

if hits == 100 and misses == 0 then
    setStatus("State", "COMPLETE")
else
    setStatus("State", "FAILED")
    warn("Ground QA Check failed! Misses: " .. misses)
end

print(string.format("Import Complete in %.2fs", duration))
print("Import Stats:")
for k, v in pairs(stats) do
    print(" - " .. k .. ": " .. v)
end
if manifest.Counts and manifest.Counts.Buildings then
    local expected = manifest.Counts.Buildings
    local created = stats.buildings
    local rejected = expected - created
    print("Expected Buildings: " .. expected)
    print("Created Buildings: " .. created)
    print("Rejected Buildings: " .. rejected)
end
