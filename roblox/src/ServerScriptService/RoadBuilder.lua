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

function RoadBuilder.buildRoadSegment(p1, p2, width, feature, tileFolder, scale, junctionMap, cumulativeDist)
	local distance = (p2 - p1).Magnitude
	if distance < 0.1 then
		return
	end

	local cutbackSW1 = 0
	local cutbackSW2 = 0
	local cutbackAsphalt1 = 0
	local cutbackAsphalt2 = 0
	
	if junctionMap then
		local k1 = math.floor(p1.X * 10) / 10 .. "_" .. math.floor(p1.Z * 10) / 10
		local n1 = junctionMap[k1]
		if n1 and n1.Degree > 2 and not n1.IsBridge and not n1.IsTunnel then
			local maxW = width
			for _, w in ipairs(n1.WidthsStuds) do
				if w * scale > maxW then maxW = w * scale end
			end
			cutbackSW1 = (maxW/2) + Config.Sidewalks.DefaultWidth
			cutbackAsphalt1 = 0 -- Asphalt runs all the way to the center of the junction!
		end
		
		local k2 = math.floor(p2.X * 10) / 10 .. "_" .. math.floor(p2.Z * 10) / 10
		local n2 = junctionMap[k2]
		if n2 and n2.Degree > 2 and not n2.IsBridge and not n2.IsTunnel then
			local maxW = width
			for _, w in ipairs(n2.WidthsStuds) do
				if w * scale > maxW then maxW = w * scale end
			end
			cutbackSW2 = (maxW/2) + Config.Sidewalks.DefaultWidth
			cutbackAsphalt2 = 0 -- Asphalt runs all the way to the center of the junction!
		end
	end

	local actualDistAsphalt = distance - cutbackAsphalt1 - cutbackAsphalt2
	local actualDistSW = distance - cutbackSW1 - cutbackSW2
	
	if actualDistAsphalt <= 0.1 then return end

	local dir = (p2 - p1).Unit
	
	-- Calculate centers for Asphalt and Sidewalks
	local actualP1Asphalt = p1 + dir * cutbackAsphalt1
	local actualP2Asphalt = p2 - dir * cutbackAsphalt2
	local cframeAsphalt = CFrame.lookAt(actualP1Asphalt, actualP2Asphalt) * CFrame.new(0, 0, -actualDistAsphalt / 2)
	
	local actualP1SW = p1 + dir * cutbackSW1
	local actualP2SW = p2 - dir * cutbackSW2
	local cframeSW = CFrame.lookAt(actualP1SW, actualP2SW) * CFrame.new(0, 0, -actualDistSW / 2)

	local hwType = feature.Properties.highway or "unknown"
	local oneway = feature.Properties.DirectionMode == "one-way"
	local lanes = feature.Properties.LaneCount or 2
	local noMarkings = (
		hwType == "footway"
		or hwType == "path"
		or hwType == "service"
		or hwType == "living_street"
		or hwType == "pedestrian"
	)

	local isPavement = (hwType == "footway" or hwType == "path" or hwType == "pedestrian" or hwType == "steps")
	local mat = isPavement and Config.Materials.Pavement or Config.Materials.Asphalt
	local col = isPavement and Config.Colors.Pavement or Config.Colors.Asphalt
	local roadLayerY = Config.Layers.Road

	local roadCFrameAsphalt = CFrame.new(cframeAsphalt.Position.X, roadLayerY, cframeAsphalt.Position.Z) * cframeAsphalt.Rotation
	local roadCFrameSW = CFrame.new(cframeSW.Position.X, roadLayerY, cframeSW.Position.Z) * cframeSW.Rotation
	
	-- For true pedestrian paths, we use actualDistSW so they don't clip into the center of road intersections
	local finalRoadDist = isPavement and actualDistSW or actualDistAsphalt
	local finalRoadCFrame = isPavement and roadCFrameSW or roadCFrameAsphalt
	if finalRoadDist <= 0.1 then return end

	local roadPart = createPart("Road_" .. feature.Id, tileFolder.Roads, col, mat, true, Vector3.new(width, 0.4, finalRoadDist), finalRoadCFrame)

	if feature.Properties and feature.Properties.name then
		local namePart = Instance.new("Part")
		namePart.Name = "StreetNameAnchor"
		namePart.Size = Vector3.new(10, 0.1, 10)
		namePart.Transparency = 1
		namePart.Anchored = true
		namePart.CanCollide = false
		namePart.CFrame = finalRoadCFrame * CFrame.new(0, 0.21, 0) -- slightly above the 0.4 height road
		namePart.Parent = roadPart

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "StreetNameGui"
		surfaceGui.Face = Enum.NormalId.Top
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 50
		surfaceGui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Parent = surfaceGui
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = feature.Properties.name
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.5
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		surfaceGui.Parent = namePart
	end
	
	if not isPavement and hwType ~= "motorway" and hwType ~= "motorway_link" then
		if actualDistSW > 0.1 then
			local sidewalkW = Config.Sidewalks.DefaultWidth
			local sidewalkH = Config.Sidewalks.Height
			local curbW = Config.Sidewalks.CurbWidth

			local rsCF = roadCFrameSW * CFrame.new(width / 2 + sidewalkW / 2, sidewalkH / 2, 0)
			createPart(
				"Sidewalk_R_" .. feature.Id,
				tileFolder.Sidewalks,
				Config.Colors.Pavement,
				Config.Materials.Pavement,
				true,
				Vector3.new(sidewalkW - curbW, 0.4 + sidewalkH, actualDistSW),
				rsCF
			)
			local rcCF = roadCFrameSW * CFrame.new(width / 2 + curbW / 2, sidewalkH / 2, 0)
			createPart(
				"Curb_R_" .. feature.Id,
				tileFolder.Sidewalks,
				Config.Colors.Curb,
				Config.Materials.Curb,
				true,
				Vector3.new(curbW, 0.4 + sidewalkH, actualDistSW),
				rcCF
			)

			local lsCF = roadCFrameSW * CFrame.new(-width / 2 - sidewalkW / 2, sidewalkH / 2, 0)
			createPart(
				"Sidewalk_L_" .. feature.Id,
				tileFolder.Sidewalks,
				Config.Colors.Pavement,
				Config.Materials.Pavement,
				true,
				Vector3.new(sidewalkW - curbW, 0.4 + sidewalkH, actualDistSW),
				lsCF
			)
			local lcCF = roadCFrameSW * CFrame.new(-width / 2 - curbW / 2, sidewalkH / 2, 0)
			createPart(
				"Curb_L_" .. feature.Id,
				tileFolder.Sidewalks,
				Config.Colors.Curb,
				Config.Materials.Curb,
				true,
				Vector3.new(curbW, 0.4 + sidewalkH, actualDistSW),
				lcCF
			)
		end
	end

	if not noMarkings and actualDistSW > 0.1 then
		local markY = Config.Layers.Marking
		local markCF = CFrame.new(cframeSW.Position.X, markY, cframeSW.Position.Z) * cframeSW.Rotation

		local mColor = Config.Colors.MarkingWhite
		local mMat = Config.Materials.Marking
		local mW = Config.Markings.LineWidth
		local mT = Config.Markings.Thickness

		createPart(
			"EdgeLine_R",
			tileFolder.RoadMarkings,
			mColor,
			mMat,
			false,
			Vector3.new(mW, mT, actualDistSW),
			markCF * CFrame.new(width / 2 - mW, 0, 0)
		)
		createPart(
			"EdgeLine_L",
			tileFolder.RoadMarkings,
			mColor,
			mMat,
			false,
			Vector3.new(mW, mT, actualDistSW),
			markCF * CFrame.new(-width / 2 + mW, 0, 0)
		)

		cumulativeDist = cumulativeDist or 0
		local dLen = Config.Markings.DashLength
		local dSpc = Config.Markings.DashSpacing
		local cycleLen = dLen + dSpc

		if not oneway and lanes >= 2 then
			local tDist = -(cumulativeDist + cutbackSW1) % cycleLen
			while tDist + dLen < actualDistSW do
				if tDist >= 0 then
					createPart(
						"CenterDash",
						tileFolder.RoadMarkings,
						mColor,
						mMat,
						false,
						Vector3.new(mW, mT, dLen),
						markCF * CFrame.new(0, 0, actualDistSW / 2 - tDist - dLen / 2)
					)
				end
				tDist = tDist + cycleLen
			end
		end

		if oneway and lanes > 1 then
			local laneWidth = width / lanes
			for l = 1, lanes - 1 do
				local xOffset = -width / 2 + (l * laneWidth)
				local tDist = -(cumulativeDist + cutbackSW1) % cycleLen
				while tDist + dLen < actualDistSW do
					if tDist >= 0 then
						createPart(
							"LaneDash",
							tileFolder.RoadMarkings,
							mColor,
							mMat,
							false,
							Vector3.new(mW, mT, dLen),
							markCF * CFrame.new(xOffset, 0, actualDistSW / 2 - tDist - dLen / 2)
						)
					end
					tDist = tDist + cycleLen
				end
			end
		end
	end

	return true
end

return RoadBuilder
