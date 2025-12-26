--!strict
local Recipes = {
	Cauldron = {
		["Blue Potion"] = {
			Ingredients = {
				["Blue Flower"] = 3,
			},
			Result = "Blue Potion",
			CraftTime = 1,
			StrictMatch = false,
		},
		["Red Potion"] = {
			Ingredients = {
				["Red Flower"] = 3,
			},
			Result = "Red Potion",
			CraftTime = 1,
			StrictMatch = false,
		},
		["Purple Potion"] = {
			Ingredients = {
				{ ["Blue Flower"] = 2, ["Red Flower"] = 1 },
				{ ["Blue Flower"] = 1, ["Red Flower"] = 2 },
			},
			Result = "Purple Potion",
			CraftTime = 1,
			StrictMatch = false,
		},
		["Mana Potion"] = {
			Ingredients = {
				["Blue Herb"] = 2,
				["Water Bottle"] = 1,
			},
			Result = "Mana Potion",
			CraftTime = 5,
			StrictMatch = false,
		},
		["Poison"] = {
			Ingredients = {
				["Mushroom"] = 1,
				["Green Herb"] = 1,
				["Water Bottle"] = 1,
			},
			Result = "Poison Bottle",
			CraftTime = 2,
			StrictMatch = true,
		},
	},
}

return Recipes