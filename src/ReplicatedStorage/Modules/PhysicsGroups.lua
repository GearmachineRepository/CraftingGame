--!strict
--!optimize 2
local Module = {}

local PhysicsService = game:GetService("PhysicsService")

-- Types
type CollisionRules = {[number]: {[number]: string | boolean}}
type Rule = {[number]: string | boolean}

-- Physics Groups Configuration
local PhysicsGroups: {[number]: string} = {
	[1] = "Dragging", 
	[2] = "Characters"
}

-- Collision Rules: {Group1, Group2, CanCollide}
local CollisionRules: CollisionRules = {
	{"Dragging", "Characters", false}
}

-- Initialize Physics Groups
for Index: number, GroupName: string in pairs(PhysicsGroups) do
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GroupName)
	end)
end

-- Apply collision rules
for _, Rule: Rule in pairs(CollisionRules) do
	PhysicsService:CollisionGroupSetCollidable(Rule[1], Rule[2], Rule[3])
end

-- Set all BaseParts in an instance to a specific collision group
function Module.SetToGroup(InstanceToSet: Instance, GroupName: string): ()
	if not InstanceToSet then return end

	-- Handle single BasePart
	if InstanceToSet:IsA("BasePart") then
		pcall(function()
			InstanceToSet.CollisionGroup = GroupName
		end)
		return
	end

	-- Handle descendants
	for _, Descendant: Instance in pairs(InstanceToSet:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			pcall(function()
				Descendant.CollisionGroup = GroupName
			end)
		end
	end
end

function Module.SetProperty(InstanceToSet: Instance, Property: string, Value: any)
	if not InstanceToSet then return end

	-- Handle single BasePart
	if InstanceToSet:IsA("BasePart") then
		pcall(function()
			local Part: BasePart = InstanceToSet :: BasePart
			(Part :: any)[Property] = Value
		end)
		return
	end

	-- Handle descendants
	for _, Descendant: Instance in pairs(InstanceToSet:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			pcall(function()
				local Part: BasePart = Descendant :: BasePart
				(Part :: any)[Property] = Value
			end)
		end
	end
end

return Module