--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local SoundModule = require(Modules:WaitForChild("SoundPlayer"))
local ToolInstancer = require(Modules:WaitForChild("ToolInstancer"))

return {
	StateAFunction = ToolInstancer.Pickup,
	StateBFunction = ToolInstancer.Pickup,
}