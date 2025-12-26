--!strict
local ToolInstancer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local DRAG_TAG: string = "Drag"
local INTERACTION_TAG: string = "Interactable"

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Items = Assets:WaitForChild("Items")

local PHYSICS_CONSTRAINT_TYPES: {string} = {
	"AlignPosition",
	"AlignOrientation",
}

local function CleanupPhysicsConstraints(Target: Instance)
	for _, Child in Target:GetChildren() do
		if Child:IsA("BasePart") then
			for _, ConstraintType in PHYSICS_CONSTRAINT_TYPES do
				local Constraint = Child:FindFirstChildOfClass(ConstraintType)
				if Constraint then
					Constraint:Destroy()
				end
			end

			local DragAttachment = Child:FindFirstChild("DragAttachment")
			if DragAttachment then
				DragAttachment:Destroy()
			end
		end
	end
end

function ToolInstancer.ItemExists(ItemName: string): boolean
	return Items:FindFirstChild(ItemName) ~= nil
end

function ToolInstancer.GetAvailableItems(): {string}
	local ItemNames: {string} = {}
	for _, Item in Items:GetChildren() do
		table.insert(ItemNames, Item.Name)
	end
	return ItemNames
end

function ToolInstancer.Create(Source: Instance | string, Location: CFrame?): Model?
	local SourceObject: Instance?
	local ShouldDestroyOriginal = false

	if type(Source) == "string" then
		local ItemName = Source
		local ItemTemplate = Items:FindFirstChild(ItemName)

		if not ItemTemplate then
			warn("Item '" .. ItemName .. "' not found in Items folder")
			return nil
		end

		SourceObject = ItemTemplate:Clone()
		ShouldDestroyOriginal = false
	else
		SourceObject = Source
		ShouldDestroyOriginal = true
	end

	if not SourceObject then
		warn("No valid source object provided")
		return nil
	end

	CleanupPhysicsConstraints(SourceObject)

	local NewModel = Instance.new("Model")
	NewModel.Name = SourceObject.Name

	local HandlePart: BasePart? = SourceObject:FindFirstChild("Handle") :: BasePart?
	local ToolCFrame: CFrame = if HandlePart then HandlePart.CFrame else CFrame.new()

	if Location then
		ToolCFrame = Location
	end

	local ChildrenToMove: {Instance} = {}
	for _, Child in SourceObject:GetChildren() do
		table.insert(ChildrenToMove, Child)
	end

	for _, Child in ChildrenToMove do
		Child.Parent = NewModel

		if Child == HandlePart then
			Child.Name = "Handle"
			if Child:IsA("BasePart") then
				Child.CanCollide = true
				Child.Anchored = false
			end
		end
	end

	if HandlePart and HandlePart.Parent == NewModel then
		NewModel.PrimaryPart = HandlePart
	else
		NewModel.PrimaryPart = NewModel:FindFirstChildWhichIsA("BasePart")
	end

	local DraggablesFolder = workspace:FindFirstChild("Draggables")
	local InteractablesFolder = workspace:FindFirstChild("Interactables")
	NewModel.Parent = DraggablesFolder or InteractablesFolder or workspace

	if NewModel.PrimaryPart then
		NewModel:PivotTo(ToolCFrame)

		task.spawn(function()
			task.wait()

			if not NewModel:IsDescendantOf(workspace) then
				return
			end

			if NewModel.PrimaryPart then
				pcall(function()
					NewModel.PrimaryPart:SetNetworkOwnershipAuto()
				end)
			end
		end)
	end

	if ShouldDestroyOriginal then
		SourceObject:Destroy()
	end

	NewModel:SetAttribute("CurrentState", "StateB")
	CollectionService:AddTag(NewModel, DRAG_TAG)
	CollectionService:AddTag(NewModel, INTERACTION_TAG)

	return NewModel
end

function ToolInstancer.Pickup(Player: Player, Object: Instance, Config: any)
	local NewTool: Tool
	local ObjectName = Object.Name

	local ExistingTool = Items:FindFirstChild(ObjectName)
	if ExistingTool and ExistingTool:IsA("Tool") then
		NewTool = ExistingTool:Clone()
	else
		NewTool = Instance.new("Tool")
		NewTool.Name = ObjectName
		NewTool.RequiresHandle = true

		if Object:IsA("Model") then
			local TargetModel = Object :: Model
			local PrimaryPart = TargetModel.PrimaryPart or TargetModel:FindFirstChildWhichIsA("BasePart")

			if PrimaryPart then
				for _, Child in TargetModel:GetChildren() do
					if Child:IsA("BasePart") then
						Child.CanCollide = false
						Child.Anchored = false

						for _, ConstraintType in PHYSICS_CONSTRAINT_TYPES do
							local Constraint = Child:FindFirstChildOfClass(ConstraintType)
							if Constraint then
								Constraint:Destroy()
							end
						end
						local DragAttachment = Child:FindFirstChild("DragAttachment")
						if DragAttachment then
							DragAttachment:Destroy()
						end
					end
					Child.Parent = NewTool
				end

				local Handle = NewTool:FindFirstChild(PrimaryPart.Name)
				if Handle and Handle:IsA("BasePart") then
					Handle.Name = "Handle"
					Handle.CanCollide = false
					Handle.Anchored = false
				end
			end
		elseif Object:IsA("BasePart") then
			local Handle = Object:Clone()
			Handle.Name = "Handle"
			Handle.CanCollide = false
			Handle.Anchored = false
			Handle.Parent = NewTool
		end

		if Config then
			NewTool.ToolTip = Config.ToolTip or ObjectName
			if Config.TextureId then
				NewTool.TextureId = Config.TextureId
			end
		else
			NewTool.ToolTip = ObjectName
		end
	end

	NewTool.Parent = Player.Backpack

	if Object:IsDescendantOf(workspace) then
		Object:Destroy()
	end
end

return ToolInstancer