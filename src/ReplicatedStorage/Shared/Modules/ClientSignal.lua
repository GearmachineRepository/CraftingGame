--!strict
local ClientSignal = {}
ClientSignal.__index = ClientSignal

export type ClientSignal<T...> = {
	Connect: (self: ClientSignal<T...>, Callback: (T...) -> ()) -> Connection,
	Fire: (self: ClientSignal<T...>, T...) -> (),
	Wait: (self: ClientSignal<T...>) -> T...,
	Destroy: (self: ClientSignal<T...>) -> (),
}

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

type ConnectionInternal = {
	Callback: (...any) -> (),
	Connected: boolean,
	Disconnect: (self: ConnectionInternal) -> (),
}

type SignalInternal = {
	Connections: {ConnectionInternal},
	WaitingThreads: {thread},
}

function ClientSignal.new<T...>(): ClientSignal<T...>
	local self = setmetatable({}, ClientSignal) :: any
	self.Connections = {}
	self.WaitingThreads = {}
	return self
end

function ClientSignal:Connect(Callback: (...any) -> ()): Connection
	local InternalSelf = self :: SignalInternal

	local ConnectionData: ConnectionInternal = {
		Callback = Callback,
		Connected = true,
		Disconnect = function(ConnectionSelf: ConnectionInternal)
			ConnectionSelf.Connected = false
			local Index = table.find(InternalSelf.Connections, ConnectionSelf)
			if Index then
				table.remove(InternalSelf.Connections, Index)
			end
		end,
	}

	table.insert(InternalSelf.Connections, ConnectionData)
	return ConnectionData :: any
end

function ClientSignal:Fire(...: any)
	local InternalSelf = self :: SignalInternal

	for _, ConnectionData in InternalSelf.Connections do
		if ConnectionData.Connected then
			task.spawn(ConnectionData.Callback, ...)
		end
	end

	for _, WaitingThread in InternalSelf.WaitingThreads do
		task.spawn(WaitingThread, ...)
	end
	table.clear(InternalSelf.WaitingThreads)
end

function ClientSignal:Wait(): ...any
	local InternalSelf = self :: SignalInternal
	table.insert(InternalSelf.WaitingThreads, coroutine.running())
	return coroutine.yield()
end

function ClientSignal:Destroy()
	local InternalSelf = self :: SignalInternal
	table.clear(InternalSelf.Connections)
	table.clear(InternalSelf.WaitingThreads)
end

return ClientSignal