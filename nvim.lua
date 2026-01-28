--- Neovim plugin entry point.
--- Initializes the communication layer for use within Neovim.
--- Uses vim.uv for async I/O and vim.notify for logging.

local uv = require("lua.uv_wrapper")
local logger = require("lua.logger")
local tasks = require("lua.tasks.mod")
local comms = require("lua.comms.mod")

-- Configure logger to use Neovim's notification system
--- @param level LogLevel The log level
--- @param message string The message to display
logger.set_printer(function(level, message)
	-- vim.notify(message, level)
end)

uv.init(vim.uv)

local function strip_cwd(path)
	return vim.fn.fnamemodify(path, ":.")
end
tasks.register(require("lua.tasks.openfile").setup(function(payload, callback)
	uv.fstat(strip_cwd(payload.path), function(err, stat)
		local capable = not err and stat and stat.type == "file"
		callback(capable)
	end)
end, function(payload)
	vim.schedule(function()
		vim.cmd("edit " .. payload.path)
		if payload.row > 0 or payload.col > 0 then
			local row = payload.row
			if row <= 0 then
				row = 1
			end
			local col = payload.col
			if col <= 0 then
				col = 1
			end
			vim.cmd("call cursor(" .. row .. "," .. col .. ")")
		end
		vim.system({ "wezterm", "cli", "activate-pane" })
	end)
end))

comms.run_comms()
uv.shutdown(comms.shutdown)
