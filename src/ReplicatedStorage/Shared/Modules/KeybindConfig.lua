--!strict
local KeybindConfig = {}

type PlatformKeybinds = {
	Interact: Enum.KeyCode | Enum.UserInputType | string,
	Drag: Enum.KeyCode | Enum.UserInputType | string,
	DistanceModifier: Enum.KeyCode | Enum.UserInputType | string?,
	Cancel: Enum.KeyCode | Enum.UserInputType | string,
	Drop: (Enum.KeyCode | Enum.UserInputType | string)?,
}

KeybindConfig.Keybinds = {
	PC = {
		Interact = Enum.KeyCode.E,
		Drag = Enum.UserInputType.MouseButton1,
		DistanceModifier = Enum.KeyCode.Q,
		Cancel = Enum.KeyCode.Escape,
		Drop = Enum.KeyCode.G,
	},
	Controller = {
		Interact = Enum.KeyCode.ButtonX,
		Drag = Enum.KeyCode.ButtonL2,
		DistanceModifier = Enum.KeyCode.ButtonR2,
		Cancel = Enum.KeyCode.ButtonB,
		Drop = Enum.KeyCode.ButtonY,
	},
	Mobile = {
		Interact = "TouchTap",
		Drag = "TouchHold",
		Drop = "DropButton",
		Cancel = "TouchDoubleTap",
	},
} :: {[string]: PlatformKeybinds}

local DISPLAY_NAMES: {[string]: string} = {
	MouseButton1 = "Left Click",
	MouseButton2 = "Right Click",
	MouseButton3 = "Middle Click",
	Return = "Enter",
	LeftShift = "Shift",
	RightShift = "Shift",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonA = "A",
	ButtonB = "B",
	ButtonR1 = "RB",
	ButtonR2 = "RT",
	ButtonL1 = "LB",
	ButtonL2 = "LT",
	TouchTap = "Tap",
	TouchHold = "Hold",
	TouchDoubleTap = "Double Tap",
	DropButton = "Drop Button",
}

function KeybindConfig.GetKeybind(Platform: string, Action: string): (Enum.KeyCode | Enum.UserInputType | string)?
	local PlatformKeybindData = KeybindConfig.Keybinds[Platform]
	if PlatformKeybindData then
		return (PlatformKeybindData :: any)[Action]
end
	return nil
end

function KeybindConfig.GetDisplayText(Platform: string, Action: string): string
	local Keybind = KeybindConfig.GetKeybind(Platform, Action)
	if not Keybind then
		return Action
	end

	if type(Keybind) == "string" then
		return DISPLAY_NAMES[Keybind] or Keybind
	end

	local EnumName = Keybind.Name
	return DISPLAY_NAMES[EnumName] or EnumName
end

return KeybindConfig