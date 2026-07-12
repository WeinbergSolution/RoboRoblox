local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "DebugOverlay"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 150)
frame.Position = UDim2.new(1, -310, 0, 10)
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.BackgroundTransparency = 0.5
frame.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Parent = frame
layout.Padding = UDim.new(0, 5)

local function createLabel(name)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.Parent = frame
	return label
end

local fpsLabel = createLabel("FPSLabel")
local posLabel = createLabel("PosLabel")
local stateLabel = createLabel("StateLabel")
local bldgLabel = createLabel("BldgLabel")
local durationLabel = createLabel("DurationLabel")

local lastTime = tick()
local frames = 0

RunService.RenderStepped:Connect(function()
	frames = frames + 1
	local current = tick()
	if current - lastTime >= 1 then
		fpsLabel.Text = " FPS: " .. frames
		frames = 0
		lastTime = current
	end

	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		local pos = char.HumanoidRootPart.Position
		posLabel.Text = string.format(" Pos: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
	else
		posLabel.Text = " Pos: N/A"
	end

	local statusFolder = ReplicatedStorage:FindFirstChild("ImportStatus")
	if statusFolder then
		local state = statusFolder:FindFirstChild("State")
		if state then
			stateLabel.Text = " State: " .. state.Value
		end

		local bldg = statusFolder:FindFirstChild("BuildingsCreated")
		local rds = statusFolder:FindFirstChild("RoadsCreated")
		if bldg and rds then
			bldgLabel.Text = string.format(" Bldg: %d | Roads: %d", bldg.Value, rds.Value)
		end

		local dur = statusFolder:FindFirstChild("DurationSeconds")
		if dur then
			durationLabel.Text = string.format(" Import Time: %ds", dur.Value)
		end
	end
end)
