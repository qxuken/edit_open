--- Global state singleton for the application.
--- Contains configuration, runtime state, and registries.

--- @class TaskModule
--- @field id integer Unique task type identifier
--- @field encode fun(payload: table): string?, string? Encode payload to binary data
--- @field decode fun(data: string): table?, string? Decode binary data to payload
--- @field can_execute fun(payload: table, callback: fun(capable: boolean)) Check if this instance can execute the task
--- @field execute fun(payload: table) Execute the task

--- @class LeaderRole
--- @field id integer Role identifier (2 = leader)
--- @field role integer Alias for id
--- @field socket uv_udp_t UDP socket for communication
--- @field peers table<integer, uv_timer_t> Connected peers by port -> timeout timer
--- @field tasks table<integer, LeaderTaskEntry> Active tasks by task_id

--- @class FollowerRole
--- @field id integer Role identifier (1 = follower)
--- @field role integer Alias for id
--- @field socket uv_udp_t UDP socket for communication
--- @field heartbeat_timer uv_timer_t Timer for sending heartbeat pings
--- @field tasks table<integer, FollowerTaskEntry> Pending tasks by task_id

--- @class CandidateRole
--- @field id integer Role identifier (0 = candidate)

--- @alias Role LeaderRole|FollowerRole|CandidateRole

--- @class LeaderTaskEntry
--- @field type_id integer Task type identifier
--- @field payload table Decoded task payload
--- @field raw_data string Encoded task data
--- @field state integer Task state: pending|dispatched|granted|completed
--- @field capable_peers integer[] Ports of peers that reported capability
--- @field granted_peer integer? Port of peer granted to execute
--- @field requester_port integer? Port of original requester
--- @field dispatched_count integer Number of peers task was dispatched to
--- @field not_capable_count integer Number of task_not_capable responses received
--- @field dispatch_timer uv_timer_t? Timer for dispatch timeout

--- @class FollowerTaskEntry
--- @field type_id integer Task type identifier
--- @field payload table Decoded task payload
--- @field state integer Task state: pending|granted|completed

--- @class MessageHandler
--- @field [integer] fun(payload: table)[] Handlers by message type ID

--- Printer function type
--- @alias PrinterFunction fun(level: LogLevel, message: string)

--- @class GlobalState
--- @field log_level integer Current log level (0=TRACE, 1=DEBUG, 2=INFO, 3=WARN)
--- @field HOST string Host address for UDP communication
--- @field PORT integer Port number for leader
--- @field command_registry table<integer, TaskModule> Registered task modules by type ID
--- @field role Role Current role state
--- @field last_command_id integer Counter for generating unique task IDs
--- @field print PrinterFunction Printer function used by logger

--- @type GlobalState
local G = {
	log_level = 1,
	HOST = "127.0.0.1",
	PORT = 48391,
	command_registry = {},
	print = function() end,
	role = { id = 0 },
	last_command_id = 0,
}
return G
