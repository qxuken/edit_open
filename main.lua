local uv = require("lib.uv_wrapper")
local comms = require("lib.comms")

uv.init(require("luv"))
uv.shutdown(function()
	comms.cleanup_role_and_shutdown_socket()
end)

comms.run_comms()
uv.run()
