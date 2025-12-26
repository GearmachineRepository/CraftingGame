local ToolInstancer = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Modules
local SoundPlayer = require(script.Parent:WaitForChild("SoundPlayer"))

-- Constants
local DRAG_TAG: string = "Drag"
local INTERACTION_TAG: string = "Interactable"

-- Assets
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Items = Assets:WaitForChild("Items")

-- check if an item exists in the Items folder
function ToolInstancer.ItemExists(itemName: string): boolean
	return Items:FindFirstChild(itemName) ~= nil
end

-- get all available item names
function ToolInstancer.GetAvailableItems(): {string}
	local itemNames = {}
	for _, item in pairs(Items:GetChildren()) do
		table.insert(itemNames, item.Name)
	end
	return itemNames
end

function ToolInstancer.Create(object: Instance | string, Location: CFrame?): Model?
	local sourceObject: Instance?
	local shouldDestroyOriginal = false

	if type(object) == "string" then
		local itemName = object :: string
		local itemTemplate = Items:FindFirstChild(itemName)

		if not itemTemplate then
			warn("Item '" .. itemName .. "' not found in Items folder")
			return nil
		end

		-- Clone the item template
		sourceObject = itemTemplate:Clone()
		shouldDestroyOriginal = false -- Don't destroy the template
	else
		-- Handle Instance input
		sourceObject = object :: Instance
		shouldDestroyOriginal = true -- Destroy the original object
	end

	if not sourceObject then
		warn("No valid source object provided")
		return nil
	end

	local model = Instance.new("Model")
	model.Name = sourceObject.Name

	local handle: BasePart? = sourceObject:FindFirstChild("Handle") :: BasePart?

	
	local toolCFrame: CFrame = handle and handle.CFrame or CFrame.new()
	if Location then
		toolCFrame = Location
	end

	-- Move/copy all children from source to model
	local childrenToMove = {}
	for _, child in pairs(sourceObject:GetChildren()) do
		table.insert(childrenToMove, child)
	end

	for _, child in pairs(childrenToMove) do
		-- For string-based creation, we're working with a clone, so we can move directly
		-- For instance-based creation, we're moving from the original
		child.Parent = model

		if child == handle then
			child.Name = "Handle" 
			if child:IsA("BasePart") then
				child.CanCollide = true
				child.Anchored = false
			end
		end
	end

	-- Set primary part
	if handle and handle.Parent == model then
		model.PrimaryPart = handle
	else
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	end

	-- Set collision properties for all parts
	for _, part in pairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.CanCollide = true
			part.Anchored = false
		end
	end

	model.Parent = workspace:FindFirstChild("Draggables") or workspace:FindFirstChild("Interactables")

	-- Set position
	if model.PrimaryPart then
		model.PrimaryPart:SetNetworkOwnershipAuto()
		model:PivotTo(toolCFrame)
	end

	-- Clean up original if needed
	if shouldDestroyOriginal then
		sourceObject:Destroy()
	end

	-- Add attributes and tags
	model:SetAttribute("CurrentState", "StateB")
	CollectionService:AddTag(model, DRAG_TAG)
	CollectionService:AddTag(model, INTERACTION_TAG)

	return model
end

function ToolInstancer.Pickup(player: Player, object: Instance, config: any): ()
	local tool: Tool
	local objectName = object.Name

	local existingTool = Items:FindFirstChild(objectName)
	if existingTool and existingTool:IsA("Tool") then
		tool = existingTool:Clone()
	else
		tool = Instance.new("Tool")
		tool.Name = objectName
		tool.RequiresHandle = true

		if object:IsA("Model") then
			local primaryPart = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				
				for _, child in pairs(object:GetChildren()) do
					child.Parent = tool
				end
				
				local handle = tool:FindFirstChild(primaryPart.Name)
				if handle and handle:IsA("BasePart") then
					handle.Name = "Handle"
					handle.CanCollide = false
					handle.Anchored = false
				end
			end
		elseif object:IsA("BasePart") then
			-- Clone the part as the handle
			local handle = object:Clone()
			handle.Name = "Handle"
			handle.CanCollide = false
			handle.Anchored = false
			handle.Parent = tool
		end

		-- Set tool properties based on config or defaults
		if config then
			tool.ToolTip = config.ToolTip or objectName
			if config.TextureId then
				tool.TextureId = config.TextureId
			end
		else
			tool.ToolTip = objectName
		end
	end
	
	tool.Parent = player.Backpack

	if object:IsDescendantOf(workspace) then
		object:Destroy()
	end
end

return ToolInstancer
