--!strict
--!optimize 2
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlatformManager = require(Modules:WaitForChild("PlatformManager"))
local KeybindConfig = require(Modules:WaitForChild("KeybindConfig"))

-- Services and Objects
local Player: Player = Players.LocalPlayer

-- Events
local Events: Folder = ReplicatedStorage:WaitForChild("Events")
local InputEvents: Folder = Events:WaitForChild("InputEvents") :: Folder
local DragStartEvent: BindableEvent = InputEvents:WaitForChild("DragStart") :: BindableEvent
local DragStopEvent: BindableEvent = InputEvents:WaitForChild("DragStop") :: BindableEvent
local AdjustDistanceEvent: BindableEvent = InputEvents:WaitForChild("AdjustDistance") :: BindableEvent

-- State
local CurrentPlatform: string = PlatformManager.GetPlatform()
local IsModifierHeld: boolean = false
local IsDragging: boolean = false

-- Current keybinds (updated when platform changes)
local CurrentKeybinds = {
	Drag = nil,
	DistanceModifier = nil
}

-- Update keybinds for current platform
local function UpdateKeybinds(): ()
	CurrentKeybinds.Drag = KeybindConfig.GetKeybind(CurrentPlatform, "Drag")
	CurrentKeybinds.DistanceModifier = KeybindConfig.GetKeybind(CurrentPlatform, "DistanceModifier")
end

-- Controller distance adjustment action (prevents camera movement)
local function HandleControllerDistance(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Change and inputObject.KeyCode == Enum.KeyCode.Thumbstick2 then
		if IsDragging and IsModifierHeld then
			local stickY = inputObject.Position.Y
			if math.abs(stickY) > 0.15 then -- Smaller deadzone for better precision
				-- Scale the input for smoother control (reduce sensitivity)
				local scaledInput = stickY * 0.5 -- Reduce sensitivity by half
				AdjustDistanceEvent:Fire(scaledInput, true)
			end
		end
		return Enum.ContextActionResult.Sink -- Always consume right stick when modifier is held
	end
	return Enum.ContextActionResult.Pass
end

-- Distance control action (prevents camera zoom)
local function HandleDistanceControl(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Change and inputObject.UserInputType == Enum.UserInputType.MouseWheel then
		if IsDragging then
			AdjustDistanceEvent:Fire(inputObject.Position.Z, true)
		end
		return Enum.ContextActionResult.Sink -- Consume the input to prevent camera zoom
	end
	return Enum.ContextActionResult.Pass
end

-- Handle platform-specific distance modifier binding
local function BindDistanceModifier(): ()
	if CurrentPlatform == "PC" then
		ContextActionService:BindAction("DistanceControl", HandleDistanceControl, false, Enum.UserInputType.MouseWheel)
	elseif CurrentPlatform == "Controller" then
		ContextActionService:BindAction("ControllerDistance", HandleControllerDistance, false, Enum.KeyCode.Thumbstick2)
	end
	-- Mobile doesn't need special binding
end

-- Unbind distance modifier
local function UnbindDistanceModifier(): ()
	ContextActionService:UnbindAction("DistanceControl")
	ContextActionService:UnbindAction("ControllerDistance")
end

-- Handle input based on current platform keybinds
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	-- Check for drag start
	if (input.KeyCode == CurrentKeybinds.Drag) or (input.UserInputType == CurrentKeybinds.Drag) then
		DragStartEvent:Fire()
		IsDragging = true
	end

	-- Check for distance modifier
	if (input.KeyCode == CurrentKeybinds.DistanceModifier) or (input.UserInputType == CurrentKeybinds.DistanceModifier) then
		IsModifierHeld = true
		BindDistanceModifier()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	-- Check for drag stop
	if (input.KeyCode == CurrentKeybinds.Drag) or (input.UserInputType == CurrentKeybinds.Drag) then
		DragStopEvent:Fire()
		IsDragging = false
	end

	-- Check for distance modifier release
	if (input.KeyCode == CurrentKeybinds.DistanceModifier) or (input.UserInputType == CurrentKeybinds.DistanceModifier) then
		IsModifierHeld = false
		UnbindDistanceModifier()
	end
end)

-- Mobile-specific touch input handling
local function HandleMobileInput(): ()
	if CurrentPlatform ~= "Mobile" then return end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.Touch then
			DragStartEvent:Fire()
			IsDragging = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.Touch then
			DragStopEvent:Fire()
			IsDragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.Touch and IsDragging then
			local deltaY = input.Delta.Y
			if math.abs(deltaY) > 5 then
				AdjustDistanceEvent:Fire(deltaY > 0 and -1 or 1, true)
			end
		end
	end)
end

-- Handle platform changes
local function OnPlatformChanged(newPlatform: string): ()
	CurrentPlatform = newPlatform

	-- Update keybinds for new platform
	UpdateKeybinds()

	-- Reset state
	if IsModifierHeld then
		IsModifierHeld = false
		UnbindDistanceModifier()
	end

	if IsDragging then
		DragStopEvent:Fire()
		IsDragging = false
	end

	-- Setup mobile input if needed
	if newPlatform == "Mobile" then
		HandleMobileInput()
	end
end

-- Initialize
local function Initialize(): ()
	-- Set initial keybinds
	UpdateKeybinds()

	-- Subscribe to platform changes
	PlatformManager.OnPlatformChanged(OnPlatformChanged)

	-- Setup mobile input if starting on mobile
	HandleMobileInput()
end

Initialize()