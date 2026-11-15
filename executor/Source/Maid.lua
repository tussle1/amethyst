local Maid = {}
Maid.__index = Maid

---Create an owner for temporary connections and instances.
---@return table
function Maid.new()
	return setmetatable({tasks = {}}, Maid)
end

---Register a cleanup task for a feature's lifetime.
---@param task any
---@return any
function Maid:give(task)
	table.insert(self.tasks, task)
	return task
end

---Release connections before their instances to avoid stale callbacks.
function Maid:clean()
	local tasks = self.tasks
	self.tasks = {}
	for index = #tasks, 1, -1 do
		local item = tasks[index]
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif type(item) == "function" then
			local ok, errorMessage = pcall(item)
			if not ok then warn("[amethyst] cleanup failed:", errorMessage) end
		elseif type(item) == "table" and type(item.destroy) == "function" then
			item:destroy()
		end
	end
end

return Maid
