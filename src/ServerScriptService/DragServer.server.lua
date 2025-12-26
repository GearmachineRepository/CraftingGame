--!strict
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

--Modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PhysicsModule = require(Modules:WaitForChild("PhysicsGroups"))
local UIDManager = require(Modules:WaitForChild("UIDManager"))

-- Constants
local DRAG_TAG: string = "Drag"
local DRAG_ATTACHMENT_NAME: string = "DragAttachment"
local DRAG_NETWORK_DELAY: number = 0.35
local DEFAULT_DRAG_RESPONSIVENESS: number = 25 
local MASS_DIVISOR: number = 10
local REINSTALL_COOLDOWN = 0.6
local SNAP_RADIUS = 8  
local UPDATE_INTERVAL = 1/30

-- Remote Events
local Events: Folder = ReplicatedStorage:WaitForChild("Events")
local DragEvents: Folder = Events:WaitForChild("DragEvents") :: Folder
local UpdateCameraPositionRemote: RemoteEvent = DragEvents:WaitForChild("UpdateCameraPosition") :: RemoteEvent
local DragObjectRemote: RemoteEvent = DragEvents:WaitForChild("DragObject") :: RemoteEvent

-- Player Data Storage
local PlayerData: {[Player]: {
	CFrameValue: CFrameValue?,
	DraggedParts: {[Instance]: RBXScriptConnection?}
}} = {}

-- find nearest ancestor that declares Owner return userId or nil
local function CleanupDragState(Player: Player, Target: Instance)
	local Data = PlayerData[Player] if not Data then return end

	-- physics root
	local PhysicsPart: BasePart? = Target:IsA("Model") and (Target :: Model).PrimaryPart or (Target :: BasePart)
	if not PhysicsPart then return end

	-- disconnect update loop
	local conn = Data.DraggedParts[Target]
	if conn then
		conn:Disconnect()
		Data.DraggedParts[Target] = nil
	end

	-- clear drag flags
	Target:SetAttribute("BeingDragged", nil)
	Target:SetAttribute("DraggedBy", nil)

	-- remove drag attachment
	local dragAtt = PhysicsPart:FindFirstChild("DragAttachment")
	if dragAtt then dragAtt:Destroy() end

	-- disable aligns
	local ap = PhysicsPart:FindFirstChildOfClass("AlignPosition")
	if ap then ap.Enabled = false ap.Attachment0 = nil end
	local ao = PhysicsPart:FindFirstChildOfClass("AlignOrientation")
	if ao then ao.Enabled = false ao.Attachment0 = nil end

	-- release net ownership safely
	task.delay(DRAG_NETWORK_DELAY, function()
		if PhysicsPart:IsDescendantOf(workspace) and not PhysicsPart.Anchored
			and not PhysicsPart:GetAttribute("BeingDragged") then
			pcall(function() PhysicsPart:SetNetworkOwnershipAuto() end)
		end
	end)
end

local function GetOwningUserId(inst: Instance): number?
	local node: Instance? = inst
	while node and node ~= workspace do
		local owner = node:GetAttribute("Owner")
		if typeof(owner) == "number" then
			return owner
		end
		node = node.Parent
	end
	return nil
end

local function GetAncestorCart(inst: Instance): Model?
	local node = inst :: any
	while node and node ~= workspace do
		if node:IsA("Model") and (node:GetAttribute("Type") == "Cart") then
			return node
		end
		-- structural fallback: must have both Root (BasePart) and Wagon (Model) as children
		if node:IsA("Model") then
			local root = node:FindFirstChild("Root")
			local wagon = node:FindFirstChild("Wagon")
			if root and root:IsA("BasePart") and wagon and wagon:IsA("Model") then
				return node
			end
		end
		node = node.Parent
	end
	return nil
end

-- true if player is allowed to drag this target
local function CanPlayerDrag(player: Player, target: Instance): boolean
	-- disallow dragging while pulling a cart (dragging cart itself is handled elsewhere)
	if player:GetAttribute("Carting") then
		return false
	end

	-- hard owner gate: if target (or owning ancestor like a cart) has Owner != player
	local ownerId = GetOwningUserId(target)
	if ownerId and ownerId ~= player.UserId then
		return false
	end

	-- item must be tagged Drag (reduces surprises)
	if not CollectionService:HasTag(target, "Drag") then
		return false
	end

	-- already being dragged by someone else
	if target:GetAttribute("BeingDragged") and target:GetAttribute("DraggedBy") ~= player.Name then
		return false
	end

	return true
end

-- Initialize Player Data
local function InitializePlayerData(Player: Player): ()
	local CFrameValue: CFrameValue = Instance.new("CFrameValue")
	CFrameValue.Name = "CameraPosition"
	CFrameValue.Parent = Player

	PlayerData[Player] = {
		CFrameValue = CFrameValue,
		DraggedParts = {}
	}
	
	Player.CharacterAdded:Connect(function(Character)
		local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 10)
		if HumanoidRootPart then
			PhysicsModule.SetToGroup(Character, "Characters")
		else
			Player:Kick("Took too long to load.")
		end
	end)
end

-- Cleanup Player Data
local function CleanupPlayerData(Player: Player): ()
	local Data = PlayerData[Player]
	if not Data then return end

	-- Stop all drag updates and clear dragged parts
	for PhysicsObject: Instance, Connection: RBXScriptConnection? in pairs(Data.DraggedParts) do
		if Connection then
			Connection:Disconnect()
		end
		StopDragging(Player, PhysicsObject)
	end

	-- Clean up CFrameValue
	if Data.CFrameValue then
		Data.CFrameValue:Destroy()
	end

	PlayerData[Player] = nil
end

-- Setup Drag Components for Parts with Drag Tag
local function SetupDragComponents(Target: Instance): ()
	if Target:IsA("BasePart") then
		local Part: BasePart = Target :: BasePart
		PhysicsModule.SetToGroup(Part, "Dragging")

		if not Part:FindFirstChildOfClass("AlignPosition") then
			local AlignPos: AlignPosition = Instance.new("AlignPosition")
			AlignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
			AlignPos.Enabled = false
			AlignPos.MaxForce = 40000
			AlignPos.Responsiveness = 25
			AlignPos.MaxVelocity = math.huge
			AlignPos.ApplyAtCenterOfMass = true
			AlignPos.Parent = Part
		end

		if not Part:FindFirstChildOfClass("AlignOrientation") then
			local AlignOri: AlignOrientation = Instance.new("AlignOrientation")
			AlignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
			AlignOri.Enabled = false
			AlignOri.MaxTorque = 40000
			AlignOri.Responsiveness = 25
			AlignOri.MaxAngularVelocity = math.huge
			AlignOri.Parent = Part
		end
	elseif Target:IsA("Model") then
		local Model: Model = Target :: Model
		PhysicsModule.SetToGroup(Model, "Dragging")

		-- Ensure model has a PrimaryPart
		if not Model.PrimaryPart then
			Model.PrimaryPart = Model:FindFirstChildWhichIsA("BasePart")
		end

		local PrimaryPart: BasePart? = Model.PrimaryPart
		if PrimaryPart then
			if not PrimaryPart:FindFirstChildOfClass("AlignPosition") then
				local AlignPos: AlignPosition = Instance.new("AlignPosition")
				AlignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
				AlignPos.Enabled = false
				AlignPos.MaxForce = 40000
				AlignPos.Responsiveness = 25
				AlignPos.MaxVelocity = math.huge
				AlignPos.ApplyAtCenterOfMass = true
				AlignPos.Parent = PrimaryPart
			end

			if not PrimaryPart:FindFirstChildOfClass("AlignOrientation") then
				local AlignOri: AlignOrientation = Instance.new("AlignOrientation")
				AlignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
				AlignOri.Enabled = false
				AlignOri.MaxTorque = 40000
				AlignOri.Responsiveness = 25
				AlignOri.MaxAngularVelocity = math.huge
				AlignOri.Parent = PrimaryPart
			end
		end
	end
end

-- Start Dragging Function
local function StartDragging(Player: Player, Target: Instance): ()
	if not CanPlayerDrag(Player, Target) then return end
	
	local Data = PlayerData[Player]
	if not Data or not Data.CFrameValue then return end

	-- Check if target is already being dragged by someone else
	if Target:GetAttribute("BeingDragged") then
		return -- Target is already being dragged
	end
	
	-- Mark target as being dragged
	Target:SetAttribute("LastDetachTime", tick())
	Target:SetAttribute("BeingDragged", true)
	Target:SetAttribute("DraggedBy", Player.Name)

	-- Get the part to apply physics to (PrimaryPart for models, the part itself for BaseParts)
	local PhysicsPart: BasePart?
	if Target:IsA("Model") then
		PhysicsPart = (Target :: Model).PrimaryPart
	elseif Target:IsA("BasePart") then
		PhysicsPart = Target :: BasePart
	end

	if not PhysicsPart then return end
	
	-- Set properties
	PhysicsModule.SetProperty(Target, "Anchored", false)
	
	-- Set network owner to the player for smooth dragging
	PhysicsPart:SetNetworkOwner(Player)

	-- Create drag attachment
	local DragAttachment: Attachment = Instance.new("Attachment")
	DragAttachment.Name = DRAG_ATTACHMENT_NAME
	DragAttachment.Parent = PhysicsPart

	-- Get align components
	local AlignPosition: AlignPosition? = PhysicsPart:FindFirstChildOfClass("AlignPosition")
	local AlignOrientation: AlignOrientation? = PhysicsPart:FindFirstChildOfClass("AlignOrientation")

	if AlignPosition and AlignOrientation then
		-- Calculate responsiveness based on mass (heavier = slower)
		local BaseMass: number = PhysicsPart.AssemblyMass
		local MassMultiplier: number = math.max(1, BaseMass / MASS_DIVISOR)
		local AdjustedResponsiveness: number = DEFAULT_DRAG_RESPONSIVENESS / MassMultiplier

		AdjustedResponsiveness = math.clamp(AdjustedResponsiveness, 1, 50)

		-- Configure and enable align components
		AlignPosition.Attachment0 = DragAttachment
		AlignPosition.Responsiveness = AdjustedResponsiveness -- Use calculated responsiveness
		AlignPosition.Enabled = true

		AlignOrientation.Attachment0 = DragAttachment
		AlignOrientation.Responsiveness = AdjustedResponsiveness -- Match position responsiveness
		AlignOrientation.Enabled = true

		-- Create update loop for this target
		local LastTime = tick()
		local UpdateConnection: RBXScriptConnection = RunService.Heartbeat:Connect(function()
			if tick()- LastTime >= UPDATE_INTERVAL then
				LastTime = tick()

				if Data.CFrameValue then
					local TargetCFrame: CFrame = Data.CFrameValue.Value
					AlignPosition.Position = TargetCFrame.Position
					AlignOrientation.CFrame = TargetCFrame
				end
			end
		end)

		-- Store the connection for cleanup
		Data.DraggedParts[Target] = UpdateConnection
	end
end

-- Stop Dragging Function
function StopDragging(Player: Player, Target: Instance): ()
	local Data = PlayerData[Player]
	if not Data then return end

	-- Verify this player is actually dragging this part
	if Target:GetAttribute("DraggedBy") ~= Player.Name then
		return
	end

	CleanupDragState(Player, Target)
end

-- Stop All Dragging for Player
local function StopAllDragging(Player: Player): ()
	local Data = PlayerData[Player]
	if not Data then return end

	-- Create a copy of the keys to avoid modifying table while iterating
	local PartsToStop: {Instance} = {}
	for Part: Instance in pairs(Data.DraggedParts) do
		table.insert(PartsToStop, Part)
	end

	-- Stop dragging all parts
	for _, Part: Instance in pairs(PartsToStop) do
		StopDragging(Player, Part)
	end
end

-- Remote Event Handlers
UpdateCameraPositionRemote.OnServerEvent:Connect(function(Player: Player, CameraPosition: CFrame)
	local Data = PlayerData[Player]
	if Data and Data.CFrameValue then
		Data.CFrameValue.Value = CameraPosition
	end
end)

DragObjectRemote.OnServerEvent:Connect(function(Player: Player, Part: Instance?, Status: boolean)
	-- Handle stop all dragging (when Part is nil and Status is false)
	if not Part and not Status then
		StopAllDragging(Player)
		return
	end

	-- Validate part exists and has drag tag
	if not Part or not Part.Parent then return end
	if not CollectionService:HasTag(Part, DRAG_TAG) then return end

	if Status then
		StartDragging(Player, Part)
	else
		StopDragging(Player, Part)
	end
end)

-- Collection Service Events
CollectionService:GetInstanceAddedSignal(DRAG_TAG):Connect(SetupDragComponents)

-- Setup existing tagged parts
for _, Target: Instance in pairs(CollectionService:GetTagged(DRAG_TAG)) do
	if Target:IsA("BasePart") or Target:IsA("Model") then
		SetupDragComponents(Target)
	end
end

-- Player Connection Events
Players.PlayerAdded:Connect(InitializePlayerData)
Players.PlayerRemoving:Connect(CleanupPlayerData)

-- Initialize existing players
for _, Player: Player in pairs(Players:GetPlayers()) do
	InitializePlayerData(Player)
end