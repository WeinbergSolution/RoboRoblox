local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local cityData = ReplicatedStorage:WaitForChild("CityData")
local manifest = require(cityData:WaitForChild("Manifest"))

local cityGeometry = Workspace:FindFirstChild("CityGeometry")
if cityGeometry then
    cityGeometry:Destroy()
end
cityGeometry = Instance.new("Folder")
cityGeometry.Name = "CityGeometry"
cityGeometry.Parent = Workspace

local ROAD_WIDTH_MAP = {
    motorway = 12, trunk = 10, primary = 8, secondary = 7, tertiary = 6,
    residential = 5, unclassified = 4, service = 3, footway = 2, path = 2
}

print("Starting City Import from Source:", manifest.Source)
local startTime = os.clock()

local stats = {
    roads = 0,
    buildings = 0,
    rail = 0,
    water = 0,
    green = 0,
    failed = 0
}

local function createPart(name, parent, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanTouch = false
    part.CanQuery = false
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Parent = parent
    return part
end

local function processLineString(feature, folder, color, width, height, statKey)
    local coords = feature.Geometry
    if #coords < 2 then return end
    
    local featureId = tostring(feature.Id)
    local featureType = feature.Properties.highway or feature.Properties.railway or feature.Properties.water or "Unknown"
    
    for i = 1, #coords - 1 do
        local p1 = coords[i]
        local p2 = coords[i+1]
        
        -- Roblox uses X, Y, Z where Y is up. Our 2D coords are X, Z.
        local pos1 = Vector3.new(p1[1], height/2, p1[2])
        local pos2 = Vector3.new(p2[1], height/2, p2[2])
        
        local distance = (pos2 - pos1).Magnitude
        if distance > 0.1 then
            local part = createPart("Segment_" .. featureId, folder, color)
            part.Size = Vector3.new(width, height, distance)
            part.CFrame = CFrame.lookAt(pos1, pos2) * CFrame.new(0, 0, -distance/2)
            
            part:SetAttribute("OSMId", featureId)
            part:SetAttribute("FeatureType", featureType)
            part:SetAttribute("Source", manifest.Source)
            
            stats[statKey] += 1
        end
    end
end

local function processPolygonBBox(feature, folder, color, defaultHeight, statKey)
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
    
    local sizeX = maxX - minX
    local sizeZ = maxZ - minZ
    if sizeX < 0.1 or sizeZ < 0.1 then return end
    
    local height = defaultHeight
    if feature.Properties["building:levels"] then
        height = tonumber(feature.Properties["building:levels"]) * 3 or defaultHeight
    end
    
    local centerX = minX + sizeX / 2
    local centerZ = minZ + sizeZ / 2
    
    local part = createPart("Building_" .. tostring(feature.Id), folder, color)
    part.Size = Vector3.new(sizeX, height, sizeZ)
    part.CFrame = CFrame.new(centerX, height/2, centerZ)
    
    part:SetAttribute("OSMId", tostring(feature.Id))
    part:SetAttribute("FeatureType", feature.Properties.building or "Building")
    part:SetAttribute("Source", manifest.Source)
    
    stats[statKey] += 1
end

local function importCategory(categoryName, processor, color, width, height, statKey)
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
                    local actualWidth = width
                    if statKey == "roads" and feature.Properties.highway then
                        actualWidth = ROAD_WIDTH_MAP[feature.Properties.highway] or width
                    end
                    processor(feature, chunkFolder, color, actualWidth, height, statKey)
                end)
                if not success then
                    stats.failed += 1
                    warn("Failed to import feature " .. tostring(feature.Id) .. ": " .. tostring(err))
                end
            end
        end
    end
end

-- Import logic
importCategory("Roads", processLineString, Color3.fromRGB(100, 100, 100), 5, 0.2, "roads")
importCategory("Rail", processLineString, Color3.fromRGB(50, 50, 50), 3, 0.3, "rail")
importCategory("Water", processLineString, Color3.fromRGB(50, 150, 250), 10, 0.1, "water")
importCategory("Buildings", processPolygonBBox, Color3.fromRGB(200, 200, 200), 0, 10, "buildings")
importCategory("Green", processPolygonBBox, Color3.fromRGB(100, 200, 100), 0, 0.1, "green")

local duration = os.clock() - startTime
print(string.format("Import Complete in %.2fs", duration))
print("Import Stats:")
for k, v in pairs(stats) do
    print(" - " .. k .. ": " .. v)
end
