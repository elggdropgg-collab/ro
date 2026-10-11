--!strict
-- Collects connections, instances, threads and callbacks and cleans them up in one call.

local Maid = {}
Maid.__index = Maid

export type Maid = typeof(setmetatable({} :: { _tasks: { any } }, Maid))

function Maid.new(): Maid
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid.Give<T>(self: Maid, item: T): T
	table.insert(self._tasks, item)
	return item
end

function Maid.Clean(self: Maid)
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		local item = tasks[i]
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" or (kind == "table" and item.Destroy) then
			item:Destroy()
		elseif kind == "function" then
			task.spawn(item)
		elseif kind == "thread" then
			pcall(task.cancel, item)
		end
	end
end

Maid.Destroy = Maid.Clean

return Maid
