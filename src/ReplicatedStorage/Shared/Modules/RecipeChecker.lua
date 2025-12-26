--!strict
local RecipeChecker = {}

local Recipes = require(script.Parent:WaitForChild("Recipes"))

type IngredientList = {[string]: number}
type RecipeVariation = IngredientList

export type RecipeResult = {
	Name: string,
	Recipe: any,
	Ingredients: {string},
	IngredientCounts: {[string]: number},
	MatchedVariation: IngredientList?,
	ModelsToDestroy: {Model | Instance}?,
}

local function GetObjectType(Object: Instance): string?
	if Object:IsA("Model") then
		return Object.Name
	elseif Object:IsA("BasePart") then
		local ParentModel = Object:FindFirstAncestorOfClass("Model")
		if ParentModel and ParentModel:IsDescendantOf(workspace:FindFirstChild("Draggables")) then
			return ParentModel.Name
		end
		return Object.Name
	elseif Object:IsA("Tool") then
		return Object.Name
	end
	return nil
end

local function ExtractIngredients(Parts: {Instance}): ({string}, {[string]: number}, {[string]: {Instance}})
	local IngredientNames: {string} = {}
	local IngredientCounts: {[string]: number} = {}
	local IngredientModels: {[string]: {Instance}} = {}
	local SeenModels: {[Instance]: boolean} = {}

	for _, Part in Parts do
		local TargetModel: Instance? = nil

		if Part:IsA("Model") or Part:IsA("Tool") then
			TargetModel = Part
		elseif Part:IsA("BasePart") then
			TargetModel = Part:FindFirstAncestorOfClass("Model")
		end

		if TargetModel and not SeenModels[TargetModel] then
			SeenModels[TargetModel] = true
			local ObjectType = GetObjectType(TargetModel)

			if ObjectType then
				IngredientCounts[ObjectType] = (IngredientCounts[ObjectType] or 0) + 1

				if not IngredientModels[ObjectType] then
					IngredientModels[ObjectType] = {}
				end
				table.insert(IngredientModels[ObjectType], TargetModel)

				if not table.find(IngredientNames, ObjectType) then
					table.insert(IngredientNames, ObjectType)
				end
			end
		end
	end

	return IngredientNames, IngredientCounts, IngredientModels
end

local function DoesVariationMatch(Variation: IngredientList, IngredientCounts: {[string]: number}, StrictMatch: boolean): boolean
	for IngredientName, RequiredAmount in Variation do
		local AvailableAmount = IngredientCounts[IngredientName] or 0
		if AvailableAmount < RequiredAmount then
			return false
		end
	end

	if StrictMatch then
		for IngredientName, _AvailableAmount in IngredientCounts do
			local RequiredAmount = Variation[IngredientName] or 0
			if RequiredAmount == 0 then
				return false
			end
		end
	end

	return true
end

local function DoesRecipeMatch(RecipeData: any, IngredientCounts: {[string]: number}): (boolean, IngredientList?)
	local RecipeIngredients = RecipeData.Ingredients
	local StrictMatch: boolean = RecipeData.StrictMatch or false

	if type(RecipeIngredients[1]) == "table" then
		for _, Variation in RecipeIngredients do
			if DoesVariationMatch(Variation, IngredientCounts, StrictMatch) then
				return true, Variation
			end
		end
		return false, nil
	else
		local Matches = DoesVariationMatch(RecipeIngredients, IngredientCounts, StrictMatch)
		return Matches, if Matches then RecipeIngredients else nil
	end
end

function RecipeChecker.CheckRecipes(StationType: string, Parts: {Instance}): RecipeResult?
	local StationRecipes = Recipes[StationType]
	if not StationRecipes then
		warn("No recipes found for station type:", StationType)
		return nil
	end

	local IngredientNames, IngredientCounts, IngredientModels = ExtractIngredients(Parts)

	for RecipeName, RecipeData in StationRecipes do
		local Matches, MatchedVariation = DoesRecipeMatch(RecipeData, IngredientCounts)

		if Matches and MatchedVariation then
			local ModelsToDestroy: {Instance} = {}

			for IngredientName, RequiredCount in MatchedVariation do
				local AvailableModels = IngredientModels[IngredientName] or {}
				for Index = 1, RequiredCount do
					if AvailableModels[Index] then
						table.insert(ModelsToDestroy, AvailableModels[Index])
					end
				end
			end

			return {
				Name = RecipeName,
				Recipe = RecipeData,
				Ingredients = IngredientNames,
				IngredientCounts = IngredientCounts,
				MatchedVariation = MatchedVariation,
				ModelsToDestroy = ModelsToDestroy,
			}
		end
	end

	return nil
end

function RecipeChecker.GetRecipesForStation(StationType: string): {[string]: any}
	return Recipes[StationType] or {}
end

type PossibleRecipe = {
	Name: string,
	Recipe: any,
	CanMake: boolean,
	MatchedVariation: IngredientList?,
	MissingIngredients: {{Variation: IngredientList, Missing: {{Ingredient: string, Needed: number}}}},
}

function RecipeChecker.GetPossibleRecipes(StationType: string, Parts: {Instance}): {PossibleRecipe}
	local StationRecipes = Recipes[StationType]
	if not StationRecipes then
		return {}
	end

	local _, IngredientCounts = ExtractIngredients(Parts)
	local PossibleRecipes: {PossibleRecipe} = {}

	for RecipeName, RecipeData in StationRecipes do
		local RecipeIngredients = RecipeData.Ingredients
		local CanMake = false
		local BestVariation: IngredientList? = nil
		local AllMissingIngredients: {{Variation: IngredientList, Missing: {{Ingredient: string, Needed: number}}}} = {}

		if type(RecipeIngredients[1]) == "table" then
			for _, Variation in RecipeIngredients do
				local VariationCanMake = true
				local MissingIngredients: {{Ingredient: string, Needed: number}} = {}

				for IngredientName, RequiredAmount in Variation do
					local AvailableAmount = IngredientCounts[IngredientName] or 0
					if AvailableAmount < RequiredAmount then
						VariationCanMake = false
						table.insert(MissingIngredients, {
							Ingredient = IngredientName,
							Needed = RequiredAmount - AvailableAmount,
						})
					end
				end

				if VariationCanMake then
					CanMake = true
					BestVariation = Variation
					break
				else
					table.insert(AllMissingIngredients, {
						Variation = Variation,
						Missing = MissingIngredients,
					})
				end
			end
		else
			local MissingIngredients: {{Ingredient: string, Needed: number}} = {}
			CanMake = true

			for IngredientName, RequiredAmount in RecipeIngredients do
				local AvailableAmount = IngredientCounts[IngredientName] or 0
				if AvailableAmount < RequiredAmount then
					CanMake = false
					table.insert(MissingIngredients, {
						Ingredient = IngredientName,
						Needed = RequiredAmount - AvailableAmount,
					})
				end
			end

			if not CanMake then
				table.insert(AllMissingIngredients, {
					Variation = RecipeIngredients,
					Missing = MissingIngredients,
				})
			end
		end

		table.insert(PossibleRecipes, {
			Name = RecipeName,
			Recipe = RecipeData,
			CanMake = CanMake,
			MatchedVariation = BestVariation,
			MissingIngredients = AllMissingIngredients,
		})
	end

	return PossibleRecipes
end

return RecipeChecker