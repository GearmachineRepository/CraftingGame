--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local Networking = Shared:WaitForChild("Networking")

local ToolInstancer = require(Modules:WaitForChild("ToolInstancer"))
local Packets = require(Networking:WaitForChild("Packets"))

type ToolConnectionData = {[number]: RBXScriptConnection}

type ToolEntry = {
	Tool: Tool?,
	Connections: ToolConnectionData,
}

type PlayerToolData = {
	Tools: {[Instance]: ToolEntry},
}

local PlayerData: {[Player]: PlayerToolData} = {}

local DROP_DISTANCE: number = 3
local DROP_BUFFER: number = 0.5

local RaycastParameters = RaycastParams.new()
RaycastParameters.FilterType = Enum.RaycastFilterType.Exclude

local function HookEvent(ConnectionTable: ToolConnectionData, Connection: RBXScriptConnection)
	table.insert(ConnectionTable, Connection)
end

local function SetupTool(Player: Player, NewTool: Tool)
	local Data = PlayerData[Player]
	if not Data then
		return
	end

	if not Data.Tools[NewTool] then
		Data.Tools[NewTool] = {
			Tool = NewTool,
			Connections = {},
		}
	end

	local ToolEntry = Data.Tools[NewTool]

	HookEvent(ToolEntry.Connections, NewTool.Equipped:Connect(function()
	end))

	HookEvent(ToolEntry.Connections, NewTool.Unequipped:Connect(function()
	end))

	HookEvent(ToolEntry.Connections, NewTool.Activated:Connect(function()
	end))
end

local function CleanupTool(Player: Player, OldTool: Tool)
	local Data = PlayerData[Player]
	if not Data then
		return
	end

	local ToolEntry = Data.Tools[OldTool]
	if ToolEntry then
		for _, Connection in ToolEntry.Connections do
			if Connection then
				Connection:Disconnect()
			end
		end
		Data.Tools[OldTool] = nil
	end
end

local function HandleDropRequest(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	local RootPart = Character.PrimaryPart
	if not RootPart then
		return
	end

	local EquippedTool = Character:FindFirstChildWhichIsA("Tool")
	if not EquippedTool then
		return
	end

	local RootPosition = RootPart.Position
	local LookVector = RootPart.CFrame.LookVector
	local DropPosition = RootPosition + (LookVector * DROP_DISTANCE)

	RaycastParameters.FilterDescendantsInstances = {Character}

	local RaycastResult = workspace:Raycast(RootPosition, LookVector * DROP_DISTANCE, RaycastParameters)

	if RaycastResult then
		local HitDistance = (RaycastResult.Position - RootPosition).Magnitude
		local SafeDistance = math.max(DROP_BUFFER, HitDistance - DROP_BUFFER)
		DropPosition = RootPosition + (LookVector * SafeDistance)
	end

	ToolInstancer.Create(EquippedTool, CFrame.new(DropPosition))
end

local function InitializePlayerData(Player: Player)
	PlayerData[Player] = {
		Tools = {},
	}

	Player.CharacterAdded:Connect(function(Character)
		Character.ChildAdded:Connect(function(Child: Instance)
			if Child:IsA("Tool") then
				SetupTool(Player, Child)
			end
		end)

		Character.ChildRemoved:Connect(function(Child: Instance)
			if Child:IsA("Tool") then
				CleanupTool(Player, Child)
			end
		end)
	end)
end

local function CleanupPlayerData(Player: Player)
	local Data = PlayerData[Player]
	if not Data then
		return
	end

	PlayerData[Player] = nil
end

Packets.Drop.OnServerEvent:Connect(HandleDropRequest)

Players.PlayerAdded:Connect(InitializePlayerData)
Players.PlayerRemoving:Connect(CleanupPlayerData)

for _, Player in Players:GetPlayers() do
	InitializePlayerData(Player)
end

workspace.ChildAdded:Connect(function(Child)
	if Child:IsA("Tool") then
		task.wait(0.1)
		ToolInstancer.Create(Child)
	end
end)