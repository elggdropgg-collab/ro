--!strict
-- Minimal script signal for communication between services.

local Signal = {}
Signal.__index = Signal

type Handler = { fn: (...any) -> (), connected: boolean }

export type Connection = { Disconnect: () -> () }
export type Signal = typeof(setmetatable({} :: { _handlers: { Handler } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, fn: (...any) -> ()): Connection
	local handler: Handler = { fn = fn, connected = true }
	table.insert(self._handlers, handler)
	return {
		Disconnect = function()
			handler.connected = false
			local index = table.find(self._handlers, handler)
			if index then
				table.remove(self._handlers, index)
			end
		end,
	}
end

function Signal.Fire(self: Signal, ...: any)
	for _, handler in table.clone(self._handlers) do
		if handler.connected then
			task.spawn(handler.fn, ...)
		end
	end
end

return Signal
