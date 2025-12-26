--!strict
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local PlatformManager = require(Modules:WaitForChild("PlatformManager"))
local KeybindConfig = require(Modules:WaitForChild("KeybindConfig"))
local ClientSignal = require(Modules:WaitForChild("ClientSignal"))

local DragStartSignal = ClientSignal.new()
local DragStopSignal = ClientSignal.new()
local AdjustDistanceSignal = ClientSignal.new()

local CurrentPlatform: string = PlatformManager.GetPlatform()
local IsModifierHeld: boolean = false
local IsDragging: boolean = false

local CONTROLLER_DISTANCE_DEADZONE: number = 0.15
local CONTROLLER_DISTANCE_SENSITIVITY: number = 0.5
local MOBILE_DISTANCE_THRESHOLD: number = 5

type KeybindValue = Enum.KeyCode | Enum.UserInputType | string | nil

local CurrentKeybinds: {Drag: KeybindValue, DistanceModifier: KeybindValue} = {
	Drag = nil,
	DistanceModifier = nil,
}

local function UpdateKeybinds()
	CurrentKeybinds.Drag = KeybindConfig.GetKeybind(CurrentPlatform, "Drag")
	CurrentKeybinds.DistanceModifier = KeybindConfig.GetKeybind(CurrentPlatform, "DistanceModifier")
end

local function HandleControllerDistance(_ActionName: string, InputState: Enum.UserInputState, InputObject: InputObject): Enum.ContextActionResult
	if InputState == Enum.UserInputState.Change and InputObject.KeyCode == Enum.KeyCode.Thumbstick2 then
		if IsDragging and IsModifierHeld then
			local StickY = InputObject.Position.Y
			if math.abs(StickY) > CONTROLLER_DISTANCE_DEADZONE then
				local ScaledInput = StickY * CONTROLLER_DISTANCE_SENSITIVITY
				AdjustDistanceSignal:Fire(ScaledInput, true)
			end
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function HandleDistanceControl(_ActionName: string, InputState: Enum.UserInputState, InputObject: InputObject): Enum.ContextActionResult
	if InputState == Enum.UserInputState.Change and InputObject.UserInputType == Enum.UserInputType.MouseWheel then
		if IsDragging then
			AdjustDistanceSignal:Fire(InputObject.Position.Z, true)
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function BindDistanceModifier()
	if CurrentPlatform == "PC" then
		ContextActionService:BindAction("DistanceControl", HandleDistanceControl, false, Enum.UserInputType.MouseWheel)
	elseif CurrentPlatform == "Controller" then
		ContextActionService:BindAction("ControllerDistance", HandleControllerDistance, false, Enum.KeyCode.Thumbstick2)
	end
end

local function UnbindDistanceModifier()
	ContextActionService:UnbindAction("DistanceControl")
	ContextActionService:UnbindAction("ControllerDistance")
end

local function OnInputBegan(InputData: any, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	local IsDragInput = (InputData.KeyCode == CurrentKeybinds.Drag) or (InputData.UserInputType == CurrentKeybinds.Drag)
	if IsDragInput then
		DragStartSignal:Fire()
		IsDragging = true
	end

	local IsModifierInput = (InputData.KeyCode == CurrentKeybinds.DistanceModifier) or (InputData.UserInputType == CurrentKeybinds.DistanceModifier)
	if IsModifierInput then
		IsModifierHeld = true
		BindDistanceModifier()
	end
end

local function OnInputEnded(InputData: any, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	local IsDragInput = (InputData.KeyCode == CurrentKeybinds.Drag) or (InputData.UserInputType == CurrentKeybinds.Drag)
	if IsDragInput then
		DragStopSignal:Fire()
		IsDragging = false
	end

	local IsModifierInput = (InputData.KeyCode == CurrentKeybinds.DistanceModifier) or (InputData.UserInputType == CurrentKeybinds.DistanceModifier)
	if IsModifierInput then
		IsModifierHeld = false
		UnbindDistanceModifier()
	end
end

local MobileInputConnections: {RBXScriptConnection} = {}

local function SetupMobileInput()
	if CurrentPlatform ~= "Mobile" then
		return
	end

	for _, Connection in MobileInputConnections do
		Connection:Disconnect()
	end
	table.clear(MobileInputConnections)

	table.insert(MobileInputConnections, UserInputService.InputBegan:Connect(function(InputData: InputObject, GameProcessed: boolean)
		if GameProcessed then
			return
		end

		if InputData.UserInputType == Enum.UserInputType.Touch then
			DragStartSignal:Fire()
			IsDragging = true
		end
	end))

	table.insert(MobileInputConnections, UserInputService.InputEnded:Connect(function(InputData: InputObject, GameProcessed: boolean)
		if GameProcessed then
			return
		end

		if InputData.UserInputType == Enum.UserInputType.Touch then
			DragStopSignal:Fire()
			IsDragging = false
		end
	end))

	table.insert(MobileInputConnections, UserInputService.InputChanged:Connect(function(InputData: InputObject, GameProcessed: boolean)
		if GameProcessed then
			return
		end

		if InputData.UserInputType == Enum.UserInputType.Touch and IsDragging then
			local DeltaY = InputData.Delta.Y
			if math.abs(DeltaY) > MOBILE_DISTANCE_THRESHOLD then
				local Direction = if DeltaY > 0 then -1 else 1
				AdjustDistanceSignal:Fire(Direction, true)
			end
		end
	end))
end

local function OnPlatformChanged(NewPlatform: string)
	CurrentPlatform = NewPlatform
	UpdateKeybinds()

	if IsModifierHeld then
		IsModifierHeld = false
		UnbindDistanceModifier()
	end

	if IsDragging then
		DragStopSignal:Fire()
		IsDragging = false
	end

	if NewPlatform == "Mobile" then
		SetupMobileInput()
	else
		for _, Connection in MobileInputConnections do
			Connection:Disconnect()
		end
		table.clear(MobileInputConnections)
	end
end

local function Initialize()
	UpdateKeybinds()
	PlatformManager.OnPlatformChanged(OnPlatformChanged)

	UserInputService.InputBegan:Connect(OnInputBegan)
	UserInputService.InputEnded:Connect(OnInputEnded)

	SetupMobileInput()
end

Initialize()

return {
	DragStart = DragStartSignal,
	DragStop = DragStopSignal,
	AdjustDistance = AdjustDistanceSignal,
}