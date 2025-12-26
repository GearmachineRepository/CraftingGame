--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local Networking = Shared:WaitForChild("Networking")

local PhysicsGroups = require(Modules:WaitForChild("PhysicsGroups"))
local LoopManager = require(Modules:WaitForChild("LoopManager"))
local Packets = require(Networking:WaitForChild("Packets"))

local DRAG_TAG: string = "Drag"
local DRAG_ATTACHMENT_NAME: string = "DragAttachment"
local DRAG_NETWORK_DELAY: number = 0.35
local DEFAULT_DRAG_RESPONSIVENESS: number = 25
local MASS_DIVISOR: number = 10
local POSITION_CHANGE_THRESHOLD: number = 0.1

type DragConnection = {
	Loop: any,
	LastPosition: Vector3,
}

type PlayerDragData = {
	TargetCFrame: CFrame,
	DraggedParts: {[Instance]: DragConnection},
}

local PlayerData: {[Player]: PlayerDragData} = {}

local function CleanupDragState(Player: Player, Target: Instance)
	local Data = PlayerData[Player]
	if not Data then
		return
	end

	local PhysicsPart: BasePart?
	if Target:IsA("Model") then
		PhysicsPart = (Target :: Model).PrimaryPart
	elseif Target:IsA("BasePart") then
		PhysicsPart = Target :: BasePart
	end

	if not PhysicsPart then
		return
	end

	local DragConnection = Data.DraggedParts[Target]
	if DragConnection then
		if DragConnection.Loop then
			DragConnection.Loop:Destroy()
		end
		Data.DraggedParts[Target] = nil
	end

	Target:SetAttribute("BeingDragged", nil)
	Target:SetAttribute("DraggedBy", nil)

	local DragAttachment = PhysicsPart:FindFirstChild(DRAG_ATTACHMENT_NAME)
	if DragAttachment then
		DragAttachment:Destroy()
	end

	local AlignPosition = PhysicsPart:FindFirstChildOfClass("AlignPosition")
	if AlignPosition then
		AlignPosition.Enabled = false
		AlignPosition.Attachment0 = nil
	end

	local AlignOrientation = PhysicsPart:FindFirstChildOfClass("AlignOrientation")
	if AlignOrientation then
		AlignOrientation.Enabled = false
		AlignOrientation.Attachment0 = nil
	end

	task.delay(DRAG_NETWORK_DELAY, function()
		if PhysicsPart:IsDescendantOf(workspace) and not PhysicsPart.Anchored and not PhysicsPart:GetAttribute("BeingDragged") then
			pcall(function()
				PhysicsPart:SetNetworkOwnershipAuto()
			end)
		end
	end)
end

local function GetOwningUserId(Target: Instance): number?
	local Node: Instance? = Target
	while Node and Node ~= workspace do
		local Owner = Node:GetAttribute("Owner")
		if typeof(Owner) == "number" then
			return Owner
		end
		Node = Node.Parent
	end
	return nil
end

local function CanPlayerDrag(Player: Player, Target: Instance): boolean
	local OwnerId = GetOwningUserId(Target)
	if OwnerId and OwnerId ~= Player.UserId then
		return false
	end

	if not CollectionService:HasTag(Target, DRAG_TAG) then
		return false
	end

	if Target:GetAttribute("BeingDragged") and Target:GetAttribute("DraggedBy") ~= Player.Name then
		return false
	end

	return true
end

local function SetupDragComponents(Target: Instance)
	local PhysicsPart: BasePart?

	if Target:IsA("BasePart") then
		PhysicsPart = Target
	elseif Target:IsA("Model") then
		local TargetModel = Target :: Model
		if not TargetModel.PrimaryPart then
			TargetModel.PrimaryPart = TargetModel:FindFirstChildWhichIsA("BasePart")
		end
		PhysicsPart = TargetModel.PrimaryPart
	end

	if not PhysicsPart then
		return
	end

	PhysicsGroups.SetToGroup(Target, "Dragging")

	if not PhysicsPart:FindFirstChildOfClass("AlignPosition") then
		local AlignPosition = Instance.new("AlignPosition")
		AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
		AlignPosition.Enabled = false
		AlignPosition.MaxForce = 40000
		AlignPosition.Responsiveness = DEFAULT_DRAG_RESPONSIVENESS
		AlignPosition.MaxVelocity = math.huge
		AlignPosition.ApplyAtCenterOfMass = true
		AlignPosition.Parent = PhysicsPart
	end

	if not PhysicsPart:FindFirstChildOfClass("AlignOrientation") then
		local AlignOrientation = Instance.new("AlignOrientation")
		AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		AlignOrientation.Enabled = false
		AlignOrientation.MaxTorque = 40000
		AlignOrientation.Responsiveness = DEFAULT_DRAG_RESPONSIVENESS
		AlignOrientation.MaxAngularVelocity = math.huge
		AlignOrientation.Parent = PhysicsPart
	end
end

local function StartDragging(Player: Player, Target: Instance)
	if not CanPlayerDrag(Player, Target) then
		return
	end

	local Data = PlayerData[Player]
	if not Data then
		return
	end

	if Target:GetAttribute("BeingDragged") then
		return
	end

	Target:SetAttribute("LastDetachTime", tick())
	Target:SetAttribute("BeingDragged", true)
	Target:SetAttribute("DraggedBy", Player.Name)

	local PhysicsPart: BasePart?
	if Target:IsA("Model") then
		PhysicsPart = (Target :: Model).PrimaryPart
	elseif Target:IsA("BasePart") then
		PhysicsPart = Target :: BasePart
	end

	if not PhysicsPart then
		return
	end

	PhysicsGroups.SetProperty(Target, "Anchored", false)
	PhysicsPart:SetNetworkOwner(Player)

	local DragAttachment = Instance.new("Attachment")
	DragAttachment.Name = DRAG_ATTACHMENT_NAME
	DragAttachment.Parent = PhysicsPart

	local AlignPosition = PhysicsPart:FindFirstChildOfClass("AlignPosition")
	local AlignOrientation = PhysicsPart:FindFirstChildOfClass("AlignOrientation")

	if AlignPosition and AlignOrientation then
		local BaseMass = PhysicsPart.AssemblyMass
		local MassMultiplier = math.max(1, BaseMass / MASS_DIVISOR)
		local AdjustedResponsiveness = math.clamp(DEFAULT_DRAG_RESPONSIVENESS / MassMultiplier, 1, 50)

		AlignPosition.Attachment0 = DragAttachment
		AlignPosition.Responsiveness = AdjustedResponsiveness
		AlignPosition.Enabled = true

		AlignOrientation.Attachment0 = DragAttachment
		AlignOrientation.Responsiveness = AdjustedResponsiveness
		AlignOrientation.Enabled = true

		local DragConnection: DragConnection = {
			Loop = nil,
			LastPosition = Data.TargetCFrame.Position,
		}

		local UpdateLoop = LoopManager.Create(function()
			if not Data or not Data.TargetCFrame then
				return
			end

			local TargetPosition = Data.TargetCFrame.Position
			local PositionDelta = (TargetPosition - DragConnection.LastPosition).Magnitude

			if PositionDelta > POSITION_CHANGE_THRESHOLD then
				AlignPosition.Position = TargetPosition
				AlignOrientation.CFrame = Data.TargetCFrame
				DragConnection.LastPosition = TargetPosition
			end
		end, LoopManager.Rates.Physics)

		DragConnection.Loop = UpdateLoop
		UpdateLoop:Start()

		Data.DraggedParts[Target] = DragConnection
	end
end

local function StopDragging(Player: Player, Target: Instance)
	local Data = PlayerData[Player]
	if not Data then
		return
	end

	if Target:GetAttribute("DraggedBy") ~= Player.Name then
		return
	end

	CleanupDragState(Player, Target)
end

local function StopAllDragging(Player: Player)
	local Data = PlayerData[Player]
	if not Data then
		return
	end

	local PartsToStop: {Instance} = {}
	for Part in Data.DraggedParts do
		table.insert(PartsToStop, Part)
	end

	for _, Part in PartsToStop do
		StopDragging(Player, Part)
	end
end

local function InitializePlayerData(Player: Player)
	PlayerData[Player] = {
		TargetCFrame = CFrame.new(),
		DraggedParts = {},
	}

	Player.CharacterAdded:Connect(function(Character)
		local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 10)
		if HumanoidRootPart then
			PhysicsGroups.SetToGroup(Character, "Characters")
		else
			Player:Kick("Character failed to load properly.")
		end
	end)
end

local function CleanupPlayerData(Player: Player)
	local Data = PlayerData[Player]
	if not Data then
		return
	end

	for Target, DragConnection in Data.DraggedParts do
		if DragConnection.Loop then
			DragConnection.Loop:Destroy()
		end
		CleanupDragState(Player, Target)
	end

	PlayerData[Player] = nil
end

Packets.DragUpdate.OnServerEvent:Connect(function(Player: Player, TargetCFrame: CFrame)
	local Data = PlayerData[Player]
	if Data then
		Data.TargetCFrame = TargetCFrame
	end
end)

Packets.DragStart.OnServerEvent:Connect(function(Player: Player, Target: Instance)
	if not Target or not Target.Parent then
		return
	end
	if not CollectionService:HasTag(Target, DRAG_TAG) then
		return
	end
	StartDragging(Player, Target)
end)

Packets.DragStop.OnServerEvent:Connect(function(Player: Player)
	StopAllDragging(Player)
end)

Packets.DragStopAll.OnServerEvent:Connect(function(Player: Player)
	StopAllDragging(Player)
end)

CollectionService:GetInstanceAddedSignal(DRAG_TAG):Connect(SetupDragComponents)

for _, Target in CollectionService:GetTagged(DRAG_TAG) do
	if Target:IsA("BasePart") or Target:IsA("Model") then
		SetupDragComponents(Target)
	end
end

Players.PlayerAdded:Connect(InitializePlayerData)
Players.PlayerRemoving:Connect(CleanupPlayerData)

for _, Player in Players:GetPlayers() do
	InitializePlayerData(Player)
end