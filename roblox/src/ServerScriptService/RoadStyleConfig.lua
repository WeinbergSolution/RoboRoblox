return {
	Materials = {
		Asphalt = Enum.Material.Asphalt,
		Pavement = Enum.Material.Pavement,
		Marking = Enum.Material.SmoothPlastic,
		Curb = Enum.Material.Concrete,
		Green = Enum.Material.Grass,
		Water = Enum.Material.Glass,
		Rail = Enum.Material.Metal,
	},
	Colors = {
		Asphalt = Color3.fromRGB(60, 60, 60),
		Pavement = Color3.fromRGB(120, 120, 120),
		MarkingWhite = Color3.fromRGB(240, 240, 240),
		MarkingYellow = Color3.fromRGB(240, 200, 50),
		Curb = Color3.fromRGB(150, 150, 150),
		Green = Color3.fromRGB(80, 160, 80),
		Water = Color3.fromRGB(50, 150, 250),
		Rail = Color3.fromRGB(30, 30, 30),
	},
	Markings = {
		DashLength = 3.0, -- Studs
		DashSpacing = 4.0, -- Studs
		LineWidth = 0.4, -- Studs
		Thickness = 0.05, -- Studs
		StopLineWidth = 1.0, -- Studs
		ZebraStripeWidth = 2.0, -- Studs
		ZebraSpacing = 2.0, -- Studs
	},
	Sidewalks = {
		DefaultWidth = 6.0, -- Studs
		Height = 0.5, -- Studs (above road)
		CurbWidth = 0.5, -- Studs
	},
	Layers = {
		Ground = 0.0,
		Green = 0.03,
		Water = 0.05,
		Road = 0.16,
		Marking = 0.6, -- Road layer + 0.4 height + 0.04 delta
		Rail = 0.22,
		Sidewalk = 0.66,
	},
}
