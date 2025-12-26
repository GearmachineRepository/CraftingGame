--!strict
local RecipeChecker = {}
local Recipes = require(script.Parent:WaitForChild("Recipes"))

-- Types
type IngredientList = {[string]: number}
type RecipeVariation = IngredientList
type RecipeIngredients = IngredientList | {RecipeVariation}
export type RecipeList = {
	name: string,
	recipe: any,
	ingredients: {string},
	ingredientCounts: {[string]: number},
	matchedVariation: IngredientList?,
	modelsToDestroy: {Model|Instance}?
}


-- Helper function to get the name/type of an object
local function GetObjectType(object: Instance): string?
	if object:IsA("Model") then
		return object.Name
	elseif object:IsA("BasePart") then
		local parentModel = object:FindFirstAncestorOfClass("Model")
		if parentModel and parentModel:IsDescendantOf(workspace.Draggables) then
			return parentModel.Name
		end
		return object.Name
	elseif object:IsA("Tool") then
		return object.Name
	end
	return nil
end

-- Extract ingredients from parts found in bounds
local function ExtractIngredients(parts: {Instance})
	local ingredients = {}
	local ingredientCounts = {}
	local ingredientModels = {}

	local seenModels = {}

	for _, part in pairs(parts) do
		local model = nil
		if part:IsA("Model") then
			model = part
		elseif part:IsA("BasePart") then
			model = part:FindFirstAncestorOfClass("Model") :: Model
		elseif part:IsA("Tool") then
			model = part
		end

		if model and not seenModels[model] then
			seenModels[model] = true
			local objectType = GetObjectType(model)

			if objectType then
				ingredientCounts[objectType] = (ingredientCounts[objectType] or 0) + 1

				if not ingredientModels[objectType] then
					ingredientModels[objectType] = {}
				end
				table.insert(ingredientModels[objectType], model)

				if not table.find(ingredients, objectType) then
					table.insert(ingredients, objectType)
				end
			end
		end
	end

	return ingredients, ingredientCounts, ingredientModels
end

-- Check if ingredients match a single recipe variation
local function DoesVariationMatch(variation: IngredientList, ingredientCounts: {[string]: number}, strictMatch: boolean): boolean
	for ingredient, requiredAmount in pairs(variation) do
		local availableAmount = ingredientCounts[ingredient] or 0
		if availableAmount < requiredAmount then
			return false
		end
	end

	if strictMatch then
		for ingredient, availableAmount in pairs(ingredientCounts) do
			local requiredAmount = variation[ingredient] or 0
			if requiredAmount == 0 then
				return false
			end
		end
	end

	return true
end

-- Check if ingredients match a recipe (supports both old and new format)
local function DoesRecipeMatch(recipe: any, ingredientCounts: {[string]: number}): (boolean, IngredientList?)
	local ingredients = recipe.ingredients
	local strictMatch: boolean = recipe.strictMatch or false

	if type(ingredients[1]) == "table" then
		for _, variation in pairs(ingredients) do
			if DoesVariationMatch(variation, ingredientCounts, strictMatch) then
				return true, variation -- Return which variation matched
			end
		end
		return false, nil
	else
		local matches = DoesVariationMatch(ingredients, ingredientCounts, strictMatch)
		return matches, if matches then ingredients else nil
	end
end

-- Main function to check recipes for a specific crafting station
function RecipeChecker.CheckRecipes(stationType: string, parts: {Instance}): RecipeList?
	local stationRecipes = Recipes[stationType]
	if not stationRecipes then
		warn("No recipes found for station type: " .. tostring(stationType))
		return nil
	end

	local ingredients, ingredientCounts, ingredientModels = ExtractIngredients(parts)

	for recipeName, recipe in pairs(stationRecipes) do
		local matches, matchedVariation = DoesRecipeMatch(recipe, ingredientCounts)
		if matches and matchedVariation then
			-- Select only required number of models per ingredient
			local modelsToDestroy = {}

			for ingredientName, requiredCount in pairs(matchedVariation) do
				local availableModels = ingredientModels[ingredientName] or {}
				for i = 1, requiredCount do
					if availableModels[i] then
						table.insert(modelsToDestroy, availableModels[i])
					end
				end
			end

			return {
				name = recipeName,
				recipe = recipe,
				ingredients = ingredients,
				ingredientCounts = ingredientCounts,
				matchedVariation = matchedVariation,
				modelsToDestroy = modelsToDestroy
			}
		end
	end

	return nil
end

-- Get all possible recipes for a station
function RecipeChecker.GetRecipesForStation(stationType: string): {[string]: any}
	return Recipes[stationType] or {}
end

-- Check what recipes are possible with current ingredients
function RecipeChecker.GetPossibleRecipes(stationType: string, parts: {Instance}): {{name: string, recipe: any, canMake: boolean, matchedVariation: IngredientList?, missingIngredients: {{variation: IngredientList, missing: {{ingredient: string, needed: number}}}}}}
	local stationRecipes = Recipes[stationType]
	if not stationRecipes then
		return {}
	end

	local ingredients, ingredientCounts = ExtractIngredients(parts)
	local possibleRecipes: {{name: string, recipe: any, canMake: boolean, matchedVariation: IngredientList?, missingIngredients: any}} = {}

	for recipeName, recipe in pairs(stationRecipes) do
		local recipeIngredients = recipe.ingredients
		local canMake = false
		local bestVariation = nil
		local allMissingIngredients = {}

		if type(recipeIngredients[1]) == "table" then
			for _, variation in pairs(recipeIngredients) do
				local variationCanMake = true
				local missingIngredients = {}

				for ingredient, requiredAmount in pairs(variation) do
					local availableAmount = ingredientCounts[ingredient] or 0
					if availableAmount < requiredAmount then
						variationCanMake = false
						table.insert(missingIngredients, {
							ingredient = ingredient,
							needed = requiredAmount - availableAmount
						})
					end
				end

				if variationCanMake then
					canMake = true
					bestVariation = variation
					break
				else
					table.insert(allMissingIngredients, {
						variation = variation,
						missing = missingIngredients
					})
				end
			end
		else
			local missingIngredients = {}
			canMake = true

			for ingredient, requiredAmount in pairs(recipeIngredients) do
				local availableAmount = ingredientCounts[ingredient] or 0
				if availableAmount < requiredAmount then
					canMake = false
					table.insert(missingIngredients, {
						ingredient = ingredient,
						needed = requiredAmount - availableAmount
					})
				end
			end

			if not canMake then
				table.insert(allMissingIngredients, {
					variation = recipeIngredients,
					missing = missingIngredients
				})
			end
		end

		table.insert(possibleRecipes, {
			name = recipeName,
			recipe = recipe,
			canMake = canMake,
			matchedVariation = bestVariation,
			missingIngredients = allMissingIngredients
		})
	end

	return possibleRecipes
end

return RecipeChecker