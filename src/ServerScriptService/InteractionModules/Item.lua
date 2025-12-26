--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local ToolInstancer = require(Modules:WaitForChild("ToolInstancer"))

return {
	StateAFunction = ToolInstancer.Pickup,
	StateBFunction = ToolInstancer.Pickup,
}