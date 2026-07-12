local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local cityData = ReplicatedStorage:WaitForChild("CityData")
local manifest = require(cityData:WaitForChild("Manifest"))

local scale = manifest.MetersToStuds or 3.571428

local cityGeometry = Workspace:FindFirstChild("CityGeometry")
if cityGeometry then
    cityGeometry:Destroy()
end
cityGeometry = Instance.new("Folder")
cityGeometry.Name = "CityGeometry"
cityGeometry.Parent = Workspace

print("Starting City Import Phase 1B from Source:", manifest.Source)
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
local ground = Instance.new("Part")
ground.Name = "PilotGround"
ground.Anchored = true
ground.CanCollide = true
ground.Material = Enum.Material.Grass
ground.Color = Color3.fromRGB(100, 150, 100)

local bounds = manifest.PilotBoundsStuds
local sizeX = bounds.MaxX - bounds.MinX + 100
local sizeZ = bounds.MaxZ - bounds.MinZ + 100
local centerX = (bounds.MinX + bounds.MaxX) / 2
local centerZ = (bounds.MinZ + bounds.MaxZ) / 2

ground.Size = Vector3.new(sizeX, 1, sizeZ)
ground.CFrame = CFrame.new(centerX, -0.5, centerZ) -- Top at Y=0
ground.Parent = cityGeometry

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
    local widthMeters = feature.Properties.WidthMeters or 4.0
    local widthStuds = widthMeters * scale
    
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
            
            if statKey == "roads" and featureType ~= "motorway" and featureType ~= "motorway_link" then
                table.insert(spawnCandidates, pos1 + Vector3.new(0, 3, 0))
            end
        end
    end
end

local function processOBB(feature, folder, color, material, statKey)
    local cx = feature.Properties.OBB_CenterX
    local cz = feature.Properties.OBB_CenterZ
    local w = feature.Properties.OBB_Width
    local d = feature.Properties.OBB_Depth
    local rot = feature.Properties.OBB_Rotation
    local hMeters = feature.Properties.HeightMeters or 8.0
    
    if not cx then return end -- Fallback if old data
    
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
print(string.format("Import Complete in %.2fs", duration))
print("Import Stats:")
for k, v in pairs(stats) do
    print(" - " .. k .. ": " .. v)
end
