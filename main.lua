--- Main entry point for standalone Lua execution.
--- Initializes the communication layer and starts the event loop.
--- Uses luv (libuv bindings) for async I/O.

local uv = require("lua.uv_wrapper")
local tasks = require("lua.tasks.mod")
local comms = require("lua.comms")

-- Initialize libuv wrapper with luv module
uv.init(require("luv"))
-- Register shutdown handler to clean up connections
uv.shutdown(comms.cleanup_role_and_shutdown_socket)

-- Setup task registry and initialize communication
tasks.setup()
comms.run_comms()
-- Start the event loop
uv.run()
