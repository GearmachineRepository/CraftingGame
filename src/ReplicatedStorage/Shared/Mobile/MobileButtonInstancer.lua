--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MobileModules = Shared:WaitForChild("Mobile")

local MobileButtonConfig = require(MobileModules:WaitForChild("MobileButtonConfig"))

local MobileButtonInstancer = {}

local Player: Player = Players.LocalPlayer

local ButtonContainer: Frame? = nil
local ScreenGui: ScreenGui? = nil
local SizeConnection: RBXScriptConnection? = nil

local ActiveButtons: {[string]: ImageButton} = {}
local ButtonCallbacks: {[string]: () -> ()} = {}

local CurrentSizeMode: string = "Small"

local CONTAINER_PADDING: number = 10
local BUTTON_SPACING: number = 10

local function GetScreenSizeMode(ScreenSize: Vector2): string
	local LongerSide = math.max(ScreenSize.X, ScreenSize.Y)
	if LongerSide > 700 then
		return "Large"
	elseif LongerSide > MobileButtonConfig.ScreenThreshold then
		return "Medium"
	end
	return "Small"
end

local function GetButtonSize(): UDim2
	return MobileButtonConfig.ButtonSize[CurrentSizeMode] or MobileButtonConfig.ButtonSize.Medium
end

local function UpdateButtonSizes()
	local ButtonSize = GetButtonSize()
	for _, Button in ActiveButtons do
		Button.Size = ButtonSize
	end

	if ButtonContainer then
		local ButtonCount = 0
		for _ in ActiveButtons do
			ButtonCount = ButtonCount + 1
		end

		local PixelSize = ButtonSize.X.Offset
		local TotalWidth = (PixelSize * ButtonCount) + (BUTTON_SPACING * math.max(0, ButtonCount - 1))
		ButtonContainer.Size = UDim2.fromOffset(TotalWidth, PixelSize)
		ButtonContainer.Position = UDim2.new(0.5, -TotalWidth / 2, 1, -(PixelSize + CONTAINER_PADDING))
	end
end

local function OnScreenSizeChanged()
	if not ButtonContainer then
		return
	end

	local ScreenSize = ButtonContainer.AbsoluteSize
	local Parent = ButtonContainer.Parent
	if Parent and Parent:IsA("GuiBase2d") then
		ScreenSize = Parent.AbsoluteSize
	end

	local NewMode = GetScreenSizeMode(ScreenSize)
	if NewMode ~= CurrentSizeMode then
		CurrentSizeMode = NewMode
		UpdateButtonSizes()
	end
end

local function CreateButton(Definition: MobileButtonConfig.ButtonDefinition): ImageButton
	local ButtonSize = GetButtonSize()

	local Button = Instance.new("ImageButton")
	Button.Name = Definition.Name .. "Button"
	Button.Size = ButtonSize
	Button.BackgroundColor3 = Definition.BackgroundColor or Color3.fromRGB(60, 60, 60)
	Button.BackgroundTransparency = 0.3
	Button.AutoButtonColor = true
	Button.LayoutOrder = Definition.Order

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0.15, 0)
	Corner.Parent = Button

	if Definition.Region then
		Button.Image = MobileButtonConfig.SpriteSheet
		Button.ImageRectOffset = Definition.Region.Offset
		Button.ImageRectSize = Definition.Region.Size
		Button.ScaleType = Enum.ScaleType.Fit
	else
		Button.Image = ""
	end

	if Definition.Text then
		local Label = Instance.new("TextLabel")
		Label.Name = "ButtonLabel"
		Label.Size = UDim2.fromScale(1, 1)
		Label.BackgroundTransparency = 1
		Label.Text = Definition.Text
		Label.TextColor3 = Color3.new(1, 1, 1)
		Label.TextScaled = true
		Label.Font = Enum.Font.GothamBold
		Label.Parent = Button

		local TextPadding = Instance.new("UIPadding")
		TextPadding.PaddingTop = UDim.new(0.1, 0)
		TextPadding.PaddingBottom = UDim.new(0.1, 0)
		TextPadding.PaddingLeft = UDim.new(0.1, 0)
		TextPadding.PaddingRight = UDim.new(0.1, 0)
		TextPadding.Parent = Label
	end

	Button.Activated:Connect(function()
		local Callback = ButtonCallbacks[Definition.Action]
		if Callback then
			Callback()
		end
	end)

	return Button
end

local function EnsureContainer()
	if ButtonContainer and ButtonContainer.Parent then
		return
	end


	local PlayerGui = Player:WaitForChild("PlayerGui", 5)
	print("PlayerGui:", PlayerGui)

	if not PlayerGui then
		warn("PlayerGui not found!")
		return
	end

	local NewScreenGui = Instance.new("ScreenGui")
	NewScreenGui.Name = "MobileButtonsGui"
	NewScreenGui.ResetOnSpawn = false
	NewScreenGui.DisplayOrder = 10
	NewScreenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	NewScreenGui.Parent = PlayerGui
	ScreenGui = NewScreenGui

	local NewButtonContainer = Instance.new("Frame")
	NewButtonContainer.Name = "ButtonContainer"
	NewButtonContainer.BackgroundTransparency = 1
	NewButtonContainer.Visible = false
	NewButtonContainer.Parent = NewScreenGui
	ButtonContainer = NewButtonContainer

	local Layout = Instance.new("UIListLayout")
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	Layout.Padding = UDim.new(0, BUTTON_SPACING)
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Parent = NewButtonContainer

	if SizeConnection then
		SizeConnection:Disconnect()
	end

	SizeConnection = RunService.RenderStepped:Connect(OnScreenSizeChanged)
	OnScreenSizeChanged()
end

function MobileButtonInstancer.RegisterCallback(Action: string, Callback: () -> ())
	ButtonCallbacks[Action] = Callback
end

function MobileButtonInstancer.UnregisterCallback(Action: string)
	ButtonCallbacks[Action] = nil
end

function MobileButtonInstancer.ShowButton(ButtonName: string)
	EnsureContainer()
	print("ShowButton called:", ButtonName, "Container exists:", ButtonContainer ~= nil)

	if ActiveButtons[ButtonName] then
		return
	end

	local Definition = MobileButtonConfig.Buttons[ButtonName]
	if not Definition then
		warn("No button definition for:", ButtonName)
		return
	end

	local Button = CreateButton(Definition)
	Button.Parent = ButtonContainer

	ActiveButtons[ButtonName] = Button
	UpdateButtonSizes()
end

function MobileButtonInstancer.HideButton(ButtonName: string)
	local Button = ActiveButtons[ButtonName]
	if Button then
		Button:Destroy()
		ActiveButtons[ButtonName] = nil
		UpdateButtonSizes()
	end
end

function MobileButtonInstancer.ShowButtons(ButtonNames: {string})
	for _, Name in ButtonNames do
		MobileButtonInstancer.ShowButton(Name)
	end
end

function MobileButtonInstancer.HideButtons(ButtonNames: {string})
	for _, Name in ButtonNames do
		MobileButtonInstancer.HideButton(Name)
	end
end

function MobileButtonInstancer.HideAllButtons()
	for Name in ActiveButtons do
		MobileButtonInstancer.HideButton(Name)
	end
end

function MobileButtonInstancer.SetContainerVisible(Visible: boolean)
	EnsureContainer()
	print("SetContainerVisible:", Visible, "Container:", ButtonContainer)
	if ButtonContainer then
		ButtonContainer.Visible = Visible
	end
end

function MobileButtonInstancer.IsButtonVisible(ButtonName: string): boolean
	return if not ActiveButtons[ButtonName] then false else true
end

function MobileButtonInstancer.Cleanup()
	if SizeConnection then
		SizeConnection:Disconnect()
		SizeConnection = nil
	end

	for Name in ActiveButtons do
		ActiveButtons[Name]:Destroy()
	end
	table.clear(ActiveButtons)

	if ScreenGui then
		ScreenGui:Destroy()
		ScreenGui = nil
		ButtonContainer = nil
	end
end

return MobileButtonInstancer