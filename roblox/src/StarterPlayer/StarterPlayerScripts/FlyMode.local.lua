local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

print("[RoboRoblox Fly] LocalScript started")

local isFlying = false
local normalSpeed = 400
local flyKeys = { W = false, A = false, S = false, D = false, Q = false, E = false, Shift = false, Ctrl = false }
local noclipOriginals = {}
local oldAutoRotate = true

local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "FlyMode"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 300, 0, 30)
label.Position = UDim2.new(0, 10, 0, 10)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.5
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.Code
label.TextSize = 14
label.Text = " Fly: OFF  (F = Toggle)"
label.Parent = gui

local function updateUI()
	if not isFlying then
		label.Text = " Fly: OFF  (F = Toggle)"
		return
	end

	local speed = normalSpeed
	local mode = "NORMAL"
	if flyKeys.Ctrl and flyKeys.Shift then
		speed = 3500
		mode = "TURBO"
	elseif flyKeys.Shift then
		speed = 1600
		mode = "FAST"
	end
	label.Text = string.format(" Fly: ON | Mode: %s | Speed: %d", mode, speed)
end

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

local function tpToCameraPoint(pointName)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local cpFolder = Workspace:FindFirstChild("CameraPoints")
	if cpFolder then
		local pt = cpFolder:FindFirstChild(pointName)
		if pt and pt:IsA("Vector3Value") then
			hrp.CFrame = CFrame.new(pt.Value)
			hrp.AssemblyLinearVelocity = Vector3.zero
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
		oldAutoRotate = hum.AutoRotate
		hum.AutoRotate = false
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		setNoclip(true)
		hrp.AssemblyLinearVelocity = Vector3.zero
	else
		hum.AutoRotate = oldAutoRotate
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		setNoclip(false)
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
	updateUI()
end

local function onToggleAction(_, state)
	if state == Enum.UserInputState.Begin then
		toggleFly()
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindActionAtPriority("FlyToggle", onToggleAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.F)

local function onSpeedAdjust(actionName, state, input)
	if state == Enum.UserInputState.Begin then
		if actionName == "FlySpeedUp" or (input.UserInputType == Enum.UserInputType.MouseWheel and input.Position.Z > 0) then
			normalSpeed = math.min(5000, normalSpeed + 100)
		elseif actionName == "FlySpeedDown" or (input.UserInputType == Enum.UserInputType.MouseWheel and input.Position.Z < 0) then
			normalSpeed = math.max(100, normalSpeed - 100)
		end
		updateUI()
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority("FlySpeedScroll", onSpeedAdjust, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseWheel)
ContextActionService:BindActionAtPriority("FlySpeedUp", onSpeedAdjust, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Equals, Enum.KeyCode.KeypadPlus)
ContextActionService:BindActionAtPriority("FlySpeedDown", onSpeedAdjust, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Minus, Enum.KeyCode.KeypadMinus)

local function onMoveAction(actionName, state)
	local isDown = (state ~= Enum.UserInputState.End)

	if actionName == "FlyForward" then flyKeys.W = isDown
	elseif actionName == "FlyBackward" then flyKeys.S = isDown
	elseif actionName == "FlyLeft" then flyKeys.A = isDown
	elseif actionName == "FlyRight" then flyKeys.D = isDown
	elseif actionName == "FlyUp" then flyKeys.E = isDown
	elseif actionName == "FlyDown" then flyKeys.Q = isDown
	elseif actionName == "FlyFast" then flyKeys.Shift = isDown
	elseif actionName == "FlyTurbo" then flyKeys.Ctrl = isDown
	end
	
	updateUI()
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority("FlyForward", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.W)
ContextActionService:BindActionAtPriority("FlyBackward", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.S)
ContextActionService:BindActionAtPriority("FlyLeft", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.A)
ContextActionService:BindActionAtPriority("FlyRight", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.D)
ContextActionService:BindActionAtPriority("FlyUp", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E)
ContextActionService:BindActionAtPriority("FlyDown", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q)
ContextActionService:BindActionAtPriority("FlyFast", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift)
ContextActionService:BindActionAtPriority("FlyTurbo", onMoveAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftControl)

local function onCameraPoints(actionName, state)
	if state == Enum.UserInputState.Begin then
		if actionName == "PilotOverview" then tpToCameraPoint("CenterOverview")
		elseif actionName == "CamPoint1" then tpToCameraPoint("MainRoad")
		elseif actionName == "CamPoint2" then tpToCameraPoint("ResidentialArea")
		elseif actionName == "CamPoint3" then tpToCameraPoint("Intersection")
		elseif actionName == "CamPoint4" then tpToCameraPoint("TJunction")
		elseif actionName == "CamPoint5" then tpToCameraPoint("CrossJunction")
		end
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority("PilotOverview", onCameraPoints, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.O)
ContextActionService:BindActionAtPriority("CamPoint1", onCameraPoints, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.One)
ContextActionService:BindActionAtPriority("CamPoint2", onCameraPoints, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Two)
ContextActionService:BindActionAtPriority("CamPoint3", onCameraPoints, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Three)
ContextActionService:BindActionAtPriority("CamPoint4", onCameraPoints, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Four)
ContextActionService:BindActionAtPriority("CamPoint5", onCameraPoints, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Five)

print("[RoboRoblox Fly] Actions bound")

player.CharacterAdded:Connect(function()
	isFlying = false
	table.clear(noclipOriginals)
	updateUI()
end)

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	if hrp.Position.Y < -100 then
		warn("[RoboRoblox Fly] Character fell below -100. Teleporting to center.")
		tpToCameraPoint("CenterOverview")
	end

	if isFlying then
		local camCFrame = camera.CFrame
		local speed = normalSpeed
		if flyKeys.Ctrl and flyKeys.Shift then speed = 3500
		elseif flyKeys.Shift then speed = 1600
		end
		
		local moveDir = Vector3.zero

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
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end)
