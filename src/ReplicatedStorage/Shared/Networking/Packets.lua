local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = Shared:WaitForChild("Packages")

local Packet = require(Packages:WaitForChild("Packet"))

return {
    Test = Packet("Test", Packet.String),
}