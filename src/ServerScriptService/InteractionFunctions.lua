--!strict
local InteractionFunctions = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Interaction Modules
local InteractionModules = script.Parent:WaitForChild("InteractionModules")

-- Cache for loaded interaction modules
local LoadedModules: {[string]: any} = {}

-- Load an interaction module
local function LoadInteractionModule(objectType: string): any?
	if LoadedModules[objectType] then
		return LoadedModules[objectType]
	end

	local moduleScript = InteractionModules:FindFirstChild(objectType)
	if not moduleScript then
		warn("No interaction module found for object type: " .. objectType)
		return nil
	end

	local success, module = pcall(require, moduleScript)
	if not success then
		warn("Failed to load interaction module for " .. objectType .. ": " .. tostring(module))
		return nil
	end

	LoadedModules[objectType] = module
	return module
end

-- Execute interaction based on object type and state
function InteractionFunctions.ExecuteInteraction(player: Player, object: Instance, objectType: string, functionName: string, config: any): ()
	local interactionModule = LoadInteractionModule(objectType)
	
	if not interactionModule then
		return
	end

	local interactionFunction = interactionModule[functionName]
	if not interactionFunction then
		warn("Function " .. functionName .. " not found for object type: " .. objectType)
		return
	end

	-- Execute the function
	local success, error = pcall(interactionFunction, player, object, config)
	if not success then
		warn("Error executing " .. functionName .. " for " .. objectType .. ": " .. tostring(error))
	end
end

-- Clear module cache
function InteractionFunctions.ClearCache(): ()
	LoadedModules = {}
end

-- Get all available interaction types
function InteractionFunctions.GetAvailableTypes(): {string}
	local types = {}
	for _, child in pairs(InteractionModules:GetChildren()) do
		if child:IsA("ModuleScript") then
			table.insert(types, child.Name)
		end
	end
	return types
end

return InteractionFunctions