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

	local cutback1 = 0
	local cutback2 = 0

	if junctionMap then
		local k1 = math.floor(p1.X * 10) / 10 .. "_" .. math.floor(p1.Z * 10) / 10
		local n1 = junctionMap[k1]
		if n1 and n1.Degree > 2 and not n1.IsBridge and not n1.IsTunnel then
			local maxW = width
			for _, w in ipairs(n1.WidthsStuds) do
				if w * scale > maxW then
					maxW = w * scale
				end
			end
			cutback1 = math.max(width / 2, maxW / 2) + 0.5
		end

		local k2 = math.floor(p2.X * 10) / 10 .. "_" .. math.floor(p2.Z * 10) / 10
		local n2 = junctionMap[k2]
		if n2 and n2.Degree > 2 and not n2.IsBridge and not n2.IsTunnel then
			local maxW = width
			for _, w in ipairs(n2.WidthsStuds) do
				if w * scale > maxW then
					maxW = w * scale
				end
			end
			cutback2 = math.max(width / 2, maxW / 2) + 0.5
		end
	end

	local actualDist = distance - cutback1 - cutback2
	if actualDist <= 0.1 then
		return
	end

	local dir = (p2 - p1).Unit
	local actualP1 = p1 + dir * cutback1
	local actualP2 = p2 - dir * cutback2

	local cframe = CFrame.lookAt(actualP1, actualP2) * CFrame.new(0, 0, -actualDist / 2)
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

	local roadCFrame = CFrame.new(cframe.Position.X, roadLayerY, cframe.Position.Z) * cframe.Rotation
	createPart("Road_" .. feature.Id, tileFolder.Roads, col, mat, true, Vector3.new(width, 0.4, actualDist), roadCFrame)

	if not isPavement and hwType ~= "motorway" and hwType ~= "motorway_link" then
		local sidewalkW = Config.Sidewalks.DefaultWidth
		local sidewalkH = Config.Sidewalks.Height
		local curbW = Config.Sidewalks.CurbWidth

		local rsCF = roadCFrame * CFrame.new(width / 2 + sidewalkW / 2, sidewalkH / 2, 0)
		createPart(
			"Sidewalk_R_" .. feature.Id,
			tileFolder.Sidewalks,
			Config.Colors.Pavement,
			Config.Materials.Pavement,
			true,
			Vector3.new(sidewalkW - curbW, 0.4 + sidewalkH, actualDist),
			rsCF
		)
		local rcCF = roadCFrame * CFrame.new(width / 2 + curbW / 2, sidewalkH / 2, 0)
		createPart(
			"Curb_R_" .. feature.Id,
			tileFolder.Sidewalks,
			Config.Colors.Curb,
			Config.Materials.Curb,
			true,
			Vector3.new(curbW, 0.4 + sidewalkH, actualDist),
			rcCF
		)

		local lsCF = roadCFrame * CFrame.new(-width / 2 - sidewalkW / 2, sidewalkH / 2, 0)
		createPart(
			"Sidewalk_L_" .. feature.Id,
			tileFolder.Sidewalks,
			Config.Colors.Pavement,
			Config.Materials.Pavement,
			true,
			Vector3.new(sidewalkW - curbW, 0.4 + sidewalkH, actualDist),
			lsCF
		)
		local lcCF = roadCFrame * CFrame.new(-width / 2 - curbW / 2, sidewalkH / 2, 0)
		createPart(
			"Curb_L_" .. feature.Id,
			tileFolder.Sidewalks,
			Config.Colors.Curb,
			Config.Materials.Curb,
			true,
			Vector3.new(curbW, 0.4 + sidewalkH, actualDist),
			lcCF
		)
	end

	if not noMarkings then
		local markY = Config.Layers.Marking
		local markCF = CFrame.new(cframe.Position.X, markY, cframe.Position.Z) * cframe.Rotation

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
			Vector3.new(mW, mT, actualDist),
			markCF * CFrame.new(width / 2 - mW, 0, 0)
		)
		createPart(
			"EdgeLine_L",
			tileFolder.RoadMarkings,
			mColor,
			mMat,
			false,
			Vector3.new(mW, mT, actualDist),
			markCF * CFrame.new(-width / 2 + mW, 0, 0)
		)

		cumulativeDist = cumulativeDist or 0
		local dLen = Config.Markings.DashLength
		local dSpc = Config.Markings.DashSpacing
		local cycleLen = dLen + dSpc

		if not oneway and lanes >= 2 then
			local tDist = -(cumulativeDist + cutback1) % cycleLen
			while tDist + dLen < actualDist do
				if tDist >= 0 then
					createPart(
						"CenterDash",
						tileFolder.RoadMarkings,
						mColor,
						mMat,
						false,
						Vector3.new(mW, mT, dLen),
						markCF * CFrame.new(0, 0, actualDist / 2 - tDist - dLen / 2)
					)
				end
				tDist = tDist + cycleLen
			end
		end

		if oneway and lanes > 1 then
			local laneWidth = width / lanes
			for l = 1, lanes - 1 do
				local offset = -width / 2 + l * laneWidth
				local tDist = -(cumulativeDist + cutback1) % cycleLen
				while tDist + dLen < actualDist do
					if tDist >= 0 then
						createPart(
							"LaneDash",
							tileFolder.RoadMarkings,
							mColor,
							mMat,
							false,
							Vector3.new(mW, mT, dLen),
							markCF * CFrame.new(offset, 0, actualDist / 2 - tDist - dLen / 2)
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
