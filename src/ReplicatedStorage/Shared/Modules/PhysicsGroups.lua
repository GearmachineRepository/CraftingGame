--!strict
local PhysicsService = game:GetService("PhysicsService")

local PhysicsGroups = {}

local GROUP_NAMES: {string} = {
	"Dragging",
	"Characters",
}

type CollisionRule = {string | boolean}

local COLLISION_RULES: {CollisionRule} = {
	{"Dragging", "Characters", false},
}

for _, GroupName in GROUP_NAMES do
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GroupName)
	end)
end

for _, Rule in COLLISION_RULES do
	local GroupA = Rule[1] :: string
	local GroupB = Rule[2] :: string
	local CanCollide = Rule[3] :: boolean
	PhysicsService:CollisionGroupSetCollidable(GroupA, GroupB, CanCollide)
end

function PhysicsGroups.SetToGroup(Target: Instance, GroupName: string)
	if not Target then
		return
	end

	if Target:IsA("BasePart") then
		pcall(function()
			Target.CollisionGroup = GroupName
		end)
		return
	end

	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("BasePart") then
			pcall(function()
				Descendant.CollisionGroup = GroupName
			end)
		end
	end
end

function PhysicsGroups.SetProperty(Target: Instance, PropertyName: string, Value: any)
	if not Target then
		return
	end

	if Target:IsA("BasePart") then
		pcall(function()
			(Target :: any)[PropertyName] = Value
		end)
		return
	end

	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("BasePart") then
			pcall(function()
				(Descendant :: any)[PropertyName] = Value
			end)
		end
	end
end

return PhysicsGroups