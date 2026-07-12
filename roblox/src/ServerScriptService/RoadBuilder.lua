local RoadBuilder = {}
local Config = require(script.Parent:WaitForChild("RoadStyleConfig"))

local function createPart(name, folder, color, material, canCollide, size, cframe)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanTouch = false
    part.CanQuery = false
    part.CanCollide = canCollide
    part.Color = color
    part.Material = material
    part.Size = size
    part.CFrame = cframe
    part.Parent = folder
    return part
end

function RoadBuilder.buildRoadSegment(p1, p2, width, feature, tileFolder, scale)
    local distance = (p2 - p1).Magnitude
    if distance < 0.1 then return end
    
    local cframe = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -distance/2)
    local hwType = feature.Properties.highway or "unknown"
    local oneway = feature.Properties.DirectionMode == "one-way"
    local lanes = feature.Properties.LaneCount or 2
    local noMarkings = (hwType == "footway" or hwType == "path" or hwType == "service" or hwType == "living_street" or hwType == "pedestrian")
    
    -- 1. Base Road Surface
    local isPavement = (hwType == "footway" or hwType == "path" or hwType == "pedestrian" or hwType == "steps")
    local mat = isPavement and Config.Materials.Pavement or Config.Materials.Asphalt
    local col = isPavement and Config.Colors.Pavement or Config.Colors.Asphalt
    local roadLayerY = Config.Layers.Road
    
    local roadCFrame = CFrame.new(cframe.Position.X, roadLayerY, cframe.Position.Z) * cframe.Rotation
    createPart("Road_" .. feature.Id, tileFolder.Roads, col, mat, true, Vector3.new(width, 0.4, distance), roadCFrame)
    
    -- 2. Sidewalks
    if not isPavement and hwType ~= "motorway" and hwType ~= "motorway_link" then
        local sidewalkW = Config.Sidewalks.DefaultWidth
        local sidewalkH = Config.Sidewalks.Height
        local curbW = Config.Sidewalks.CurbWidth
        
        -- Right Sidewalk
        local rsCF = roadCFrame * CFrame.new(width/2 + sidewalkW/2, sidewalkH/2, 0)
        createPart("Sidewalk_" .. feature.Id, tileFolder.Sidewalks, Config.Colors.Pavement, Config.Materials.Pavement, true, Vector3.new(sidewalkW - curbW, 0.4 + sidewalkH, distance), rsCF)
        local rcCF = roadCFrame * CFrame.new(width/2 + curbW/2, sidewalkH/2, 0)
        createPart("Curb_" .. feature.Id, tileFolder.Sidewalks, Config.Colors.Curb, Config.Materials.Curb, true, Vector3.new(curbW, 0.4 + sidewalkH, distance), rcCF)
        
        -- Left Sidewalk
        local lsCF = roadCFrame * CFrame.new(-width/2 - sidewalkW/2, sidewalkH/2, 0)
        createPart("Sidewalk_" .. feature.Id, tileFolder.Sidewalks, Config.Colors.Pavement, Config.Materials.Pavement, true, Vector3.new(sidewalkW - curbW, 0.4 + sidewalkH, distance), lsCF)
        local lcCF = roadCFrame * CFrame.new(-width/2 - curbW/2, sidewalkH/2, 0)
        createPart("Curb_" .. feature.Id, tileFolder.Sidewalks, Config.Colors.Curb, Config.Materials.Curb, true, Vector3.new(curbW, 0.4 + sidewalkH, distance), lcCF)
    end
    
    -- 3. Markings
    if not noMarkings then
        local markY = Config.Layers.Marking
        local markCF = CFrame.new(cframe.Position.X, markY, cframe.Position.Z) * cframe.Rotation
        
        local mColor = Config.Colors.MarkingWhite
        local mMat = Config.Materials.Marking
        local mW = Config.Markings.LineWidth
        local mT = Config.Markings.Thickness
        
        -- Edge Lines
        createPart("EdgeLine_R", tileFolder.RoadMarkings, mColor, mMat, false, Vector3.new(mW, mT, distance), markCF * CFrame.new(width/2 - mW, 0, 0))
        createPart("EdgeLine_L", tileFolder.RoadMarkings, mColor, mMat, false, Vector3.new(mW, mT, distance), markCF * CFrame.new(-width/2 + mW, 0, 0))
        
        -- Center / Lane Lines
        if not oneway and lanes >= 2 then
            -- Dashed center line
            local dLen = Config.Markings.DashLength
            local dSpc = Config.Markings.DashSpacing
            local tDist = 0
            while tDist + dLen < distance do
                createPart("CenterDash", tileFolder.RoadMarkings, mColor, mMat, false, Vector3.new(mW, mT, dLen), markCF * CFrame.new(0, 0, distance/2 - tDist - dLen/2))
                tDist = tDist + dLen + dSpc
            end
        end
        
        if oneway and lanes > 1 then
            -- Dashed lane separators
            local laneWidth = width / lanes
            for l = 1, lanes - 1 do
                local offset = -width/2 + l * laneWidth
                local dLen = Config.Markings.DashLength
                local dSpc = Config.Markings.DashSpacing
                local tDist = 0
                while tDist + dLen < distance do
                    createPart("LaneDash", tileFolder.RoadMarkings, mColor, mMat, false, Vector3.new(mW, mT, dLen), markCF * CFrame.new(offset, 0, distance/2 - tDist - dLen/2))
                    tDist = tDist + dLen + dSpc
                end
            end
        end
    end
    
    return true
end

return RoadBuilder
