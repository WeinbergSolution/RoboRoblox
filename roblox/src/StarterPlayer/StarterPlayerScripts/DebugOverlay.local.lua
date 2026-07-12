local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
    return
end

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local cityData = ReplicatedStorage:WaitForChild("CityData")
local manifest = require(cityData:WaitForChild("Manifest"))

-- 1. Setup UI
local gui = Instance.new("ScreenGui")
gui.Name = "DebugOverlay"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 250)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.BackgroundTransparency = 0.5
frame.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.Parent = frame

local function createLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 14
    lbl.Text = " " .. text
    lbl.Parent = frame
    return lbl
end

createLabel("Coverage: " .. (manifest.Coverage or "Unknown"))
createLabel(manifest.IsFullNorderstedt and "Full Norderstedt: IMPORTED" or "Full Norderstedt: NOT YET IMPORTED")
createLabel("Scale: 1 m = " .. string.format("%.3f", manifest.MetersToStuds or 3.571) .. " studs")
createLabel("Controls: F=Fly, WASD=Move, Q/E=Down/Up, Shift=Fast, O=Overview")
local posLabel = createLabel("Position: ...")
local fpsLabel = createLabel("FPS: ...")
createLabel("Imported Roads: " .. tostring(manifest.Counts and manifest.Counts.Roads or 0))
createLabel("Imported Buildings: " .. tostring(manifest.Counts and manifest.Counts.Buildings or 0))

local isFlying = false
local flySpeed = 100
local bg, bv

local function toggleFly()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    isFlying = not isFlying
    
    if isFlying then
        hum.PlatformStand = true
        bg = Instance.new("BodyGyro")
        bg.P = 9e4
        bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.CFrame = hrp.CFrame
        bg.Parent = hrp
        
        bv = Instance.new("BodyVelocity")
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bv.Parent = hrp
    else
        hum.PlatformStand = false
        if bg then bg:Destroy() end
        if bv then bv:Destroy() end
    end
end

local function overview()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        hrp.CFrame = CFrame.new(0, 1000, 0) * CFrame.Angles(math.rad(-90), 0, 0)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        toggleFly()
    elseif input.KeyCode == Enum.KeyCode.O then
        overview()
    end
end)

local frames = 0
local lastUpdate = os.clock()

RunService.RenderStepped:Connect(function(dt)
    frames += 1
    local now = os.clock()
    if now - lastUpdate >= 1 then
        fpsLabel.Text = " FPS: " .. tostring(frames)
        frames = 0
        lastUpdate = now
    end
    
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local pos = char.HumanoidRootPart.Position
        posLabel.Text = string.format(" Position: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
    end
    
    if isFlying and char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        local camCFrame = camera.CFrame
        
        local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 350 or 100
        local vel = Vector3.new()
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel += camCFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel -= camCFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel -= camCFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel += camCFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then vel += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then vel -= Vector3.new(0, 1, 0) end
        
        if vel.Magnitude > 0 then
            vel = vel.Unit * speed
        end
        
        if bv then bv.Velocity = vel end
        if bg then bg.CFrame = camCFrame end
    end
end)
