--!strict
local ObjectDatabase = {}

local KeybindConfig = require(script.Parent:WaitForChild("KeybindConfig"))

type StateConfig = {
	Text: string,
	Function: string,
}

type ObjectConfig = {
	Type: string,
	GridFootprint: Vector2?,
	InteractionSound: string?,
	ReleaseSound: string?,
	InteractionDistance: number?,
	StateA: StateConfig,
	StateB: StateConfig?,
}

ObjectDatabase.Objects = {
	["Blue Flower"] = {
		Type = "Plant",
		GridFootprint = Vector2.new(1, 1),
		InteractionSound = "rbxassetid://9118598470",
		StateA = {
			Text = "Uproot - {INTERACT}",
			Function = "StateAFunction",
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction",
		},
	},
	["Red Flower"] = {
		Type = "Plant",
		GridFootprint = Vector2.new(1, 1),
		InteractionSound = "rbxassetid://9118598470",
		StateA = {
			Text = "Uproot - {INTERACT}",
			Function = "StateAFunction",
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction",
		},
	},
	["Wooden Box"] = {
		Type = "Item",
		GridFootprint = Vector2.new(2, 2),
		InteractionSound = "rbxassetid://9118598470",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction",
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction",
		},
	},
	["Long Wooden Box"] = {
		Type = "Item",
		GridFootprint = Vector2.new(2, 3),
		InteractionSound = "rbxassetid://9118598470",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction",
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction",
		},
	},
	["Large Wooden Box"] = {
		Type = "Item",
		GridFootprint = Vector2.new(3, 3),
		InteractionSound = "rbxassetid://9118598470",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction",
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction",
		},
	},
	["Blue Potion"] = {
		Type = "Item",
		GridFootprint = Vector2.new(1, 1),
		InteractionSound = "rbxassetid://9114618924",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction",
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction",
		},
	},
	["Red Potion"] = {
		Type = "Item",
		GridFootprint = Vector2.new(1, 1),
		InteractionSound = "rbxassetid://9114618924",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction",
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction",
		},
	},
	["Purple Potion"] = {
		Type = "Item",
		GridFootprint = Vector2.new(1, 1),
		InteractionSound = "rbxassetid://9114618924",
		StateA = {
			Text = "Pickup - {INTERACT}",
			Function = "StateAFunction",
		},
		StateB = {
			Text = "Pickup - {INTERACT}",
			Function = "StateBFunction",
		},
	},
	["Cauldron"] = {
		Type = "Cauldron",
		InteractionSound = "rbxassetid://137256690956022",
		StateA = {
			Text = "Begin Brewing - {INTERACT}",
			Function = "StateAFunction",
		},
	},
} :: {[string]: ObjectConfig}

function ObjectDatabase.GetObjectConfig(ObjectName: string): ObjectConfig?
	return ObjectDatabase.Objects[ObjectName]
end

function ObjectDatabase.GetObjectType(ObjectName: string): string?
	local Config = ObjectDatabase.GetObjectConfig(ObjectName)
	return if Config then Config.Type else nil
end

function ObjectDatabase.HasMultipleStates(ObjectName: string): boolean
	local Config = ObjectDatabase.GetObjectConfig(ObjectName)
	return Config ~= nil and Config.StateB ~= nil
end

function ObjectDatabase.FormatInteractionText(Text: string, Platform: string): string
	local InteractKey = KeybindConfig.GetDisplayText(Platform, "Interact")
	local CleanText = string.gsub(Text, " %- {INTERACT}", "")
	return CleanText .. "\n[" .. InteractKey .. "]"
end

return ObjectDatabase