--- Communication layer constants.
--- @class CommsConstants

local M = {}

--- @type integer Timeout before considering a peer disconnected (ms)
M.HEARTBEAT_TIMEOUT = 6000
--- @type integer Base interval between heartbeat pings (ms)
M.HEARTBEAT_INTERVAL = 2000
--- @type integer Minimum random jitter added to heartbeat interval (ms)
M.HEARTBEAT_RANGE_FROM = 250
--- @type integer Maximum random jitter added to heartbeat interval (ms)
M.HEARTBEAT_RANGE_TO = 1750

--- @type integer Timeout waiting for capable responses from followers (ms)
M.TASK_DISPATCH_TIMEOUT = 3000

--- Role identifier constants
--- @enum RoleId
M.role = {
	transition = -1,
	candidate = 0,
	follower = 1,
	leader = 2,
}

--- Task state constants for tracking task lifecycle
--- @enum TaskState
M.task_state = {
	pending = 0, -- Task received, checking local capability
	dispatched = 1, -- Dispatched to followers, waiting for capable responses
	granted = 2, -- Granted to a follower
	completed = 3, -- Task completed
}

return M
