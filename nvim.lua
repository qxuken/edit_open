local uv = require("lib.uv_wrapper")
local logger = require("lib.logger")
local comms = require("lib.comms")

logger.set_printer(function(level, message)
	vim.notify(message, level)
end)
uv.init(vim.uv)
comms.run_comms()
