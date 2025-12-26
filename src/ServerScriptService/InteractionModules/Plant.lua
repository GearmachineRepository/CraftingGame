--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local SoundModule = require(Modules:WaitForChild("SoundPlayer"))
local ToolInstancer = require(Modules:WaitForChild("ToolInstancer"))

-- Constants
local DRAG_TAG: string = "Drag"

return {
	StateAFunction = function(player: Player, object: Instance, config: any)
		-- Make plant draggable
		CollectionService:AddTag(object, DRAG_TAG)
		object:SetAttribute("CurrentState", "StateB")

		-- Get the physical part to apply velocity to
		local PhysicsPart: BasePart?
		if object:IsA("Model") then
			PhysicsPart = (object :: Model).PrimaryPart
		elseif object:IsA("BasePart") then
			PhysicsPart = object :: BasePart
		end

		if PhysicsPart then
			PhysicsPart.Anchored = false

			local randomDirection = Vector3.new(
				math.random(-10, 10), 
				math.random(15, 25),
				math.random(-10, 10) 
			)

			PhysicsPart.AssemblyLinearVelocity = randomDirection

			local randomRotation = Vector3.new(
				math.random(-5, 5),
				math.random(-5, 5), 
				math.random(-5, 5)
			)
			PhysicsPart.AssemblyAngularVelocity = randomRotation
		end

		if config.InteractionSound then
			SoundModule.PlaySound(config.InteractionSound, PhysicsPart)
		end
	end,

	StateBFunction = ToolInstancer.Pickup
}