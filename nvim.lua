--- Neovim plugin entry point.
--- Initializes the communication layer for use within Neovim.
--- Uses vim.uv for async I/O and vim.notify for logging.

local uv = require("lua.uv_wrapper")
local logger = require("lua.logger")
local tasks = require("lua.tasks.mod")
local comms = require("lua.comms")

-- Configure logger to use Neovim's notification system
--- @param level LogLevel The log level
--- @param message string The message to display
logger.set_printer(function(level, message)
	vim.notify(message, level)
end)

-- Initialize libuv wrapper with Neovim's built-in uv module
uv.init(vim.uv)
-- Setup task registry and initialize communication
tasks.setup()
comms.run_comms()
