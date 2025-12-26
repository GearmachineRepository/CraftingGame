--!strict
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local PlatformManager = {}

local CurrentPlatform: string = "PC"
local PlatformCallbacks: {(string) -> ()} = {}
local LastInputTime: number = 0

local INPUT_SWITCH_COOLDOWN: number = 2
local JOYSTICK_DEADZONE: number = 0.3

local function DetectInitialPlatform(): string
	if GuiService:IsTenFootInterface() then
		return "Controller"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	end
	return "PC"
end

local function UpdatePlatform(NewPlatform: string)
	if NewPlatform == CurrentPlatform then
		return
	end

	CurrentPlatform = NewPlatform

	for _, Callback in PlatformCallbacks do
		task.spawn(Callback, NewPlatform)
	end
end

local function OnInputBegan(InputData: InputObject)
	local CurrentTime = tick()

	if CurrentTime - LastInputTime < INPUT_SWITCH_COOLDOWN then
		return
	end

	local IsGamepadInput = InputData.UserInputType == Enum.UserInputType.Gamepad1
		or string.find(tostring(InputData.KeyCode), "Button") ~= nil
		or string.find(tostring(InputData.KeyCode), "Thumbstick") ~= nil

	local IsKeyboardInput = InputData.UserInputType == Enum.UserInputType.Keyboard
	local IsMouseInput = InputData.UserInputType == Enum.UserInputType.MouseButton1
		or InputData.UserInputType == Enum.UserInputType.MouseButton2
		or InputData.UserInputType == Enum.UserInputType.MouseWheel

	if IsGamepadInput and CurrentPlatform ~= "Controller" :: string then
		LastInputTime = CurrentTime
		UpdatePlatform("Controller")
	elseif (IsKeyboardInput or IsMouseInput) and CurrentPlatform ~= "PC" :: string then
		LastInputTime = CurrentTime
		UpdatePlatform("PC")
	end
end

local function OnInputChanged(InputData: InputObject)
	local CurrentTime = tick()

	if CurrentTime - LastInputTime < INPUT_SWITCH_COOLDOWN then
		return
	end

	local IsThumbstick = InputData.KeyCode == Enum.KeyCode.Thumbstick1
		or InputData.KeyCode == Enum.KeyCode.Thumbstick2

	if IsThumbstick then
		local Magnitude = InputData.Position.Magnitude
		if Magnitude > JOYSTICK_DEADZONE and CurrentPlatform ~= "Controller" then
			LastInputTime = CurrentTime
			UpdatePlatform("Controller")
		end
	end
end

function PlatformManager.GetPlatform(): string
	return CurrentPlatform
end

function PlatformManager.OnPlatformChanged(Callback: (string) -> ())
	table.insert(PlatformCallbacks, Callback)
end

function PlatformManager.RemovePlatformChangeCallback(Callback: (string) -> ())
	local Index = table.find(PlatformCallbacks, Callback)
	if Index then
		table.remove(PlatformCallbacks, Index)
	end
end

function PlatformManager.ForcePlatformUpdate()
	local DetectedPlatform = DetectInitialPlatform()
	UpdatePlatform(DetectedPlatform)
end

local function Initialize()
	CurrentPlatform = DetectInitialPlatform()

	UserInputService.InputBegan:Connect(OnInputBegan)
	UserInputService.InputChanged:Connect(OnInputChanged)

	UserInputService.GamepadConnected:Connect(function()
		task.wait(0.1)
		local CurrentTime = tick()
		if CurrentTime - LastInputTime > INPUT_SWITCH_COOLDOWN then
			LastInputTime = CurrentTime
			UpdatePlatform("Controller")
		end
	end)

	UserInputService.GamepadDisconnected:Connect(function()
		task.wait(0.1)
		local CurrentTime = tick()
		if CurrentTime - LastInputTime > INPUT_SWITCH_COOLDOWN then
			LastInputTime = CurrentTime
			UpdatePlatform("PC")
		end
	end)
end

Initialize()

return PlatformManager