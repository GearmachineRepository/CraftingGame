--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local Networking = Shared:WaitForChild("Networking")

local PhysicsGroups = require(Modules:WaitForChild("PhysicsGroups"))
local Packets = require(Networking:WaitForChild("Packets"))

local DRAG_TAG: string = "Drag"
local DRAG_ATTACHMENT_NAME: string = "DragAttachment"
local DRAG_NETWORK_DELAY: number = 0.35
local DEFAULT_DRAG_RESPONSIVENESS: number = 25
local MASS_DIVISOR: number = 10
local POSITION_CHANGE_THRESHOLD: number = 0.1

type DragState = {
	Target: Instance,
	PhysicsPart: BasePart,
	LastPosition: Vector3,
}

type PlayerDragData = {
	TargetCFrame: CFrame,
	DraggedParts: {[Instance]: DragState},
}

local PlayerData: {[Player]: PlayerDragData} = {}
local PhysicsConnection: RBXScriptConnection? = nil
local ActiveDragCount: number = 0

local function GetPhysicsPart(Target: Instance): BasePart?
	if Target:IsA("Model") then
		return (Target :: Model).PrimaryPart
	elseif Target:IsA("BasePart") then
		return Target :: BasePart
	end
	return nil
end

local function CleanupDragState(Player: Player, Target: Instance)
	local Data = PlayerData[Player]
	if not Data then
		return
	end

	local PhysicsPart = GetPhysicsPart(Target)
	if not PhysicsPart then
		return
	end

	local DragState = Data.DraggedParts[Target]
	if DragState then
		Data.DraggedParts[Target] = nil
		ActiveDragCount = math.max(0, ActiveDragCount - 1)
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
		if PhysicsPart and PhysicsPart:IsDescendantOf(workspace) and not PhysicsPart.Anchored and not Target:GetAttribute("BeingDragged") then
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

local function SetupOrResetConstraint<T>(PhysicsPart: BasePart, ConstraintClass: string, SetupFunction: (T) -> ()): T
	local Existing = PhysicsPart:FindFirstChildOfClass(ConstraintClass)

	if Existing then
		SetupFunction(Existing :: any)
		return Existing :: any
	end

	local NewConstraint = Instance.new(ConstraintClass)
	SetupFunction(NewConstraint :: any)
	NewConstraint.Parent = PhysicsPart
	return NewConstraint :: any
end

local function SetupDragComponents(Target: Instance)
	local PhysicsPart = GetPhysicsPart(Target)
	if not PhysicsPart then
		if Target:IsA("Model") then
			local TargetModel = Target :: Model
			TargetModel.PrimaryPart = TargetModel:FindFirstChildWhichIsA("BasePart")
			PhysicsPart = TargetModel.PrimaryPart
		end
	end

	if not PhysicsPart then
		return
	end

	PhysicsGroups.SetToGroup(Target, "Dragging")

	SetupOrResetConstraint(PhysicsPart, "AlignPosition", function(Constraint: AlignPosition)
		Constraint.Mode = Enum.PositionAlignmentMode.OneAttachment
		Constraint.Enabled = false
		Constraint.Attachment0 = nil
		Constraint.MaxForce = 40000
		Constraint.Responsiveness = DEFAULT_DRAG_RESPONSIVENESS
		Constraint.MaxVelocity = math.huge
		Constraint.ApplyAtCenterOfMass = true
	end)

	SetupOrResetConstraint(PhysicsPart, "AlignOrientation", function(Constraint: AlignOrientation)
		Constraint.Mode = Enum.OrientationAlignmentMode.OneAttachment
		Constraint.Enabled = false
		Constraint.Attachment0 = nil
		Constraint.MaxTorque = 40000
		Constraint.Responsiveness = DEFAULT_DRAG_RESPONSIVENESS
		Constraint.MaxAngularVelocity = math.huge
	end)
end

local function UpdateAllDrags()
	for _Player, Data in PlayerData do
		if not Data.TargetCFrame then
			continue
		end

		for Target, DragState in Data.DraggedParts do
			if not Target:IsDescendantOf(workspace) then
				continue
			end

			local TargetPosition = Data.TargetCFrame.Position
			local PositionDelta = (TargetPosition - DragState.LastPosition).Magnitude

			if PositionDelta > POSITION_CHANGE_THRESHOLD then
				local AlignPosition = DragState.PhysicsPart:FindFirstChildOfClass("AlignPosition")
				local AlignOrientation = DragState.PhysicsPart:FindFirstChildOfClass("AlignOrientation")

				if AlignPosition then
					AlignPosition.Position = TargetPosition
				end
				if AlignOrientation then
					AlignOrientation.CFrame = Data.TargetCFrame
				end

				DragState.LastPosition = TargetPosition
			end
		end
	end
end

local function StartPhysicsLoop()
	if PhysicsConnection then
		return
	end

	PhysicsConnection = RunService.Heartbeat:Connect(UpdateAllDrags)
end

local function StopPhysicsLoop()
	if PhysicsConnection then
		PhysicsConnection:Disconnect()
		PhysicsConnection = nil
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

	local PhysicsPart = GetPhysicsPart(Target)
	if not PhysicsPart then
		return
	end

	SetupDragComponents(Target)

	Target:SetAttribute("LastDetachTime", tick())
	Target:SetAttribute("BeingDragged", true)
	Target:SetAttribute("DraggedBy", Player.Name)

	PhysicsGroups.SetProperty(Target, "Anchored", false)

	pcall(function()
		PhysicsPart:SetNetworkOwner(Player)
	end)

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

		local DragState: DragState = {
			Target = Target,
			PhysicsPart = PhysicsPart,
			LastPosition = Data.TargetCFrame.Position,
		}

		Data.DraggedParts[Target] = DragState
		ActiveDragCount = ActiveDragCount + 1

		if ActiveDragCount == 1 then
			StartPhysicsLoop()
		end
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

	if ActiveDragCount == 0 then
		StopPhysicsLoop()
	end
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

	for Target in Data.DraggedParts do
		CleanupDragState(Player, Target)
	end

	PlayerData[Player] = nil

	if ActiveDragCount == 0 then
		StopPhysicsLoop()
	end
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