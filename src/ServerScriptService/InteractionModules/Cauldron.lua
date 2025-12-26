--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local SoundModule = require(Modules:WaitForChild("SoundPlayer"))
local RecipeChecker = require(Modules:WaitForChild("RecipeChecker"))
local ToolInstancer = require(Modules:WaitForChild("ToolInstancer"))

-- Setup overlap params
local Param = OverlapParams.new()
Param.FilterType = Enum.RaycastFilterType.Include

local function StartCrafting(recipeResult: RecipeChecker.RecipeList, Part: BasePart, Objects: {Instance}?)
	task.wait(recipeResult.recipe.craftTime)
	SoundModule.PlaySound("rbxassetid://5870784443", Part)
	
	if recipeResult.modelsToDestroy then
		for _, model in pairs(recipeResult.modelsToDestroy) do
			if model and model:IsA("Instance") and model:HasTag("Drag") and model:IsDescendantOf(workspace.Draggables) then
				model:Destroy()
			end
		end
	end

	ToolInstancer.Create(recipeResult.name, Part.CFrame * CFrame.new(math.random(-2,2), 5, math.random(-2,2)))
end

return {
	StateAFunction = function(player: Player, object: Instance, config: any)
		object:SetAttribute("Interacting", true)

		local character = player.Character
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")

		if config.InteractionSound then
			local PhysicsPart: BasePart?
			if object:IsA("Model") then
				PhysicsPart = (object :: Model).PrimaryPart
			elseif object:IsA("BasePart") then
				PhysicsPart = object :: BasePart
			end

			if PhysicsPart then
				SoundModule.PlaySound(config.InteractionSound, PhysicsPart)

				Param.FilterDescendantsInstances = {workspace.Draggables}

				local Parts = workspace:GetPartBoundsInBox(PhysicsPart.CFrame, PhysicsPart.Size, Param)

				if #Parts > 0 then
					local matchingRecipe: RecipeChecker.RecipeList? = RecipeChecker.CheckRecipes("Cauldron", Parts)

					if matchingRecipe then
						StartCrafting(matchingRecipe, PhysicsPart, Parts)
					else
						SoundModule.PlaySound("rbxassetid://2390695935", PhysicsPart)
					end
				else
					SoundModule.PlaySound("rbxassetid://2390695935", PhysicsPart)
				end
			end
		end

		if humanoid then
			object:SetAttribute("BrewingPlayer", player.Name)

			-- Clear interaction state when done
			object:SetAttribute("Interacting", nil)
			object:SetAttribute("BrewingPlayer", nil)
		end
	end
}