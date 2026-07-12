local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "NorderstedtDebugOverlay"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 100)
frame.Position = UDim2.new(1, -210, 0, 10)
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.BackgroundTransparency = 0.5
frame.Parent = gui

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, 0, 0.33, 0)
fpsLabel.Position = UDim2.new(0, 0, 0, 0)
fpsLabel.BackgroundTransparency = 1
fpsLabel.TextColor3 = Color3.new(1, 1, 1)
fpsLabel.Text = "FPS: "
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.Parent = frame

local coordLabel = Instance.new("TextLabel")
coordLabel.Size = UDim2.new(1, 0, 0.33, 0)
coordLabel.Position = UDim2.new(0, 0, 0.33, 0)
coordLabel.BackgroundTransparency = 1
coordLabel.TextColor3 = Color3.new(1, 1, 1)
coordLabel.Text = "Coords: "
coordLabel.TextXAlignment = Enum.TextXAlignment.Left
coordLabel.Parent = frame

local tileLabel = Instance.new("TextLabel")
tileLabel.Size = UDim2.new(1, 0, 0.33, 0)
tileLabel.Position = UDim2.new(0, 0, 0.66, 0)
tileLabel.BackgroundTransparency = 1
tileLabel.TextColor3 = Color3.new(1, 1, 1)
tileLabel.Text = "Tile ID: MVP_NORDERSTEDT"
tileLabel.TextXAlignment = Enum.TextXAlignment.Left
tileLabel.Parent = frame

local lastTick = tick()
local frames = 0

RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastTick >= 1 then
        fpsLabel.Text = " FPS: " .. frames
        frames = 0
        lastTick = tick()
    end
    
    local char = player.Character
    if char and char.PrimaryPart then
        local pos = char.PrimaryPart.Position
        coordLabel.Text = string.format(" Coords: X:%.1f, Z:%.1f", pos.X, pos.Z)
    end
end)
