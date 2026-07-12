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
local importStatsLabel = createLabel("Instances: ...")
local importStatsLabel2 = createLabel("Roads/Bldgs: ...")
local qaCoverageLabel = createLabel("Ground Check: N/A")

print("[RoboRoblox QA] UI mounted")
logLabel.Text = "Log: UI mounted"

-- Forward declarations
local flyButton: TextButton
local toggleFly

-- Noclip state management
-- (Moved to FlyMode.local.lua)

-- Teleports
local function teleportToAbsolute(x, y, z)
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        hrp.CFrame = CFrame.new(x, y, z)
        hrp.AssemblyLinearVelocity = Vector3.zero
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

local function tpToCameraPoint(pointName)
    local cpFolder = Workspace:FindFirstChild("CameraPoints")
    if cpFolder then
        local p = cpFolder:FindFirstChild(pointName)
        if p and p:IsA("Vector3Value") then
            teleportToAbsolute(p.Value.X, p.Value.Y, p.Value.Z)
        end
    end
end

-- Buttons
createButton("[OVERVIEW]", overview)
createButton("[CENTER]", function() tpToCameraPoint("CenterOverview") end)
createButton("[MAIN ROAD]", function() tpToCameraPoint("MainRoad") end)
createButton("[RESIDENTIAL]", function() tpToCameraPoint("ResidentialArea") end)
createButton("[RAIL AREA]", function() tpToCameraPoint("RailArea") end)
createButton("[POI AREA]", function() tpToCameraPoint("POIArea") end)

-- Input Bindings
local function onOverviewAction(actionName, state, input)
    if state == Enum.UserInputState.Begin then
        if actionName == "QA_Overview" then
            overview()
        end
    end
    return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority("QA_Overview", onOverviewAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.O)

print("[RoboRoblox QA] Input actions bound")
logLabel.Text = "Log: Input actions bound"

-- Player / Character State
player.CharacterAdded:Connect(function(char)
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
                local instances = 0
                local rParts = importStatusFolder:FindFirstChild("RoadSurfaceParts")
                local bParts = importStatusFolder:FindFirstChild("BuildingParts")
                local pParts = importStatusFolder:FindFirstChild("POIMarkers")
                
                if rParts and bParts then
                    importStatsLabel2.Text = string.format(" Roads: %d / Bldgs: %d / POIs: %d", rParts.Value, bParts.Value, pParts and pParts.Value or 0)
                end
                
                local tInstances = importStatusFolder:FindFirstChild("TotalInstances")
                if tInstances then
                    importStatsLabel.Text = string.format(" Total Instances: %d", tInstances.Value)
                end
            end
        end)
    else
        warn("[RoboRoblox QA] CityImportStatus not found within timeout")
        logLabel.Text = "Log: No ImportStatus"
    end
end)
