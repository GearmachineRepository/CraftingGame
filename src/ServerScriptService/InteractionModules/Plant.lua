--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local SoundPlayer = require(Modules:WaitForChild("SoundPlayer"))
local ToolInstancer = require(Modules:WaitForChild("ToolInstancer"))

local DRAG_TAG: string = "Drag"

local UPROOT_VELOCITY_MIN: number = -10
local UPROOT_VELOCITY_MAX: number = 10
local UPROOT_HEIGHT_MIN: number = 15
local UPROOT_HEIGHT_MAX: number = 25
local UPROOT_ANGULAR_MIN: number = -5
local UPROOT_ANGULAR_MAX: number = 5

return {
	StateAFunction = function(_Player: Player, Object: Instance, Config: any)
		CollectionService:AddTag(Object, DRAG_TAG)
		Object:SetAttribute("CurrentState", "StateB")

		local PhysicsPart: BasePart?
		if Object:IsA("Model") then
			PhysicsPart = (Object :: Model).PrimaryPart
		elseif Object:IsA("BasePart") then
			PhysicsPart = Object :: BasePart
		end

		if PhysicsPart then
			PhysicsPart.Anchored = false

			local RandomDirection = Vector3.new(
				math.random(UPROOT_VELOCITY_MIN, UPROOT_VELOCITY_MAX),
				math.random(UPROOT_HEIGHT_MIN, UPROOT_HEIGHT_MAX),
				math.random(UPROOT_VELOCITY_MIN, UPROOT_VELOCITY_MAX)
			)
			PhysicsPart.AssemblyLinearVelocity = RandomDirection

			local RandomRotation = Vector3.new(
				math.random(UPROOT_ANGULAR_MIN, UPROOT_ANGULAR_MAX),
				math.random(UPROOT_ANGULAR_MIN, UPROOT_ANGULAR_MAX),
				math.random(UPROOT_ANGULAR_MIN, UPROOT_ANGULAR_MAX)
			)
			PhysicsPart.AssemblyAngularVelocity = RandomRotation
		end

		if Config.InteractionSound then
			SoundPlayer.PlaySound(Config.InteractionSound, PhysicsPart)
		end
	end,

	StateBFunction = ToolInstancer.Pickup,
}