--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local Networking = Shared:WaitForChild("Networking")

local LoopManager = require(Modules:WaitForChild("LoopManager"))
local Packets = require(Networking:WaitForChild("Packets"))

local DragInputHandler = require(script.Parent:WaitForChild("DragInputHandler"))

local DRAG_DISTANCE: number = 10
local MIN_DRAG_DISTANCE: number = 5
local MAX_DRAG_DISTANCE: number = 20
local DISTANCE_INCREMENT: number = 1
local DRAG_TAG: string = "Drag"
local DRAG_DETECTION_DISTANCE: number = 32.5
local POSITION_CHANGE_THRESHOLD: number = 0.05

local HIGHLIGHT_COLOR: Color3 = Color3.new(1, 1, 1)
local HIGHLIGHT_TRANSPARENCY: number = 0.75
local FADE_TIME: number = 0.3

local Player: Player = Players.LocalPlayer
local Mouse: Mouse = Player:GetMouse()
local Camera: Camera = workspace.CurrentCamera

local IsMouseHeld: boolean = false
local CameraUpdateLoop: any = nil
local CurrentDragDistance: number = DRAG_DISTANCE
local CurrentDraggedObject: (BasePart | Model)? = nil
local CurrentHighlight: Highlight? = nil
local LastSentPosition: Vector3 = Vector3.zero
local _LastTargetCFrame: CFrame = CFrame.new()

local function CreateHighlight(Target: BasePart | Model): Highlight?
	local NewHighlight = Instance.new("Highlight")
	NewHighlight.Name = "DragHighlight"
	NewHighlight.Adornee = Target
	NewHighlight.FillColor = HIGHLIGHT_COLOR
	NewHighlight.FillTransparency = HIGHLIGHT_TRANSPARENCY
	NewHighlight.OutlineColor = HIGHLIGHT_COLOR
	NewHighlight.OutlineTransparency = 0
	NewHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	NewHighlight.Parent = Target

	return NewHighlight
end

local function RemoveHighlight(FadeOut: boolean?)
	if not CurrentHighlight then
		return
	end

	if FadeOut then
		local FadeInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local FadeGoal = {
			FillTransparency = 1,
			OutlineTransparency = 1,
		}

		local FadeTween = TweenService:Create(CurrentHighlight, FadeInfo, FadeGoal)
		FadeTween:Play()

		local HighlightToDestroy = CurrentHighlight
		FadeTween.Completed:Connect(function()
			if HighlightToDestroy then
				HighlightToDestroy:Destroy()
			end
		end)

		CurrentHighlight = nil
	else
		CurrentHighlight:Destroy()
		CurrentHighlight = nil
	end
end

local function IsFirstPerson(): boolean
	if not Player.Character then
		return false
	end

	local Head: BasePart? = Player.Character:FindFirstChild("Head") :: BasePart?
	if not Head then
		return false
	end

	local DistanceToHead: number = (Camera.CFrame.Position - Head.Position).Magnitude
	return DistanceToHead < 2
end

local function AdjustDistance(Direction: number, ModifierHeld: boolean)
	if not IsFirstPerson() and not ModifierHeld then
		return
	end

	CurrentDragDistance = math.clamp(
		CurrentDragDistance + (Direction * DISTANCE_INCREMENT),
		MIN_DRAG_DISTANCE,
		MAX_DRAG_DISTANCE
	)
end

local function UpdateCameraPosition()
	if not Player.Character then
		return
	end

	local Character: Model = Player.Character
	local Head: BasePart? = Character:FindFirstChild("Head") :: BasePart?

	if not Head then
		return
	end

	local HeadPosition: Vector3 = Head.Position
	local CameraPosition: Vector3 = Camera.CFrame.Position
	local DistanceToHead: number = (CameraPosition - HeadPosition).Magnitude
	local IsFirstPersonMode: boolean = DistanceToHead < 2

	local TargetPosition: Vector3

	if IsFirstPersonMode then
		local CameraForward: Vector3 = Camera.CFrame.LookVector
		TargetPosition = HeadPosition + (CameraForward * CurrentDragDistance)
	else
		local MouseDirection: Vector3 = (Mouse.Hit.Position - HeadPosition).Unit
		TargetPosition = HeadPosition + (MouseDirection * CurrentDragDistance)
	end

	local TargetCFrame: CFrame = CFrame.lookAt(TargetPosition, TargetPosition + Camera.CFrame.LookVector)

	local PositionDelta = (TargetPosition - LastSentPosition).Magnitude
	if PositionDelta > POSITION_CHANGE_THRESHOLD then
		LastSentPosition = TargetPosition
		_LastTargetCFrame = TargetCFrame
		Packets.DragUpdate:Fire(TargetCFrame)
	end
end

local function BuildDragWhitelist(): {Instance}
	local List: {Instance} = {}
	for _, Target in CollectionService:GetTagged(DRAG_TAG) do
		table.insert(List, Target)
	end
	return List
end

local function GetTargetPart(): (BasePart | Model)?
	local RaycastParameters = RaycastParams.new()
	RaycastParameters.FilterType = Enum.RaycastFilterType.Include
	RaycastParameters.FilterDescendantsInstances = BuildDragWhitelist()
	RaycastParameters.IgnoreWater = true

	local Ray = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
	local RaycastResult = workspace:Raycast(Ray.Origin, Ray.Direction * DRAG_DETECTION_DISTANCE, RaycastParameters)

	if not RaycastResult then
		return nil
	end

	local HitPart = RaycastResult.Instance
	local Node: Instance? = HitPart

	while Node and Node ~= workspace do
		if CollectionService:HasTag(Node, DRAG_TAG) then
			if Node:IsA("BasePart") then
				local ParentModel = Node:FindFirstAncestorOfClass("Model")
				if ParentModel and CollectionService:HasTag(ParentModel, DRAG_TAG) then
					return ParentModel
				end
			end
			return Node :: any
		end
		Node = Node.Parent
	end

	return nil
end

local function OnDragStart()
	IsMouseHeld = true
	CurrentDragDistance = DRAG_DISTANCE
	LastSentPosition = Vector3.zero

	local Target = GetTargetPart()
	if Target and CollectionService:HasTag(Target, DRAG_TAG) then
		CurrentDraggedObject = Target
		CurrentHighlight = CreateHighlight(Target)
		Packets.DragStart:Fire(Target)

		task.delay(0.25, function()
			if CurrentDraggedObject and not CurrentDraggedObject:GetAttribute("BeingDragged") then
				RemoveHighlight(true)
				CurrentDraggedObject = nil
			end
		end)
	end
end

local function OnDragStop()
	IsMouseHeld = false

	if CurrentHighlight then
		RemoveHighlight(true)
	end

	CurrentDraggedObject = nil
	LastSentPosition = Vector3.zero
	Packets.DragStop:Fire()
end

local function OnDistanceAdjust(Direction: number, ModifierHeld: boolean)
	if IsMouseHeld then
		AdjustDistance(Direction, ModifierHeld)
	end
end

local function CleanupHighlights()
	if CurrentHighlight then
		RemoveHighlight(false)
		CurrentDraggedObject = nil
	end
end

local function StartCameraUpdate()
	if CameraUpdateLoop then
		CameraUpdateLoop:Destroy()
	end

	CameraUpdateLoop = LoopManager.Create(function()
		if IsMouseHeld then
			UpdateCameraPosition()
		end
	end, LoopManager.Rates.Physics)

	CameraUpdateLoop:Start()
end

DragInputHandler.DragStart:Connect(OnDragStart)
DragInputHandler.DragStop:Connect(OnDragStop)
DragInputHandler.AdjustDistance:Connect(OnDistanceAdjust)

Player.CharacterAdded:Connect(function(_Character: Model)
	CleanupHighlights()
	StartCameraUpdate()
end)

if Player.Character then
	StartCameraUpdate()
end