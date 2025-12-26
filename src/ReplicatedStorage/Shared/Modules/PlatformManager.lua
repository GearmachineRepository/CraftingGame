--!strict
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local PlatformManager = {}

-- State
local CurrentPlatform: string = "PC"
local Callbacks: {(string) -> ()} = {}
local LastInputTime: number = 0
local INPUT_SWITCH_COOLDOWN: number = 2 -- Prevent rapid switching for 2 seconds

-- Platform Detection
local function DetectPlatform(): string
	if GuiService:IsTenFootInterface() then
		return "Controller"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	else
		return "PC"
	end
end

-- Dynamic input device detection (more aggressive than platform detection)
local function DetectActiveInputDevice(): string
	-- Check for gamepad first
	local ConnectedGamepads = UserInputService:GetConnectedGamepads()
	if #ConnectedGamepads > 0 then
		return "Controller"
	end

	-- Check for touch
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	end

	-- Default to PC
	return "PC"
end

-- Update platform and notify subscribers
local function UpdatePlatform(newPlatform: string): ()
	if newPlatform ~= CurrentPlatform then
		local oldPlatform = CurrentPlatform
		CurrentPlatform = newPlatform

		--print("PlatformManager: Platform changed from", oldPlatform, "to", newPlatform)

		-- Notify all subscribers
		for _, callback in pairs(Callbacks) do
			task.spawn(callback, newPlatform)
		end
	end
end

-- Check for platform changes (with cooldown to prevent rapid switching)
local function CheckPlatformChange(): ()
	local currentTime = tick()
	if currentTime - LastInputTime > INPUT_SWITCH_COOLDOWN then
		local detectedPlatform = DetectActiveInputDevice()
		if detectedPlatform ~= CurrentPlatform then
			UpdatePlatform(detectedPlatform)
			LastInputTime = currentTime
		end
	end
end

-- Handle input-based platform detection (add joystick support)
local function OnInputBegan(input: InputObject): ()
	local currentTime = tick()

	-- Only check for platform switches after cooldown
	if currentTime - LastInputTime < INPUT_SWITCH_COOLDOWN then
		return
	end

	-- Detect controller input (including joysticks)
	local IsGamepadInput = input.UserInputType == Enum.UserInputType.Gamepad1 or 
		string.find(tostring(input.KeyCode), "Button") or
		string.find(tostring(input.KeyCode), "Thumbstick")

	-- Detect keyboard/mouse input                  
	local IsKeyboardInput = input.UserInputType == Enum.UserInputType.Keyboard
	local IsMouseInput = input.UserInputType == Enum.UserInputType.MouseButton1 or 
		input.UserInputType == Enum.UserInputType.MouseButton2 or
		input.UserInputType == Enum.UserInputType.MouseWheel

	-- Switch platform based on intentional input
	if IsGamepadInput and CurrentPlatform ~= "Controller" then
		UpdatePlatform("Controller")
	elseif (IsKeyboardInput or IsMouseInput) then
		UpdatePlatform("PC")
	end
end

-- Add InputChanged detection for joystick movements
local function OnInputChanged(input: InputObject): ()
	local currentTime = tick()

	-- Only check for platform switches after cooldown
	if currentTime - LastInputTime < INPUT_SWITCH_COOLDOWN then
		return
	end

	-- Detect joystick movement (only significant movement to avoid noise)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local magnitude = input.Position.Magnitude
		if magnitude > 0.3 then -- Only detect significant joystick movement
			if CurrentPlatform ~= "Controller" then
				UpdatePlatform("Controller")
			end
		end
	end
end

-- Public API
function PlatformManager.GetPlatform(): string
	return CurrentPlatform
end

function PlatformManager.OnPlatformChanged(callback: (string) -> ()): ()
	table.insert(Callbacks, callback)
end

function PlatformManager.RemovePlatformChangeCallback(callback: (string) -> ()): ()
	for i, existingCallback in pairs(Callbacks) do
		if existingCallback == callback then
			table.remove(Callbacks, i)
			break
		end
	end
end

function PlatformManager.ForcePlatformUpdate(): ()
	local detectedPlatform = DetectActiveInputDevice()
	UpdatePlatform(detectedPlatform)
end

-- Initialize
local function Initialize(): ()
	-- Set initial platform
	CurrentPlatform = DetectPlatform()

	-- Connect input monitoring
	UserInputService.InputBegan:Connect(OnInputBegan)
	UserInputService.InputChanged:Connect(OnInputChanged)

	-- Monitor gamepad connections (with delay for system registration)
	UserInputService.GamepadConnected:Connect(function()
		task.wait(0.1)
		local currentTime = tick()
		if currentTime - LastInputTime > INPUT_SWITCH_COOLDOWN then
			UpdatePlatform("Controller")
		end
	end)

	UserInputService.GamepadDisconnected:Connect(function()
		task.wait(0.1)
		local currentTime = tick()
		if currentTime - LastInputTime > INPUT_SWITCH_COOLDOWN then
			UpdatePlatform("PC")
		end
	end)
	
	--Debugging
	--print("PlatformManager initialized. Current platform:", CurrentPlatform)
	--print("Connected gamepads:", #UserInputService:GetConnectedGamepads())
end

Initialize()

return PlatformManager