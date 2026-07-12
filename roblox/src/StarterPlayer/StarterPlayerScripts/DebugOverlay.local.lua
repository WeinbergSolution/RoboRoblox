local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

print("[RoboRoblox QA] LocalScript parsed and started")

-- Studio Check
if not RunService:IsStudio() then
    warn("[RoboRoblox QA] DebugOverlay is Studio-only. Aborting.")
    return
end

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Variables
local isFlying = false
local flySpeed = 100
local flyKeys = { W = false, A = false, S = false, D = false, Q = false, E = false, Shift = false }
local noclipOriginals = {} -- Stores original CanCollide state of parts
local oldAutoRotate = true

-- Setup UI Immediately
local playerGui = player:WaitForChild("PlayerGui")
print("[RoboRoblox QA] PlayerGui ready")

local gui = Instance.new("ScreenGui")
gui.Name = "DebugOverlay"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 480)
frame.Position = UDim2.new(1, -330, 0, 10) -- Panel oben rechts
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

local headerLabel = createLabel("RoboRoblox QA")
local statusLabel = createLabel("Overlay: RUNNING")
local logLabel = createLabel("Log: Initializing...")
local coverageLabel = createLabel("Coverage: ...")
local scaleLabel = createLabel("Scale: ...")
createLabel("F = Toggle Fly | O = Overview")
local flyStatusLabel = createLabel("Fly: OFF")
local posLabel = createLabel("Position: ...")
local fpsLabel = createLabel("FPS: ...")
local importStatusLabel = createLabel("Import: ...")
local importStatsLabel = createLabel("Roads/Bldgs: ...")
local qaCoverageLabel = createLabel("Ground Check: ...")

print("[RoboRoblox QA] UI mounted")
logLabel.Text = "Log: UI mounted"

-- Forward declarations
local flyButton: TextButton
local toggleFly

-- Noclip state management
local function setNoclip(enabled)
    local char = player.Character
    if not char then return end
    
    if enabled then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                noclipOriginals[part] = part.CanCollide
                part.CanCollide = false
            end
        end
    else
        for part, state in pairs(noclipOriginals) do
            if part and part.Parent then
                part.CanCollide = state
            end
        end
        table.clear(noclipOriginals)
    end
end

-- Fly logic
toggleFly = function()
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
        setNoclip(true)
        hrp.Velocity = Vector3.new(0, 0, 0)
        flyStatusLabel.Text = "Fly: ON (Speed: 100)"
        if flyButton then
            flyButton.Text = "[FLY: ON]"
        end
    else
        print("[RoboRoblox QA] Fly disabled")
        hum.AutoRotate = oldAutoRotate
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        setNoclip(false)
        hrp.Velocity = Vector3.new(0, 0, 0)
        flyStatusLabel.Text = "Fly: OFF"
        if flyButton then
            flyButton.Text = "[FLY: OFF]"
        end
    end
end

-- Teleports
local function teleportToAbsolute(x, y, z)
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        hrp.CFrame = CFrame.new(x, y, z)
        hrp.Velocity = Vector3.new(0, 0, 0)
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

local function tpToDirection(offset)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local cityData = ReplicatedStorage:FindFirstChild("CityData")
    if not cityData then return end
    local manifestMod = cityData:FindFirstChild("Manifest")
    if not manifestMod then return end
    
    local success, manifestData = pcall(require, manifestMod)
    if not success or not manifestData.LocalBoundsStuds then return end
    
    local bounds = manifestData.LocalBoundsStuds
    local cx = (bounds.MinX + bounds.MaxX) / 2
    local cz = (bounds.MinZ + bounds.MaxZ) / 2
    local w = bounds.MaxX - bounds.MinX
    local d = bounds.MaxZ - bounds.MinZ
    
    local tx = cx + offset.X * (w / 2 * 0.8)
    local tz = cz + offset.Z * (d / 2 * 0.8)
    teleportToAbsolute(tx, 50, tz)
end

-- Buttons
flyButton = createButton("[FLY: OFF]", function()
    toggleFly()
end)

createButton("[OVERVIEW]", overview)
createButton("[CENTER]", function() tpToDirection(Vector3.new(0, 0, 0)) end)
createButton("[NORTH]", function() tpToDirection(Vector3.new(0, 0, -1)) end)
createButton("[SOUTH]", function() tpToDirection(Vector3.new(0, 0, 1)) end)
createButton("[EAST]", function() tpToDirection(Vector3.new(1, 0, 0)) end)
createButton("[WEST]", function() tpToDirection(Vector3.new(-1, 0, 0)) end)

-- Input Bindings
local function onFlyAction(actionName, state, input)
    if state == Enum.UserInputState.Begin then
        if actionName == "QA_ToggleFly" then
            toggleFly()
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
        if isFlying then 
            flyStatusLabel.Text = isDown and "Fly: ON (Speed: 350)" or "Fly: ON (Speed: 100)" 
        end
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

print("[RoboRoblox QA] Input actions bound")
logLabel.Text = "Log: Input actions bound"

-- Player / Character State
player.CharacterAdded:Connect(function(char)
    isFlying = false
    table.clear(noclipOriginals)
    if flyButton then flyButton.Text = "[FLY: OFF]" end
    flyStatusLabel.Text = "Fly: OFF"
end)

local frames = 0
local lastUpdate = os.clock()

RunService.RenderStepped:Connect(function(dt)
    -- FPS
    frames += 1
    local now = os.clock()
    if now - lastUpdate >= 1 then
        fpsLabel.Text = " FPS: " .. tostring(frames)
        frames = 0
        lastUpdate = now
    end
    
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        posLabel.Text = string.format(" Position: %.1f, %.1f, %.1f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
        
        -- Fly logic override
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
            
            -- Keep against gravity if physics are running by setting velocity to counteract gravity
            -- User requested: "kein globales Workspace.Gravity = 0. HumanoidRootPart direkt bewegen."
            hrp.CFrame = CFrame.new(hrp.Position + moveDir * speed * dt)
            hrp.Velocity = Vector3.new(0, 0, 0)
        end
        
        -- Safe Respawn Floor (Y < -100)
        if hrp.Position.Y < -100 then
            warn("[RoboRoblox QA] Character fell below -100. Teleporting to center.")
            tpToDirection(Vector3.new(0, 0, 0))
        end
    end
end)

-- Async Data Loading
task.spawn(function()
    logLabel.Text = "Log: Waiting for CityData..."
    local cityData = ReplicatedStorage:WaitForChild("CityData")
    local manifestMod = cityData:WaitForChild("Manifest")
    local success, manifest = pcall(require, manifestMod)
    
    if not success then
        warn("[RoboRoblox QA] Failed to load Manifest")
        logLabel.Text = "Log: ERROR Manifest"
        return
    end
    
    print("[RoboRoblox QA] Manifest loaded")
    logLabel.Text = "Log: Manifest loaded"
    coverageLabel.Text = " Coverage: " .. (manifest.Coverage or "Unknown")
    scaleLabel.Text = " Scale: 1 m = " .. string.format("%.3f", manifest.MetersToStuds or 3.571) .. " studs"
    
    local importStatusFolder = ReplicatedStorage:WaitForChild("CityImportStatus", 10)
    if importStatusFolder then
        task.spawn(function()
            while task.wait(0.5) do
                local stateObj = importStatusFolder:FindFirstChild("State")
                if stateObj then
                    importStatusLabel.Text = " Import: " .. stateObj.Value
                end
                local rObj = importStatusFolder:FindFirstChild("RoadsCreated")
                local bObj = importStatusFolder:FindFirstChild("BuildingsCreated")
                if rObj and bObj then
                    importStatsLabel.Text = string.format(" Roads: %d / Bldgs: %d", rObj.Value, bObj.Value)
                end
                
                local gSamples = importStatusFolder:FindFirstChild("GroundSamples")
                local gHits = importStatusFolder:FindFirstChild("GroundHits")
                if gSamples and gHits then
                    qaCoverageLabel.Text = string.format(" Ground: %d/%d Hits", gHits.Value, gSamples.Value)
                end
            end
        end)
    else
        warn("[RoboRoblox QA] CityImportStatus not found within timeout")
        logLabel.Text = "Log: No ImportStatus"
    end
end)
