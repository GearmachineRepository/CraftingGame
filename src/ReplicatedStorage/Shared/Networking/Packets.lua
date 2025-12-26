--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = Shared:WaitForChild("Packages")

local Packet = require(Packages:WaitForChild("Packet"))

return {
	DragUpdate = Packet("DragUpdate", Packet.Any),
	DragStart = Packet("DragStart", Packet.Instance),
	DragStop = Packet("DragStop"),
	DragStopAll = Packet("DragStopAll"),

	Interact = Packet("Interact", Packet.Instance),
	Drop = Packet("Drop"),
}