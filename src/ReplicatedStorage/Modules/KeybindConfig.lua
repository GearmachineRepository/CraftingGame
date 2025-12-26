--!strict
local KeybindConfig = {}

-- Platform-specific keybinds
KeybindConfig.Keybinds = {
	PC = {
		Interact = Enum.KeyCode.E,
		Drag = Enum.UserInputType.MouseButton1,
		DistanceModifier = Enum.KeyCode.Q,
		Cancel = Enum.KeyCode.Escape
	},
	Controller = {
		Interact = Enum.KeyCode.ButtonX,
		Drag = Enum.KeyCode.ButtonL2,
		DistanceModifier = Enum.KeyCode.ButtonR2,
		Cancel = Enum.KeyCode.ButtonB,
		Drop = Enum.KeyCode.ButtonY
	},
	Mobile = {
		Interact = "TouchTap",
		Drag = "TouchHold",
		Drop = "TouchHold",
		Cancel = "TouchDoubleTap"
	}
}

-- Get keybind for current platform
function KeybindConfig.GetKeybind(platform: string, action: string)
	local platformKeybinds = KeybindConfig.Keybinds[platform]
	if platformKeybinds then
		return platformKeybinds[action]
	end
	return nil
end

-- Get display text for keybind
function KeybindConfig.GetDisplayText(platform: string, action: string): string
	local keybind = KeybindConfig.GetKeybind(platform, action)
	if not keybind then return action end

	-- Handle string keybinds (Mobile)
	if type(keybind) == "string" then
		local mobileDisplays = {
			["TouchTap"] = "Tap",
			["TouchHold"] = "Hold", 
			["TouchDoubleTap"] = "Double Tap"
		}
		return mobileDisplays[keybind] or keybind
	end

	local enumName = keybind.Name

	-- Custom overrides for better display names
	local customDisplays = {
		-- PC
		["MouseButton1"] = "Left Click",
		["MouseButton2"] = "Right Click",
		["MouseButton3"] = "Middle Click",
		["Return"] = "Enter",
		["LeftShift"] = "Shift",
		["RightShift"] = "Shift",

		-- Controller  
		["ButtonX"] = "X",
		["ButtonY"] = "Y",
		["ButtonA"] = "A",
		["ButtonB"] = "B",
		["ButtonR1"] = "RB",
		["ButtonR2"] = "RT",
		["ButtonL1"] = "LB",
		["ButtonL2"] = "LT"
	}

	return customDisplays[enumName] or enumName
end

return KeybindConfig