--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local Networking = Shared:WaitForChild("Networking")

local ObjectDatabase = require(Modules:WaitForChild("ObjectDatabase"))
local Packets = require(Networking:WaitForChild("Packets"))
local InteractionFunctions = require(script.Parent:WaitForChild("InteractionFunctions"))

local INTERACTION_TAG: string = "Interactable"
local MAX_INTERACTION_DISTANCE: number = 8

local function IsValidInteraction(Player: Player, Object: Instance): boolean
	if not CollectionService:HasTag(Object, INTERACTION_TAG) then
		return false
	end

	local Owner = Object:GetAttribute("Owner")
	if Owner and Owner ~= Player.UserId then
		return false
	end

	if Object:GetAttribute("BeingDragged") then
		return false
	end

	local Character = Player.Character
	if not Character then
		return false
	end

	local PlayerPosition = Character:GetPivot().Position
	local ObjectPosition: Vector3

	if Object:IsA("Model") then
		ObjectPosition = Object:GetPivot().Position
	elseif Object:IsA("BasePart") then
		ObjectPosition = Object.Position
	else
		return false
	end

	local Distance = (PlayerPosition - ObjectPosition).Magnitude
	if Distance > MAX_INTERACTION_DISTANCE then
		return false
	end

	return true
end

local function OnInteract(Player: Player, Object: Instance)
	if not IsValidInteraction(Player, Object) then
		return
	end

	local ObjectConfig = ObjectDatabase.GetObjectConfig(Object.Name)
	if not ObjectConfig then
		warn("No config found for object:", Object.Name)
		return
	end

	local CurrentState = Object:GetAttribute("CurrentState") or "StateA"
	local StateConfig = (ObjectConfig :: any)[CurrentState]

	if not StateConfig or not StateConfig.Function then
		warn("No function defined for", Object.Name, "state:", CurrentState)
		return
	end

	InteractionFunctions.ExecuteInteraction(
		Player,
		Object,
		ObjectConfig.Type,
		StateConfig.Function,
		ObjectConfig
	)
end

Packets.Interact.OnServerEvent:Connect(OnInteract)