--!strict
local InteractionFunctions = {}

local InteractionModules = script.Parent:WaitForChild("InteractionModules")

local LoadedModules: {[string]: any} = {}

local function LoadInteractionModule(ObjectType: string): any?
	if LoadedModules[ObjectType] then
		return LoadedModules[ObjectType]
	end

	local ModuleScript = InteractionModules:FindFirstChild(ObjectType)
	if not ModuleScript then
		warn("No interaction module found for object type:", ObjectType)
		return nil
	end

	local Success, LoadedModule = pcall(require, ModuleScript)
	if not Success then
		warn("Failed to load interaction module for " .. ObjectType .. ":", tostring(LoadedModule))
		return nil
	end

	LoadedModules[ObjectType] = LoadedModule
	return LoadedModule
end

function InteractionFunctions.ExecuteInteraction(Player: Player, Object: Instance, ObjectType: string, FunctionName: string, Config: any)
	local InteractionModule = LoadInteractionModule(ObjectType)

	if not InteractionModule then
		return
	end

	local InteractionFunction = InteractionModule[FunctionName]
	if not InteractionFunction then
		warn("Function " .. FunctionName .. " not found for object type:", ObjectType)
		return
	end

	local Success, ErrorMessage = pcall(InteractionFunction, Player, Object, Config)
	if not Success then
		warn("Error executing " .. FunctionName .. " for " .. ObjectType .. ":", tostring(ErrorMessage))
	end
end

function InteractionFunctions.ClearCache()
	LoadedModules = {}
end

function InteractionFunctions.GetAvailableTypes(): {string}
	local Types: {string} = {}
	for _, Child in InteractionModules:GetChildren() do
		if Child:IsA("ModuleScript") then
			table.insert(Types, Child.Name)
		end
	end
	return Types
end

return InteractionFunctions