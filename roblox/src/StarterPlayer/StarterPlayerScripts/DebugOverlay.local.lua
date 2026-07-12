local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
    warn("[RoboRoblox QA] DebugOverlay is Studio-only. Aborting.")
    return
end

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- 1. Setup UI INSTANTLY
local gui = Instance.new("ScreenGui")
gui.Name = "DebugOverlay"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 420)
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

local function createButton(text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 150, 0, 25)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.Code
    btn.TextSize = 14
    btn.Text = text
    btn.Parent = frame
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local headerLabel = createLabel("RoboRoblox QA - Loading...")
local coverageLabel = createLabel("Coverage: ...")
local scaleLabel = createLabel("Scale: ...")
createLabel("F or button = Toggle Fly")
createLabel("O or button = Overview")
local flyStatusLabel = createLabel("Fly: OFF")
local posLabel = createLabel("Position: ...")
local fpsLabel = createLabel("FPS: ...")
local importStatusLabel = createLabel("Import: ...")
local importStatsLabel = createLabel("Roads/Bldgs: ...")

print("[RoboRoblox QA] DebugOverlay LocalScript started")

-- Yielding for data asynchronously
task.spawn(function()
    local cityData = ReplicatedStorage:WaitForChild("CityData")
    local manifest = require(cityData:WaitForChild("Manifest"))
    print("[RoboRoblox QA] Manifest loaded")
    
    headerLabel.Text = " RoboRoblox QA"
    coverageLabel.Text = " Coverage: " .. (manifest.Coverage or "Unknown")
    scaleLabel.Text = " Scale: 1 m = " .. string.format("%.3f", manifest.MetersToStuds or 3.571) .. " studs"
    
    local importStatusFolder = ReplicatedStorage:WaitForChild("CityImportStatus", 10)
    
    local frames = 0
    local lastUpdate = os.clock()
    
    RunService.RenderStepped:Connect(function(dt)
        frames += 1
        local now = os.clock()
        if now - lastUpdate >= 1 then
            fpsLabel.Text = " FPS: " .. tostring(frames)
            frames = 0
            lastUpdate = now
            
            if importStatusFolder then
                local stateObj = importStatusFolder:FindFirstChild("State")
                if stateObj then
                    importStatusLabel.Text = " Import: " .. stateObj.Value
                end
                local rObj = importStatusFolder:FindFirstChild("RoadsCreated")
                local bObj = importStatusFolder:FindFirstChild("BuildingsCreated")
                if rObj and bObj then
                    importStatsLabel.Text = string.format(" Roads: %d / Bldgs: %d", rObj.Value, bObj.Value)
                end
            end
        end
    end)
end)

-- 2. Fly Logic
local isFlying = false
local flySpeed = 100
local flyKeys = { W = false, A = false, S = false, D = false, Q = false, E = false, Shift = false }
local oldAutoRotate = true

local function applyNoclip(enable)
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = not enable
        end
    end
end

local function toggleFly()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    isFlying = not isFlying
    
    if isFlying then
        print("[RoboRoblox QA] Fly enabled")
        oldAutoRotate = hum.AutoRotate
        hum.AutoRotate = false
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        Workspace.Gravity = 0
        applyNoclip(true)
        hrp.Velocity = Vector3.new(0, 0, 0)
        flyStatusLabel.Text = "Fly: ON (Speed: 100)"
    else
        print("[RoboRoblox QA] Fly disabled")
        hum.AutoRotate = oldAutoRotate
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        Workspace.Gravity = 196.2
        applyNoclip(false)
        hrp.Velocity = Vector3.new(0, 0, 0)
        flyStatusLabel.Text = "Fly: OFF"
    end
end

local function overview()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        hrp.CFrame = CFrame.new(0, 1500, 0)
        camera.CFrame = CFrame.lookAt(Vector3.new(0, 1500, 0), Vector3.new(0, 0, 0))
    end
end

local function tpTo(offset)
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        local cityData = ReplicatedStorage:FindFirstChild("CityData")
        if not cityData then return end
        local manifestMod = require(cityData:FindFirstChild("Manifest"))
        local bounds = manifestMod.LocalBoundsStuds
        if not bounds then return end
        
        local cx = (bounds.MinX + bounds.MaxX) / 2
        local cz = (bounds.MinZ + bounds.MaxZ) / 2
        local w = bounds.MaxX - bounds.MinX
        local d = bounds.MaxZ - bounds.MinZ
        
        local tx = cx + offset.X * (w / 2 * 0.8)
        local tz = cz + offset.Z * (d / 2 * 0.8)
        
        hrp.CFrame = CFrame.new(tx, 50, tz)
    end
end

local flyBtn = createButton("[FLY: OFF]", function()
    toggleFly()
    flyBtn.Text = isFlying and "[FLY: ON]" or "[FLY: OFF]"
end)
createButton("[OVERVIEW]", overview)
createButton("[CENTER]", function() tpTo(Vector3.new(0, 0, 0)) end)
createButton("[NORTH]", function() tpTo(Vector3.new(0, 0, -1)) end)
createButton("[SOUTH]", function() tpTo(Vector3.new(0, 0, 1)) end)
createButton("[EAST]", function() tpTo(Vector3.new(1, 0, 0)) end)
createButton("[WEST]", function() tpTo(Vector3.new(-1, 0, 0)) end)

-- ContextAction Bindings
local function onFlyAction(actionName, state, input)
    if state == Enum.UserInputState.Begin then
        if actionName == "QA_ToggleFly" then
            toggleFly()
            flyBtn.Text = isFlying and "[FLY: ON]" or "[FLY: OFF]"
        elseif actionName == "QA_Overview" then
            overview()
        end
    end
    return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority("QA_ToggleFly", onFlyAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.F)
ContextActionService:BindActionAtPriority("QA_Overview", onFlyAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.O)

local function onMoveAction(actionName, state, input)
    local isDown = (state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change)
    if state == Enum.UserInputState.End then isDown = false end
    
    if actionName == "QA_Forward" then flyKeys.W = isDown
    elseif actionName == "QA_Backward" then flyKeys.S = isDown
    elseif actionName == "QA_Left" then flyKeys.A = isDown
    elseif actionName == "QA_Right" then flyKeys.D = isDown
    elseif actionName == "QA_Up" then flyKeys.E = isDown
    elseif actionName == "QA_Down" then flyKeys.Q = isDown
    elseif actionName == "QA_Fast" then 
        flyKeys.Shift = isDown
        if isFlying then flyStatusLabel.Text = isDown and "Fly: ON (Speed: 350)" or "Fly: ON (Speed: 100)" end
    end
    return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority("QA_Forward", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.W)
ContextActionService:BindActionAtPriority("QA_Backward", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.S)
ContextActionService:BindActionAtPriority("QA_Left", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.A)
ContextActionService:BindActionAtPriority("QA_Right", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.D)
ContextActionService:BindActionAtPriority("QA_Up", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E)
ContextActionService:BindActionAtPriority("QA_Down", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q)
ContextActionService:BindActionAtPriority("QA_Fast", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift)

RunService.RenderStepped:Connect(function(dt)
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        posLabel.Text = string.format(" Position: %.1f, %.1f, %.1f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
        
        if isFlying then
            local camCFrame = camera.CFrame
            local speed = flyKeys.Shift and 350 or 100
            local moveDir = Vector3.new()
            
            if flyKeys.W then moveDir += camCFrame.LookVector end
            if flyKeys.S then moveDir -= camCFrame.LookVector end
            if flyKeys.D then moveDir += camCFrame.RightVector end
            if flyKeys.A then moveDir -= camCFrame.RightVector end
            if flyKeys.E then moveDir += Vector3.new(0, 1, 0) end
            if flyKeys.Q then moveDir -= Vector3.new(0, 1, 0) end
            
            if moveDir.Magnitude > 0 then
                moveDir = moveDir.Unit
            end
            
            hrp.CFrame = CFrame.new(hrp.Position + moveDir * speed * dt)
            hrp.Velocity = Vector3.new(0, 0, 0)
        end
    end
end)
