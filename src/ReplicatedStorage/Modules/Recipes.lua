local Recipes = {
	Cauldron = {
		["Blue Potion"] = {
			ingredients = {
				["Blue Flower"] = 3
			},
			result = "Blue Potion",
			craftTime = 1, -- seconds
			strictMatch = false -- allows extra ingredients
		},
		["Red Potion"] = {
			ingredients = {
				["Red Flower"] = 3
			},
			result = "Red Potion",
			craftTime = 1, -- seconds
			strictMatch = false -- allows extra ingredients
		},
		["Purple Potion"] = {
			ingredients = {
				{["Blue Flower"] = 2, ["Red Flower"] = 1}, -- Option 1
				{["Blue Flower"] = 1, ["Red Flower"] = 2}, -- Option 2
			},
			result = "Purple Potion",
			craftTime = 1, -- seconds
			strictMatch = false -- allows extra ingredients
		},
		["Mana Potion"] = {
			ingredients = {
				["Blue Herb"] = 2,
				["Water Bottle"] = 1
			},
			result = "Mana Potion",
			craftTime = 5,
			strictMatch = false
		},
		["Poison"] = {
			ingredients = {
				["Mushroom"] = 1,
				["Green Herb"] = 1,
				["Water Bottle"] = 1
			},
			result = "Poison Bottle",
			craftTime = 2,
			strictMatch = true -- must be exact ingredients
		}
	},
}

return Recipes