local RoadStyleConfig = {}

RoadStyleConfig.Colors = {
	Asphalt = Color3.fromRGB(45, 45, 45),
	Pavement = Color3.fromRGB(150, 150, 150),
	Curb = Color3.fromRGB(100, 100, 100),
	MarkingWhite = Color3.fromRGB(230, 230, 230),
	MarkingYellow = Color3.fromRGB(255, 204, 0)
}

RoadStyleConfig.Materials = {
	Asphalt = Enum.Material.Asphalt,
	Pavement = Enum.Material.Concrete,
	Curb = Enum.Material.Concrete,
	Marking = Enum.Material.SmoothPlastic
}

RoadStyleConfig.Layers = {
	Road = 0,
	Marking = 0.45
}

RoadStyleConfig.Sidewalks = {
	DefaultWidth = 4.0,
	Height = 0.5,
	CurbWidth = 0.5
}

RoadStyleConfig.Markings = {
	LineWidth = 0.3,
	Thickness = 0.1,
	DashLength = 4.0,
	DashSpacing = 4.0
}

return RoadStyleConfig
