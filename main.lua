--- Main entry point for standalone Lua execution.
--- Initializes the communication layer and starts the event loop.
--- Uses luv (libuv bindings) for async I/O.

local luv = require("luv")
local uv = require("lua.uv_wrapper")
local tasks = require("lua.tasks.mod")
local comms = require("lua.comms.mod")

math.randomseed(os.time())

uv.init(luv)
local sigint = luv.new_signal()
luv.signal_start(sigint, "sigint", function()
	print("SIGINT, shutting down...")
	luv.stop()
end)

tasks.register(require("lua.tasks.openfile").setup(function(payload, callback)
	uv.fstat(payload.path, function(err, stat)
		local capable = not err and stat and stat.type == "file"
		callback(capable)
	end)
end, function(payload)
	io.popen("wezetrm cli spawn nvim " .. payload.path)
	uv.stop()
end))

comms.run_comms()
uv.shutdown(comms.shutdown)

uv.run()
