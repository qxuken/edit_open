local uv = require("luv")
local utils = {}

local HOST = "127.0.0.1"
local PORT = 47912

local commands = {
	-- { "open", leader_handle, follower_handle },
}

local G = {
	peers = {},
	role = {
		type = "candidate",
	},
}

local function recv_msg(err, data, addr, flags)
	assert(not err, err)
	print("[data]")
	if data ~= nil then
		print("len = " .. string.len(data))
		print(data)
	else
		print("nil")
	end
	print("[addr]")
	if addr ~= nil then
		utils.dump(addr)
	else
		print("nil")
	end
	print("[flags]")
	if flags ~= nil then
		utils.dump(flags)
	else
		print("nil")
	end
	if G.role.type == "leader" and data ~= nil and addr ~= nil then
		G.role.socket:send(data, addr.ip, addr.port, function(err1)
			print(err1)
		end)
	end
end

local function try_leader()
	print("try_leader")
	local role = {
		type = "leader",
		socket = uv.new_udp(),
	}
	local ret, err, code
	ret, err, code = role.socket:bind(HOST, PORT)
	if ret ~= 0 then
		return err, code
	end
	ret, err, code = role.socket:recv_start(recv_msg)
	if ret ~= 0 then
		return err, code
	end
	print("udp server listening on port: " .. PORT)
	G.role = role
	return nil, nil
end

local function try_follower()
	print("try_follower")
	local socket = uv.new_udp()
	local ret, err, code
	ret, err, code = socket:bind(HOST, 0)
	assert(ret == 0 and not code, err)
	ret, err, code = socket:connect(HOST, PORT)
	assert(ret == 0 and not code, err)
	local timer = uv.new_timer()
	timer:start(0, 1000, function()
		socket:send("ping" .. uv.now(), nil, nil)
	end)
	ret, err, code = socket:recv_start(recv_msg)
	assert(ret == 0 and not code, err)
	print("udp client open on port: " .. socket:getsockname().port)
	G.role = {
		type = "follower",
		socket = socket,
		timer = timer,
	}
end

local function run_comms(retries)
	local retries_left = retries and retries - 1 or 3
	print("run_comms: " .. retries_left)
	if retries_left == 0 then
		return false, "No more retries, quiting"
	end
	local err
	err = try_leader()
	if err ~= nil then
		print(err)
		err = try_follower()
		if err ~= nil then
			print(err)
			return run_comms(retries_left)
		end
	end
	return true, nil
end

-- Utils

function utils.dump(t, indent, seen)
	indent, seen = indent or "", seen or {}
	if seen[t] then
		print(indent .. "*RECURSION*")
		return
	end
	seen[t] = true
	for k, v in pairs(t) do
		if type(v) == "table" then
			print(("%s[%s] = {"):format(indent, tostring(k)))
			utils.dump(v, indent .. "  ", seen)
			print(indent .. "}")
		else
			print(("%s[%s] = %s"):format(indent, tostring(k), tostring(v)))
		end
	end
end

-- Hot Loop

print(run_comms())
-- if not ok then
-- 	print("Comms failed: " .. err and err or "unknown")
-- end

-- uv.signal_start(uv.constants.SIGTERM, function(signame)
-- 	print(signame) -- string output: "sigterm"
-- end)

uv.run()
