--!strict
local RunService = game:GetService("RunService")

local LoopManager = {}

type LoopData = {
	Callback: (DeltaTime: number) -> (),
	Interval: number,
	Accumulated: number,
	Connection: RBXScriptConnection?,
	Active: boolean,
}

export type ManagedLoop = {
	Start: (self: ManagedLoop) -> (),
	Stop: (self: ManagedLoop) -> (),
	SetInterval: (self: ManagedLoop, Interval: number) -> (),
	IsActive: (self: ManagedLoop) -> boolean,
	Destroy: (self: ManagedLoop) -> (),
}

local RATE_UI_UPDATE: number = 1 / 30
local RATE_PHYSICS_UPDATE: number = 1 / 60
local RATE_NETWORK_UPDATE: number = 1 / 30

LoopManager.Rates = {
	UI = RATE_UI_UPDATE,
	Physics = RATE_PHYSICS_UPDATE,
	Network = RATE_NETWORK_UPDATE,
}

function LoopManager.Create(Callback: (DeltaTime: number) -> (), Interval: number): ManagedLoop
	local LoopData: LoopData = {
		Callback = Callback,
		Interval = Interval,
		Accumulated = 0,
		Connection = nil,
		Active = false,
	}

	local ManagedLoopInstance: ManagedLoop = {} :: any

	function ManagedLoopInstance:Start()
		if LoopData.Active then
			return
		end

		LoopData.Active = true
		LoopData.Accumulated = 0

		LoopData.Connection = RunService.Heartbeat:Connect(function(DeltaTime: number)
			LoopData.Accumulated = LoopData.Accumulated + DeltaTime

			if LoopData.Accumulated >= LoopData.Interval then
				LoopData.Accumulated = LoopData.Accumulated - LoopData.Interval
				LoopData.Callback(DeltaTime)
			end
		end)
	end

	function ManagedLoopInstance:Stop()
		if not LoopData.Active then
			return
		end

		LoopData.Active = false

		if LoopData.Connection then
			LoopData.Connection:Disconnect()
			LoopData.Connection = nil
		end
	end

	function ManagedLoopInstance:SetInterval(NewInterval: number)
		LoopData.Interval = NewInterval
	end

	function ManagedLoopInstance:IsActive(): boolean
		return LoopData.Active
	end

	function ManagedLoopInstance:Destroy()
		ManagedLoopInstance:Stop()
	end

	return ManagedLoopInstance
end

return LoopManager