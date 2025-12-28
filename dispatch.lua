--- Dispatch entrypoint - sends task requests to the leader and waits for completion.
--- Usage: lua dispatch.lua <task_type> [args...]
--- Example: lua dispatch.lua openfile /path/to/file 10 5
---
--- Flow:
--- 1. Dispatcher sends task_request to leader
--- 2. Leader checks if it can execute locally:
---    - If yes: executes and we never hear back (success assumed)
---    - If no: broadcasts task_dispatch to all peers (including us)
--- 3. If we receive task_dispatch, we check capability and respond
--- 4. If granted, we execute; if denied, another peer handles it
--- 5. Timeout means either leader handled it or no one could

local uv = require("lua.uv_wrapper")
local G = require("lua.G")
local logger = require("lua.logger")
local message = require("lua.message.mod")
local tasks = require("lua.tasks.mod")

--- Task type name to module ID mapping
--- @type table<string, integer>
local task_types = {
	openfile = 1,
}

--- Print usage information to stdout
local function print_usage()
	print("Usage: lua dispatch.lua <task_type> [args...]")
	print("")
	print("Task types:")
	print("  openfile <path> [row] [col]  - Open file at location")
	print("")
	print("Examples:")
	print("  lua dispatch.lua openfile /path/to/file.lua")
	print("  lua dispatch.lua openfile /path/to/file.lua 10 5")
end

--- Parse command-line arguments for the openfile task
--- @param args string[] The argument list (path, row, col)
--- @return OpenFilePayload? payload The parsed payload, or nil on error
--- @return string? err Error message if parsing failed
local function parse_openfile_args(args)
	local path = args[1]
	if not path then
		return nil, "openfile requires a path argument"
	end
	local row = tonumber(args[2]) or 1
	local col = tonumber(args[3]) or 1
	return {
		path = path,
		row = row,
		col = col,
	}, nil
end

--- Parse command-line arguments for a task type
--- @param task_name string The task type name
--- @param args string[] The task-specific arguments
--- @return table? payload The parsed payload, or nil on error
--- @return string? err Error message if parsing failed
local function parse_args(task_name, args)
	if task_name == "openfile" then
		return parse_openfile_args(args)
	end
	return nil, "unknown task type: " .. task_name
end

--- Clean up resources and exit the process
--- @param socket uv_udp_t The UDP socket to close
--- @param timeout_timer uv_timer_t? The timeout timer to clear
--- @param exit_code integer The exit code to use
local function cleanup_and_exit(socket, timeout_timer, exit_code)
	if timeout_timer then
		timeout_timer:stop()
		timeout_timer:close()
	end
	socket:recv_stop()
	socket:close()
	-- Let the event loop finish cleanly
	uv.set_timeout(10, function()
		os.exit(exit_code)
	end)
end

--- Main entry point - parses args, sends task request, handles responses
local function main()
	--- @type string[] Command-line arguments
	local args = arg
	if not args or #args < 1 then
		print_usage()
		os.exit(1)
	end

	local task_name = args[1]
	local type_id = task_types[task_name]
	if not type_id then
		print("Error: unknown task type: " .. task_name)
		print_usage()
		os.exit(1)
	end

	-- Collect remaining args for the task
	local task_args = {}
	for i = 2, #args do
		table.insert(task_args, args[i])
	end

	local payload, err = parse_args(task_name, task_args)
	if not payload then
		print("Error: " .. err)
		print_usage()
		os.exit(1)
	end

	-- Initialize
	uv.init(require("luv"))
	tasks.setup()

	local task_module = tasks.get(type_id)
	if not task_module then
		print("Error: task module not found for type: " .. type_id)
		os.exit(1)
	end

	-- Encode payload
	local data
	data, err = task_module.encode(payload)
	if not data then
		print("Error encoding payload: " .. (err or "unknown"))
		os.exit(1)
	end

	-- Create UDP socket to send to leader
	local socket = uv.new_udp()
	if not socket then
		print("Error creating socket")
		os.exit(1)
	end

	-- Bind to any available port
	local ret, bind_err
	ret, bind_err = socket:bind(G.HOST, 0)
	if ret ~= 0 then
		print("Error binding socket: " .. (bind_err or "unknown"))
		socket:close()
		os.exit(1)
	end

	local local_addr = socket:getsockname()
	logger.debug("Dispatcher bound to port " .. local_addr.port)

	-- Track state
	--- @type uv_timer_t? Timer for request timeout
	local timeout_timer = nil
	--- @type integer? Task ID if we get dispatched
	local pending_task_id = nil

	-- Set up receive handler to wait for response
	local recv_ret, recv_start_err = socket:recv_start(function(recv_err, recv_data, addr)
		if recv_err then
			logger.debug("Receive error: " .. recv_err)
			return
		end
		if not recv_data or not addr then
			return
		end

		-- Only accept messages from the leader
		if addr.port ~= G.PORT then
			return
		end

		local cmd_id, recv_payload, unpack_err = message.unpack_frame(recv_data)
		if unpack_err or not recv_payload then
			logger.debug("Unpack error: " .. unpack_err)
			return
		end

		logger.debug("Received: " .. message.get_name(cmd_id))

		if cmd_id == message.type.task_pending then
			-- Leader acknowledged our request and assigned a task ID
			pending_task_id = recv_payload.id
			print("Task accepted, id=" .. pending_task_id)
		elseif cmd_id == message.type.task_completed then
			-- Task completed successfully (either by leader or a follower)
			print("Task completed successfully")
			cleanup_and_exit(socket, timeout_timer, 0)
		elseif cmd_id == message.type.task_failed then
			-- Task failed (no capable instances, timeout, etc.)
			print("Task failed - no instance could execute it")
			cleanup_and_exit(socket, timeout_timer, 1)
		elseif cmd_id == message.type.task_dispatch then
			-- Leader dispatched task to us (couldn't handle locally)
			local dispatch_payload, decode_err = tasks.decode_task(recv_payload.type_id, recv_payload.data)
			if decode_err or not dispatch_payload then
				logger.debug("Decode error: " .. decode_err)
				return
			end

			pending_task_id = recv_payload.id

			-- Check if we can execute this task
			task_module.can_execute(dispatch_payload, function(capable)
				if capable then
					logger.debug("Capable, sending response for task " .. pending_task_id)
					local frame = message.pack_task_capable_frame(pending_task_id)
					socket:send(frame, G.HOST, G.PORT, function(send_err)
						if send_err then
							logger.debug("Send error: " .. send_err)
						end
					end)
				else
					logger.debug("Not capable of executing task, sending not_capable")
					local not_capable_frame = message.pack_task_not_capable_frame(pending_task_id)
					socket:send(not_capable_frame, G.HOST, G.PORT, function(send_err)
						if send_err then
							logger.debug("Send error: " .. send_err)
						end
					end)
					-- Don't exit yet - wait for task_completed or task_failed from leader
				end
			end)
		elseif cmd_id == message.type.task_granted then
			-- We were granted the task, execute it
			print("Task granted, executing...")
			task_module.execute(payload)
			print("Task completed")
			cleanup_and_exit(socket, timeout_timer, 0)
		elseif cmd_id == message.type.task_denied then
			-- Another peer was selected to handle the task
			print("Task assigned to another instance")
			cleanup_and_exit(socket, timeout_timer, 0)
		end
	end)

	if recv_ret ~= 0 then
		print("Error starting recv: " .. (recv_start_err or "unknown"))
		socket:close()
		os.exit(1)
	end

	-- Send task request to leader
	print("Sending task request...")
	local frame = message.pack_task_request_frame(0, type_id, data)
	socket:send(frame, G.HOST, G.PORT, function(send_err)
		if send_err then
			print("Error sending task request: " .. send_err)
			print("Is a leader running? (Start with: lua main.lua)")
			socket:recv_stop()
			socket:close()
			os.exit(1)
		end
		logger.debug("Task request sent to leader at port " .. G.PORT)
	end)

	-- Set timeout - if we don't hear back, assume leader handled it
	--- @type integer Timeout duration in milliseconds
	local TIMEOUT_MS = 5000
	timeout_timer = uv.set_timeout(TIMEOUT_MS, function()
		-- No response means either:
		-- 1. Leader executed locally (success)
		-- 2. No leader running (failure, but send would have failed)
		-- 3. Task was handled by another follower
		print("No response - task likely handled by leader or another instance")
		cleanup_and_exit(socket, timeout_timer, 0)
	end)

	-- Run event loop
	uv.run()
end

main()
