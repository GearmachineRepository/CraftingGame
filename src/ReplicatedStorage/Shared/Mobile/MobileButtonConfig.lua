--!strict
local MobileButtonConfig = {}

export type ButtonRegion = {
	Offset: Vector2,
	Size: Vector2,
}

export type ButtonDefinition = {
	Name: string,
	Action: string,
	Region: ButtonRegion?,
	Text: string?,
	BackgroundColor: Color3?,
	Order: number,
}

MobileButtonConfig.SpriteSheet = "rbxassetid://rbxassetid://107299612426726"

MobileButtonConfig.SheetSize = Vector2.new(512, 512)

MobileButtonConfig.Regions = {
	Drop = {
		Offset = Vector2.new(0, 0),
		Size = Vector2.new(145, 145),
	},
	Pickup = {
		Offset = Vector2.new(145, 0),
		Size = Vector2.new(145, 145),
	},
	Interact = {
		Offset = Vector2.new(290, 0),
		Size = Vector2.new(145, 145),
	},
} :: {[string]: ButtonRegion}

MobileButtonConfig.ButtonSize = {
	Small = UDim2.fromOffset(50, 50),
	Medium = UDim2.fromOffset(70, 70),
	Large = UDim2.fromOffset(90, 90),
}

MobileButtonConfig.ScreenThreshold = 500

MobileButtonConfig.Buttons = {
	DragDrop = {
		Name = "DragDrop",
		Action = "DragDrop",
		Region = MobileButtonConfig.Regions.Drop,
		Text = "Undrag",
		BackgroundColor = Color3.fromRGB(80, 80, 80),
		Order = 1,
	},
	DragPickup = {
		Name = "DragPickup",
		Action = "DragPickup",
		Region = MobileButtonConfig.Regions.Pickup,
		Text = "Pickup",
		BackgroundColor = Color3.fromRGB(60, 120, 60),
		Order = 2,
	},
} :: {[string]: ButtonDefinition}

return MobileButtonConfig