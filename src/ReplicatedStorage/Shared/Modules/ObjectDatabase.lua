--!strict
local ObjectDatabase = {}

local KeybindConfig = require(script.Parent:WaitForChild("KeybindConfig"))

--InteractionDistance is optional

-- Object configurations
ObjectDatabase.Objects = {
	["Blue Flower"] = {
		Type = "Plant",
		GridFootprint = Vector2.new(1, 1),
		InteractionSound = "rbxassetid://9118598470",
		StateA = {
			Text = "Uproot - {INTERACT}",
			Function = "StateAFunction"
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction"
		},
	},
	["Red Flower"] = {
		Type = "Plant",
		GridFootprint = Vector2.new(1, 1),
		InteractionSound = "rbxassetid://9118598470",
		StateA = {
			Text = "Uproot - {INTERACT}",
			Function = "StateAFunction"
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction"
		},
	},
	["Wooden Box"] = {
		Type = "Item",
		GridFootprint = Vector2.new(2, 2),
		InteractionSound = "rbxassetid://9118598470",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction"
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction"
		},
	},
	["Long Wooden Box"] = {
		Type = "Item",
		GridFootprint = Vector2.new(2, 3),
		InteractionSound = "rbxassetid://9118598470",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction"
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction"
		},
	},
	["Large Wooden Box"] = {
		Type = "Item",
		GridFootprint = Vector2.new(3, 3),
		InteractionSound = "rbxassetid://9118598470",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction"
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction"
		},
	},
	["Blue Potion"] = {
		Type = "Item",
		GridFootprint = Vector2.new(1, 1),
		InteractionSound = "rbxassetid://9114618924",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction"
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction"
		},
	},
	["Red Potion"] = {
		Type = "Item",
		GridFootprint = Vector2.new(1, 1),
		InteractionSound = "rbxassetid://9114618924",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction"
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction"
		},
	},
	["Purple Potion"] = {
		Type = "Item",
		GridFootprint = Vector2.new(1, 1),
		InteractionSound = "rbxassetid://9114618924",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction"
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction"
		},
	},
	["Small Cart"] = {
		Type = "Cart",
		InteractionSound = "rbxassetid://95897689644876",
		ReleaseSound = "rbxassetid://95897689644876",
		StateA = {
			Text = "Pull - {INTERACT}",
			Function = "StateAFunction"
		},
		StateB = {
			Text = "Drop - {INTERACT}",
			Function = "StateBFunction"
		},
	},
	["Cauldron"] = {
		Type = "Cauldron",
		InteractionSound = "rbxassetid://137256690956022",
		StateA = {
			Text = "Begin Brewing - {INTERACT}",
			Function = "StateAFunction"
		}
	},
}

-- Get object configuration
function ObjectDatabase.GetObjectConfig(objectName: string)
	return ObjectDatabase.Objects[objectName]
end

-- Get object type
function ObjectDatabase.GetObjectType(objectName: string): string?
	local config = ObjectDatabase.GetObjectConfig(objectName)
	return config and config.Type
end

-- Check if object has multiple states
function ObjectDatabase.HasMultipleStates(objectName: string): boolean
	local config = ObjectDatabase.GetObjectConfig(objectName)
	return config and config.StateB ~= nil
end

-- Format interaction text with keybind on separate line
function ObjectDatabase.FormatInteractionText(text: string, platform: string): string
	local interactKey = KeybindConfig.GetDisplayText(platform, "Interact")
	local cleanText = string.gsub(text, " %- {INTERACT}", "") -- Remove " - {INTERACT}" part
	return cleanText .. "\n[" .. interactKey .. "]"
end

return ObjectDatabase