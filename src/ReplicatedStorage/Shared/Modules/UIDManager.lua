--!strict

local HttpService = game:GetService("HttpService")
local UIDManager = {}

-- Returns the UID string, creating one if missing
function UIDManager.ensureModelUID(inst: Instance): string
	local uid = inst:GetAttribute("UID")
	if typeof(uid) ~= "string" or #uid == 0 then
		uid = HttpService:GenerateGUID(false)
		inst:SetAttribute("UID", uid)
	end
	return uid
end

function UIDManager.clearModelUID(inst: Instance)
	if inst:GetAttribute("UID") then
		inst:SetAttribute("UID", nil)
	end
end

function UIDManager.matches(inst: Instance, otherUID: string): boolean
	return inst:GetAttribute("UID") == otherUID
end

return UIDManager