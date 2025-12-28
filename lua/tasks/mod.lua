local M = {}

M.registry = {}

local function ensure_task_module(task)
	assert(type(task) == "table", "task module must be a table")
	assert(type(task.id) == "number", "task module must define numeric id")
	assert(type(task.encode) == "function", "task module must expose encode")
	assert(type(task.decode) == "function", "task module must expose decode")
end

function M.register(task)
	ensure_task_module(task)
	if M.registry[task.id] then
		error("task id already registered: " .. task.id)
	end
	M.registry[task.id] = task
	return task
end

function M.get(task_id)
	return M.registry[task_id]
end

function M.setup()
	M.registry = {}
	local openfile = require("lua.tasks.openfile")
	M.register(openfile)
end

return M
