--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ToolInstancer = require(Modules:WaitForChild("ToolInstancer"))

-- Assets
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Items = Assets:WaitForChild("Items")

-- Remote Events
local Events: Folder = ReplicatedStorage:WaitForChild("Events") :: Folder
local InteractionEvents: Folder = Events:WaitForChild("InteractionEvents") :: Folder
local DropRemote: RemoteEvent = InteractionEvents:WaitForChild("Drop") :: RemoteEvent

-- Types
type ConnectionData = {[number]: RBXScriptConnection}
type ToolData = {[Instance]: {Tool: Tool?, Connections: ConnectionData}}
type PlayerData = {[Player]: {
	Tools: ToolData,
}}

-- Constants
local DRAG_TAG: string = "Drag"
local INTERACTION_TAG: string = "Interactable"

-- Player Data Storage
local PlayerData: PlayerData = {}

local function HookEvent(Table: ConnectionData, Event: RBXScriptConnection): ()
	table.insert(Table, Event)
end

local function SetupTool(Player: Player, Child: Tool): ()
	local ToolData: ToolData = PlayerData[Player].Tools
	if not ToolData[Child] then
		ToolData[Child] = {Tool = Child, Connections = {}}
	end
	
	HookEvent(ToolData[Child].Connections, Child.Equipped:Connect(function()

	end))
	HookEvent(ToolData[Child].Connections, Child.Unequipped:Connect(function()

	end))
	HookEvent(ToolData[Child].Connections, Child.Activated:Connect(function()
		
	end))
end

local function CleanupTool(Player: Player, Child: Tool): ()
	local ToolData: ToolData = PlayerData[Player].Tools

	-- Disconnect connections first
	if ToolData[Child] then
		for Index, Connection: RBXScriptConnection in pairs(ToolData[Child].Connections) do
			if Connection then
				Connection:Disconnect()
			end
		end
		ToolData[Child] = {Tool = nil, Connections = {}}
	end
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function DropRequest(Player: Player)
	local Character = Player.Character
	if Character then
		local Root = Character.PrimaryPart
		if not Root then return end

		local Tool = Character:FindFirstChildWhichIsA("Tool")
		if Tool then
			local rootPosition = Root.Position
			local rootLookVector = Root.CFrame.LookVector
			local dropDistance = 3 -- studs in front of character
			local dropPosition = rootPosition + (rootLookVector * dropDistance)

			raycastParams.FilterDescendantsInstances = {Character}

			local raycastResult = workspace:Raycast(rootPosition, rootLookVector * dropDistance, raycastParams)

			if raycastResult then
				local hitDistance = (raycastResult.Position - rootPosition).Magnitude
				local safeDistance = math.max(0.5, hitDistance - 0.5) -- Leave 0.5 stud buffer
				dropPosition = rootPosition + (rootLookVector * safeDistance)
			end
			
			ToolInstancer.Create(Tool, CFrame.new(dropPosition))
			Tool:Destroy()
		end
	end
end

-- Initialize Player Data
local function InitializePlayerData(Player: Player): ()

	PlayerData[Player] = {
		Tools = {}
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

-- Cleanup Player Data
local function CleanupPlayerData(Player: Player): ()
	local Data = PlayerData[Player]
	if not Data then return end

	PlayerData[Player] = nil
end

-- Player Connection Events
Players.PlayerAdded:Connect(InitializePlayerData)
Players.PlayerRemoving:Connect(CleanupPlayerData)

-- Events
DropRemote.OnServerEvent:Connect(DropRequest)

-- Initialize existing players
for _, Player: Player in pairs(Players:GetPlayers()) do
	InitializePlayerData(Player)
end

-- Monitor workspace for dropped tools
workspace.ChildAdded:Connect(function(child)
	if child:IsA("Tool") then
		task.wait(0.1)

		ToolInstancer.Create(child)
	end
end)