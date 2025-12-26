--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local Networking = Shared:WaitForChild("Networking")

local PlatformManager = require(Modules:WaitForChild("PlatformManager"))
local KeybindConfig = require(Modules:WaitForChild("KeybindConfig"))
local ObjectDatabase = require(Modules:WaitForChild("ObjectDatabase"))
local LoopManager = require(Modules:WaitForChild("LoopManager"))
local Packets = require(Networking:WaitForChild("Packets"))

local INTERACTION_TAG: string = "Interactable"
local INTERACTION_DISTANCE: number = 8
local DROP_ACTION_NAME: string = "DropItem"

local Player: Player = Players.LocalPlayer

local NearestInteractable: Instance? = nil
local PromptLabel: TextLabel? = nil
local UpdateLoop: any = nil
local CurrentPlatform: string = "PC"
local CurrentBillboard: BillboardGui? = nil
local DropButtonBound: boolean = false

local RaycastParameters = RaycastParams.new()
RaycastParameters.FilterType = Enum.RaycastFilterType.Exclude

local function CreateBillboardUI(): BillboardGui
	local Billboard = Instance.new("BillboardGui")
	Billboard.Name = "InteractionPrompt"
	Billboard.Size = UDim2.fromOffset(200, 50)
	Billboard.StudsOffset = Vector3.new(0, 3, 0)
	Billboard.LightInfluence = 0
	Billboard.Enabled = false
	Billboard.AlwaysOnTop = true

	local Frame = Instance.new("Frame")
	Frame.Size = UDim2.fromScale(1, 1)
	Frame.BackgroundTransparency = 1
	Frame.BackgroundColor3 = Color3.new(0, 0, 0)
	Frame.BorderSizePixel = 0
	Frame.Parent = Billboard

	local Label = Instance.new("TextLabel")
	Label.Name = "PromptLabel"
	Label.Size = UDim2.fromScale(1, 1)
	Label.BackgroundTransparency = 1
	Label.Text = ""
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.TextScaled = true
	Label.Font = Enum.Font.SourceSansItalic
	Label.Parent = Frame

	local Stroke = Instance.new("UIStroke")
	Stroke.Thickness = 2
	Stroke.Enabled = true
	Stroke.Parent = Label

	return Billboard
end

local function GetInteractionPosition(): Vector3
	if not Player.Character then
		return Vector3.new(0, 0, 0)
	end

	local Head: BasePart? = Player.Character:FindFirstChild("Head") :: BasePart?
	return if Head then Head.Position else Player.Character:GetPivot().Position
end

local function IsInLineOfSight(Object: Instance): boolean
	local PlayerPosition = GetInteractionPosition()

	local FilterList: {Instance} = {}
	if Player.Character then
		table.insert(FilterList, Player.Character)
	end
	RaycastParameters.FilterDescendantsInstances = FilterList

	local function CanSeePosition(TargetPosition: Vector3): boolean
		local Direction = (TargetPosition - PlayerPosition).Unit
		local Distance = (TargetPosition - PlayerPosition).Magnitude

		local RaycastResult = workspace:Raycast(PlayerPosition, Direction * Distance, RaycastParameters)

		if not RaycastResult then
			return true
		end

		local HitInstance = RaycastResult.Instance
		if Object:IsA("Model") and (HitInstance == Object or HitInstance:IsDescendantOf(Object)) then
			return true
		elseif Object:IsA("BasePart") and HitInstance == Object then
			return true
		end

		return false
	end

	if Object:IsA("Model") then
		local TestPositions: {Vector3} = {}
		table.insert(TestPositions, Object:GetPivot().Position)

		for _, Child in Object:GetChildren() do
			if Child:IsA("BasePart") then
				table.insert(TestPositions, Child.Position)

				local PartSize = Child.Size
				local PartCFrame = Child.CFrame

				local Offsets = {
					Vector3.new(PartSize.X / 2, 0, 0),
					Vector3.new(-PartSize.X / 2, 0, 0),
					Vector3.new(0, PartSize.Y / 2, 0),
					Vector3.new(0, -PartSize.Y / 2, 0),
					Vector3.new(0, 0, PartSize.Z / 2),
					Vector3.new(0, 0, -PartSize.Z / 2),
				}

				for _, Offset in Offsets do
					local WorldOffset = PartCFrame:VectorToWorldSpace(Offset)
					table.insert(TestPositions, PartCFrame.Position + WorldOffset)
				end
			end
		end

		for _, Position in TestPositions do
			if CanSeePosition(Position) then
				return true
			end
		end

		return false
	elseif Object:IsA("BasePart") then
		return CanSeePosition(Object.Position)
	end

	return false
end

local function ShouldShowInteraction(Object: Instance): boolean
	local Owner = Object:GetAttribute("Owner")
	if Owner and Owner ~= Player.UserId then
		return false
	end

	if Object:GetAttribute("BeingDragged") then
		return false
	end

	if Object:GetAttribute("Interacting") then
		return false
	end

	local BrewingPlayer = Object:GetAttribute("BrewingPlayer")
	if BrewingPlayer and BrewingPlayer ~= Player.Name then
		return false
	end

	if Player:GetAttribute("Dragging") then
		return false
	end

	if not IsInLineOfSight(Object) then
		return false
	end

	return true
end

local function GetInteractionDistance(Object: Instance): number
	local ObjectConfig = ObjectDatabase.GetObjectConfig(Object.Name)
	if ObjectConfig and ObjectConfig.InteractionDistance then
		return ObjectConfig.InteractionDistance
	end

	local AttributeDistance = Object:GetAttribute("InteractionDistance")
	if AttributeDistance and type(AttributeDistance) == "number" then
		return AttributeDistance
	end

	return INTERACTION_DISTANCE
end

local function GetInteractionText(Object: Instance): string?
	local ObjectConfig = ObjectDatabase.GetObjectConfig(Object.Name)
	if not ObjectConfig then
		local FallbackText = Object:GetAttribute("InteractionText") :: string?
		if FallbackText then
			local Platform = CurrentPlatform or "PC"
			return ObjectDatabase.FormatInteractionText(FallbackText, Platform)
		end
		return nil
	end

	local CurrentState = Object:GetAttribute("CurrentState") or "StateA"
	local StateConfig = (ObjectConfig :: any)[CurrentState]

	if not StateConfig or not StateConfig.Text then
		return nil
	end

	local Platform = CurrentPlatform or "PC"
	return ObjectDatabase.FormatInteractionText(StateConfig.Text, Platform)
end

local function FindNearestInteractable(): Instance?
	local PlayerPosition = GetInteractionPosition()
	local ClosestDistance = INTERACTION_DISTANCE
	local ClosestObject: Instance? = nil

	for _, Object in CollectionService:GetTagged(INTERACTION_TAG) do
		if not ShouldShowInteraction(Object) then
			continue
		end

		local InteractionText = GetInteractionText(Object)
		if not InteractionText then
			continue
		end

		local ObjectPosition: Vector3
		if Object:IsA("Model") then
			ObjectPosition = Object:GetPivot().Position
		elseif Object:IsA("BasePart") then
			ObjectPosition = Object.Position
		else
			continue
		end

		local Distance = (PlayerPosition - ObjectPosition).Magnitude
		local ObjectInteractionDistance = GetInteractionDistance(Object)

		if Distance < ClosestDistance and Distance <= ObjectInteractionDistance then
			ClosestDistance = Distance
			ClosestObject = Object
		end
	end

	return ClosestObject
end

local function IsInputMatchingKeybind(InputData: InputObject, KeybindValue: any): boolean
	if KeybindValue == nil then
		return false
	end

	if typeof(KeybindValue) == "EnumItem" then
		local EnumType = KeybindValue.EnumType

		if EnumType == Enum.KeyCode then
			return InputData.KeyCode == (KeybindValue :: Enum.KeyCode)
		end

		if EnumType == Enum.UserInputType then
			return InputData.UserInputType == (KeybindValue :: Enum.UserInputType)
		end

		return false
	end

	return false
end

local function UpdateInteractionPrompt()
	local NewNearest = FindNearestInteractable()

	if NewNearest ~= NearestInteractable then
		NearestInteractable = NewNearest

		if NearestInteractable then
			if not CurrentBillboard then
				CurrentBillboard = CreateBillboardUI()
			end

			if not CurrentBillboard then
				return
			end

			local BillboardFrame = CurrentBillboard:FindFirstChild("Frame")
			if not BillboardFrame then
				return
			end

			PromptLabel = BillboardFrame:FindFirstChild("PromptLabel") :: TextLabel
			if not PromptLabel then
				return
			end

			CurrentBillboard.Parent = NearestInteractable
			local InteractionText = GetInteractionText(NearestInteractable)
			if InteractionText then
				PromptLabel.Text = InteractionText
				CurrentBillboard.Enabled = true
			else
				CurrentBillboard.Enabled = false
			end
		else
			if CurrentBillboard then
				CurrentBillboard.Enabled = false
			end
		end
	elseif NearestInteractable and CurrentBillboard and CurrentBillboard.Enabled then
		local InteractionText = GetInteractionText(NearestInteractable)

		local BillboardFrame = CurrentBillboard:FindFirstChild("Frame")
		if not BillboardFrame then
			return
		end

		PromptLabel = BillboardFrame:FindFirstChild("PromptLabel") :: TextLabel
		if not PromptLabel then
			return
		end

		if InteractionText and PromptLabel.Text ~= InteractionText then
			PromptLabel.Text = InteractionText
		elseif not InteractionText then
			CurrentBillboard.Enabled = false
		end
	end
end

local function PlayInteractSound()
	local SoundEffects = SoundService:FindFirstChild("Sound Effects")
	if SoundEffects then
		local InteractSound = SoundEffects:FindFirstChild("Interact")
		if InteractSound and InteractSound:IsA("Sound") then
			InteractSound.PlaybackSpeed = 1 + (math.random() / 10)
			InteractSound:Play()
		end
	end
end

local function HandleDropAction(_ActionName: string, InputState: Enum.UserInputState, _InputObject: InputObject): Enum.ContextActionResult
	if InputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	local Character = Player.Character
	if not Character then
		return Enum.ContextActionResult.Pass
	end

	local EquippedTool = Character:FindFirstChildWhichIsA("Tool")
	if EquippedTool then
		Packets.Drop:Fire()
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

local function UpdateDropButton()
	local Character = Player.Character
	if not Character then
		if DropButtonBound then
			ContextActionService:UnbindAction(DROP_ACTION_NAME)
			DropButtonBound = false
		end
		return
	end

	local EquippedTool = Character:FindFirstChildWhichIsA("Tool")
	local ShouldShowButton = EquippedTool ~= nil and (CurrentPlatform == "Mobile" or CurrentPlatform == "Controller")

	if ShouldShowButton and not DropButtonBound then
		ContextActionService:BindAction(
			DROP_ACTION_NAME,
			HandleDropAction,
			true,
			Enum.KeyCode.ButtonY
		)
		ContextActionService:SetTitle(DROP_ACTION_NAME, "Drop")
		ContextActionService:SetPosition(DROP_ACTION_NAME, UDim2.new(1, -70, 0, 50))
		DropButtonBound = true
	elseif not ShouldShowButton and DropButtonBound then
		ContextActionService:UnbindAction(DROP_ACTION_NAME)
		DropButtonBound = false
	end
end

local function OnInteractionInput(InputData: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	local InteractKeybind = KeybindConfig.GetKeybind(CurrentPlatform, "Interact")
	local DropKeybind = KeybindConfig.GetKeybind(CurrentPlatform, "Drop")

	if CurrentPlatform == "Mobile" then
		if InputData.UserInputType == Enum.UserInputType.Touch and InputData.UserInputState == Enum.UserInputState.Begin then
			local TouchPosition = InputData.Position
			local TouchedUI = false

			local Success, GuiObjects = pcall(function()
				return Player.PlayerGui:GetGuiObjectsAtPosition(TouchPosition.X, TouchPosition.Y)
			end)

			if Success and GuiObjects then
				for _, GuiObject in GuiObjects do
					local ObjectName = string.lower(GuiObject.Name)

					if string.find(ObjectName, "thumbstick")
						or string.find(ObjectName, "dynamicthumbstick")
						or string.find(ObjectName, "joystick")
						or string.find(ObjectName, "movepad")
						or string.find(ObjectName, "dpad")
						or string.find(ObjectName, "dropitem") then
						TouchedUI = true
						break
					end
				end
			end

			if not TouchedUI and NearestInteractable then
				PlayInteractSound()
				Packets.Interact:Fire(NearestInteractable)
			end
		end
	else
		local IsInteractInput = IsInputMatchingKeybind(InputData, InteractKeybind)

		if IsInteractInput and NearestInteractable then
			PlayInteractSound()
			Packets.Interact:Fire(NearestInteractable)
		end
	end

	if CurrentPlatform == "Controller" then
		local IsDropInput = IsInputMatchingKeybind(InputData, DropKeybind)

		if IsDropInput then
			Packets.Drop:Fire()
		end
	end
end

local function OnPlatformChanged(NewPlatform: string)
	CurrentPlatform = NewPlatform

	UpdateDropButton()

	if NearestInteractable and CurrentBillboard and CurrentBillboard.Enabled then
		local InteractionText = GetInteractionText(NearestInteractable)
		if InteractionText and CurrentBillboard then
			local BillboardFrame = CurrentBillboard:FindFirstChild("Frame")
			if BillboardFrame then
				PromptLabel = BillboardFrame:FindFirstChild("PromptLabel") :: TextLabel
				if PromptLabel then
					PromptLabel.Text = InteractionText
				end
			end
		end
	end
end

local function OnCharacterChildChanged()
	UpdateDropButton()
end

local function Initialize()
	CurrentPlatform = PlatformManager.GetPlatform() or "PC"

	CreateBillboardUI()
	PlatformManager.OnPlatformChanged(OnPlatformChanged)

	UpdateLoop = LoopManager.Create(function()
		UpdateInteractionPrompt()
		UpdateDropButton()
	end, LoopManager.Rates.UI)
	UpdateLoop:Start()

	UserInputService.InputBegan:Connect(OnInteractionInput)
end

local function Cleanup()
	if UpdateLoop then
		UpdateLoop:Destroy()
		UpdateLoop = nil
	end

	if CurrentBillboard then
		CurrentBillboard:Destroy()
		CurrentBillboard = nil
		PromptLabel = nil
	end

	if DropButtonBound then
		ContextActionService:UnbindAction(DROP_ACTION_NAME)
		DropButtonBound = false
	end

	NearestInteractable = nil
end

Player.CharacterAdded:Connect(function(Character: Model)
	task.wait(1)
	Initialize()

	Character.ChildAdded:Connect(OnCharacterChildChanged)
	Character.ChildRemoved:Connect(OnCharacterChildChanged)
end)

Player.CharacterRemoving:Connect(Cleanup)

if Player.Character then
	Initialize()

	Player.Character.ChildAdded:Connect(OnCharacterChildChanged)
	Player.Character.ChildRemoved:Connect(OnCharacterChildChanged)
end