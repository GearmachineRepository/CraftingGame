--!strict
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

-- Constants
local DRAG_DISTANCE: number = 10
local MIN_DRAG_DISTANCE: number = 5
local MAX_DRAG_DISTANCE: number = 20
local DISTANCE_INCREMENT: number = 1
local DRAG_TAG: string = "Drag"
local UPDATE_FREQUENCY: number = 1/60
local DRAG_DETECTION_DISTANCE = 32.5

-- Highlight constants
local HIGHLIGHT_COLOR: Color3 = Color3.new(1, 1, 1) -- Green highlight
local HIGHLIGHT_TRANSPARENCY: number = 0.75
local FADE_TIME: number = 0.3 -- Fade out time in seconds

-- Services and Objects
local Player: Player = Players.LocalPlayer
local Mouse: Mouse = Player:GetMouse()
local Camera: Camera = workspace.CurrentCamera

-- Remote Events
local Events: Folder = ReplicatedStorage:WaitForChild("Events")

local DragEvents: Folder = Events:WaitForChild("DragEvents") :: Folder
local UpdateCameraPositionRemote: RemoteEvent = DragEvents:WaitForChild("UpdateCameraPosition") :: RemoteEvent
local DragObjectRemote: RemoteEvent = DragEvents:WaitForChild("DragObject") :: RemoteEvent

local InputEvents: Folder = Events:WaitForChild("InputEvents") :: Folder
local DragStartEvent: BindableEvent = InputEvents:WaitForChild("DragStart") :: BindableEvent
local DragStopEvent: BindableEvent = InputEvents:WaitForChild("DragStop") :: BindableEvent
local AdjustDistanceEvent: BindableEvent = InputEvents:WaitForChild("AdjustDistance") :: BindableEvent

-- Variables
local IsMouseHeld: boolean = false
local CameraUpdateConnection: RBXScriptConnection?
local LastUpdateTime: number = 0
local CurrentDragDistance: number = DRAG_DISTANCE
local CurrentDraggedObject: (BasePart | Model)? = nil
local CurrentHighlight: Highlight? = nil

-- Highlight Functions
local function CreateHighlight(target: (BasePart | Model)): Highlight?
	local highlight = Instance.new("Highlight")
	highlight.Name = "DragHighlight"
	highlight.Adornee = target
	highlight.FillColor = HIGHLIGHT_COLOR
	highlight.FillTransparency = HIGHLIGHT_TRANSPARENCY
	highlight.OutlineColor = HIGHLIGHT_COLOR
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = target

	return highlight
end

local function RemoveHighlight(fadeOut: boolean?): ()
	if not CurrentHighlight then return end

	if fadeOut then
		-- Fade out the highlight
		local TweenService = game:GetService("TweenService")
		local fadeInfo = TweenInfo.new(
			FADE_TIME,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)

		local fadeGoal = {
			FillTransparency = 1,
			OutlineTransparency = 1
		}

		local fadeTween = TweenService:Create(CurrentHighlight, fadeInfo, fadeGoal)
		fadeTween:Play()

		fadeTween.Completed:Connect(function()
			if CurrentHighlight then
				CurrentHighlight:Destroy()
				CurrentHighlight = nil
			end
		end)
	else
		-- Immediate removal
		CurrentHighlight:Destroy()
		CurrentHighlight = nil
	end
end

-- Check if we're in first person
local function IsFirstPerson(): boolean
	if not Player.Character then return false end

	local Head: BasePart? = Player.Character:FindFirstChild("Head") :: BasePart
	if not Head then return false end

	local DistanceToHead: number = (Camera.CFrame.Position - Head.Position).Magnitude
	return DistanceToHead < 2
end

-- Handle distance adjustment
local function AdjustDistance(direction: number, modifierHeld: boolean): ()
	-- Only allow distance adjustment in first person or when modifier is held in third person
	if not IsFirstPerson() and not modifierHeld then return end

	CurrentDragDistance = math.clamp(
		CurrentDragDistance + (direction * DISTANCE_INCREMENT),
		MIN_DRAG_DISTANCE,
		MAX_DRAG_DISTANCE
	)
end

-- Camera Position Update Function
local function UpdateCameraPosition(): ()
	-- Throttle updates to reduce network spam and improve smoothness
	local CurrentTime: number = tick()
	if CurrentTime - LastUpdateTime < UPDATE_FREQUENCY then
		return
	end
	LastUpdateTime = CurrentTime

	if not Player.Character then return end

	local Character: Model = Player.Character
	local Head: BasePart? = Character:FindFirstChild("Head") :: BasePart

	if not Head then return end

	-- Check if we're in first person (camera very close to head)
	local HeadPosition: Vector3 = Head.Position
	local CameraPosition: Vector3 = Camera.CFrame.Position
	local DistanceToHead: number = (CameraPosition - HeadPosition).Magnitude
	local IsFirstPersonMode: boolean = DistanceToHead < 2 -- Adjust threshold if needed

	local TargetPosition: Vector3

	if IsFirstPersonMode then
		-- In first person: always place objects in front of camera direction
		local CameraForward: Vector3 = Camera.CFrame.LookVector
		TargetPosition = HeadPosition + (CameraForward * CurrentDragDistance)
	else
		-- In third person: use original mouse-based positioning
		local MouseDirection: Vector3 = (Mouse.Hit.Position - HeadPosition).Unit
		TargetPosition = HeadPosition + (MouseDirection * CurrentDragDistance)
	end

	-- Create CFrame with position and maintain camera's orientation for rotation
	local TargetCFrame: CFrame = CFrame.lookAt(TargetPosition, TargetPosition + Camera.CFrame.LookVector)

	UpdateCameraPositionRemote:FireServer(TargetCFrame)
end

-- Target Filter Configuration
local TargetFilter: {Instance} = {}

-- Update Target Filter Function
local function UpdateTargetFilter(): ()
	TargetFilter = {}

	-- Filter out player's character
	if Player.Character then
		table.insert(TargetFilter, Player.Character)
	end

	-- Filter out other players' characters
	for _, OtherPlayer: Player in pairs(Players:GetPlayers()) do
		if OtherPlayer ~= Player and OtherPlayer.Character then
			table.insert(TargetFilter, OtherPlayer.Character)
		end
	end

	-- Filter out currently dragged objects (to prevent interference)
	for _, Object: Instance in pairs(workspace:GetDescendants()) do
		if (Object:IsA("BasePart") or Object:IsA("Model")) and Object:GetAttribute("BeingDragged") then
			table.insert(TargetFilter, Object)
		end
	end

	-- Filter out problematic parts that shouldn't be interactive
	for _, Object: Instance in pairs(workspace:GetDescendants()) do
		if Object:IsA("BasePart") then
			if not Object.CanCollide and not CollectionService:HasTag(Object, DRAG_TAG) and not (Object.Parent and Object.Parent:IsA("Model") and CollectionService:HasTag(Object.Parent, DRAG_TAG)) then
				table.insert(TargetFilter, Object)
			end
		end
	end
end

-- Get Target Part Function
local function buildDragWhitelist(): {Instance}
	-- Include models/parts tagged Drag; Model in Include covers its descendants
	local list = {}
	for _, inst in ipairs(CollectionService:GetTagged(DRAG_TAG)) do
		table.insert(list, inst)
	end
	return list
end

local function GetTargetPart(): (BasePart | Model)?
	-- Raycast only against draggable items
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = buildDragWhitelist()
	params.IgnoreWater = true

	local ray = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
	local res = workspace:Raycast(ray.Origin, ray.Direction * DRAG_DETECTION_DISTANCE, params)
	if not res then return nil end

	local hit = res.Instance
	-- Walk up to find first Drag-tagged ancestor (covers part, model, or nested)
	local node: Instance? = hit
	while node and node ~= workspace do
		if CollectionService:HasTag(node, DRAG_TAG) then
			-- Prefer returning the model if present for stable server handling
			if node:IsA("BasePart") then
				local m = node:FindFirstAncestorOfClass("Model")
				if m and CollectionService:HasTag(m, DRAG_TAG) then
					return m
				end
			end
			return node :: any
		end
		node = node.Parent
	end
	return nil
end


-- Input Event Handlers
local function OnDragStart(): ()
	if Player:GetAttribute("Carting") then
		return
	end

	IsMouseHeld = true
	CurrentDragDistance = DRAG_DISTANCE

	local Target = GetTargetPart()
	if Target and CollectionService:HasTag(Target, DRAG_TAG) then
		CurrentDraggedObject = Target
		CurrentHighlight = CreateHighlight(Target)
		DragObjectRemote:FireServer(Target, true)

		task.delay(0.25, function()
			if CurrentDraggedObject and (not CurrentDraggedObject:GetAttribute("BeingDragged")) then
				RemoveHighlight(true)
				CurrentDraggedObject = nil
			end
		end)
	end
end

local function OnDragStop(): ()
	IsMouseHeld = false
	if CurrentHighlight then
		RemoveHighlight(true)
	end
	CurrentDraggedObject = nil
	DragObjectRemote:FireServer(nil, false)
end

local function OnDistanceAdjust(direction: number, modifierHeld: boolean): ()
	if IsMouseHeld then -- Only adjust distance while dragging
		-- Q is always required now for both first and third person
		AdjustDistance(direction, modifierHeld)
	end
end

-- Cleanup function for highlights
local function CleanupHighlights(): ()
	if CurrentHighlight then
		RemoveHighlight(false) -- Immediate removal on cleanup
		CurrentDraggedObject = nil
	end
end

-- Initialize Camera Update Loop
local function StartCameraUpdate(): ()
	if CameraUpdateConnection then
		CameraUpdateConnection:Disconnect()
	end

	CameraUpdateConnection = RunService.Heartbeat:Connect(UpdateCameraPosition)
end

-- Connect to Input Events
DragStartEvent.Event:Connect(OnDragStart)
DragStopEvent.Event:Connect(OnDragStop)
AdjustDistanceEvent.Event:Connect(OnDistanceAdjust)

-- Start camera updates when player spawns
Player.CharacterAdded:Connect(function(Character: Model)
	CleanupHighlights() -- Clean up any existing highlights
	StartCameraUpdate()
end)

-- Start immediately if character already exists
if Player.Character then
	StartCameraUpdate()
end