local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local isFlying = false
local flySpeed = 100
local flyKeys = { W = false, A = false, S = false, D = false, Q = false, E = false, Shift = false }
local noclipOriginals = {}
local oldAutoRotate = true

local playerGui = player:WaitForChild("PlayerGui")

-- Simple UI
local gui = Instance.new("ScreenGui")
gui.Name = "FlyMode"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 200, 0, 30)
label.Position = UDim2.new(0, 10, 0, 10)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.5
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.Code
label.TextSize = 14
label.Text = " Fly: OFF  (F = Toggle)"
label.Parent = gui

-- Noclip
local function setNoclip(enabled)
	local char = player.Character
	if not char then
		return
	end

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

-- Toggle Fly
local function toggleFly()
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChild("Humanoid")
	if not hrp or not hum then
		return
	end

	isFlying = not isFlying

	if isFlying then
		oldAutoRotate = hum.AutoRotate
		hum.AutoRotate = false
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		setNoclip(true)
		hrp.AssemblyLinearVelocity = Vector3.zero
		label.Text = " Fly: ON  (Speed: 100)"
	else
		hum.AutoRotate = oldAutoRotate
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		setNoclip(false)
		hrp.AssemblyLinearVelocity = Vector3.zero
		label.Text = " Fly: OFF  (F = Toggle)"
	end
end

-- Input: Toggle
local function onToggleAction(_, state)
	if state == Enum.UserInputState.Begin then
		toggleFly()
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindActionAtPriority(
	"FlyToggle",
	onToggleAction,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.F
)

-- Input: Movement keys
local function onMoveAction(actionName, state)
	local isDown = (state ~= Enum.UserInputState.End)

	if actionName == "FlyForward" then
		flyKeys.W = isDown
	elseif actionName == "FlyBackward" then
		flyKeys.S = isDown
	elseif actionName == "FlyLeft" then
		flyKeys.A = isDown
	elseif actionName == "FlyRight" then
		flyKeys.D = isDown
	elseif actionName == "FlyUp" then
		flyKeys.E = isDown
	elseif actionName == "FlyDown" then
		flyKeys.Q = isDown
	elseif actionName == "FlyFast" then
		flyKeys.Shift = isDown
		if isFlying then
			label.Text = isDown and " Fly: ON  (Speed: 350)" or " Fly: ON  (Speed: 100)"
		end
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority(
	"FlyForward",
	onMoveAction,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.W
)
ContextActionService:BindActionAtPriority(
	"FlyBackward",
	onMoveAction,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.S
)
ContextActionService:BindActionAtPriority(
	"FlyLeft",
	onMoveAction,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.A
)
ContextActionService:BindActionAtPriority(
	"FlyRight",
	onMoveAction,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.D
)
ContextActionService:BindActionAtPriority(
	"FlyUp",
	onMoveAction,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.E
)
ContextActionService:BindActionAtPriority(
	"FlyDown",
	onMoveAction,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.Q
)
ContextActionService:BindActionAtPriority(
	"FlyFast",
	onMoveAction,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.LeftShift
)

-- Reset on respawn
player.CharacterAdded:Connect(function()
	isFlying = false
	table.clear(noclipOriginals)
	label.Text = " Fly: OFF  (F = Toggle)"
end)

-- Fly loop
RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	if isFlying then
		local camCFrame = camera.CFrame
		local speed = flyKeys.Shift and 350 or 100
		local moveDir = Vector3.zero

		if flyKeys.W then
			moveDir += camCFrame.LookVector
		end
		if flyKeys.S then
			moveDir -= camCFrame.LookVector
		end
		if flyKeys.D then
			moveDir += camCFrame.RightVector
		end
		if flyKeys.A then
			moveDir -= camCFrame.RightVector
		end
		if flyKeys.E then
			moveDir += Vector3.new(0, 1, 0)
		end
		if flyKeys.Q then
			moveDir -= Vector3.new(0, 1, 0)
		end

		if moveDir.Magnitude > 0 then
			moveDir = moveDir.Unit
		end

		hrp.CFrame = CFrame.new(hrp.Position + moveDir * speed * dt)
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end)
