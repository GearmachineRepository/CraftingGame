--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local SoundPlayer = require(Modules:WaitForChild("SoundPlayer"))
local RecipeChecker = require(Modules:WaitForChild("RecipeChecker"))
local ToolInstancer = require(Modules:WaitForChild("ToolInstancer"))

local FAILURE_SOUND: string = "rbxassetid://2390695935"
local SUCCESS_SOUND: string = "rbxassetid://5870784443"

local OverlapParameters = OverlapParams.new()
OverlapParameters.FilterType = Enum.RaycastFilterType.Include

local function StartCrafting(RecipeResult: RecipeChecker.RecipeResult, CraftingPart: BasePart)
	task.wait(RecipeResult.Recipe.CraftTime)
	SoundPlayer.PlaySound(SUCCESS_SOUND, CraftingPart)

	if RecipeResult.ModelsToDestroy then
		for _, TargetModel in RecipeResult.ModelsToDestroy do
			local DraggablesFolder = workspace:FindFirstChild("Draggables")
			if TargetModel and TargetModel:IsA("Instance") and TargetModel:HasTag("Drag") and DraggablesFolder and TargetModel:IsDescendantOf(DraggablesFolder) then
				TargetModel:Destroy()
			end
		end
	end

	local SpawnOffset = CFrame.new(math.random(-2, 2), 5, math.random(-2, 2))
	ToolInstancer.Create(RecipeResult.Name, CraftingPart.CFrame * SpawnOffset)
end

return {
	StateAFunction = function(Player: Player, Object: Instance, Config: any)
		Object:SetAttribute("Interacting", true)

		local Character = Player.Character
		if not Character then
			return
		end

		local Humanoid = Character:FindFirstChildOfClass("Humanoid")

		if Config.InteractionSound then
			local PhysicsPart: BasePart?
			if Object:IsA("Model") then
				PhysicsPart = (Object :: Model).PrimaryPart
			elseif Object:IsA("BasePart") then
				PhysicsPart = Object :: BasePart
			end

			if PhysicsPart then
				SoundPlayer.PlaySound(Config.InteractionSound, PhysicsPart)

				local DraggablesFolder = workspace:FindFirstChild("Draggables")
				if DraggablesFolder then
					OverlapParameters.FilterDescendantsInstances = {DraggablesFolder}
				end

				local Parts = workspace:GetPartBoundsInBox(PhysicsPart.CFrame, PhysicsPart.Size, OverlapParameters)

				if #Parts > 0 then
					local MatchingRecipe = RecipeChecker.CheckRecipes("Cauldron", Parts)

					if MatchingRecipe then
						StartCrafting(MatchingRecipe, PhysicsPart)
					else
						SoundPlayer.PlaySound(FAILURE_SOUND, PhysicsPart)
					end
				else
					SoundPlayer.PlaySound(FAILURE_SOUND, PhysicsPart)
				end
			end
		end

		if Humanoid then
			Object:SetAttribute("BrewingPlayer", Player.Name)
			Object:SetAttribute("Interacting", nil)
			Object:SetAttribute("BrewingPlayer", nil)
		end
	end,
}