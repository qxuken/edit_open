local encode = require("lua.message.encode")
local logger = require("lua.logger")
local uv = require("lua.uv_wrapper")

local M = {}

M.id = 1

local function validate_payload(payload)
	assert(type(payload) == "table", "payload must be a table")
	assert(type(payload.path) == "string", "payload.path must be a string")
	assert(type(payload.row) == "number", "payload.row must be a number")
	assert(type(payload.col) == "number", "payload.col must be a number")
end

local function pack_or_error(errmsg)
	return nil, errmsg or "encoding error"
end

function M.encode(payload)
	validate_payload(payload)
	local path_data, row_data, col_data, err
	path_data, err = encode.pack_str_u16(payload.path)
	if not path_data then
		return pack_or_error(err)
	end
	row_data, err = encode.u32(payload.row)
	if not row_data then
		return pack_or_error(err)
	end
	col_data, err = encode.u32(payload.col)
	if not col_data then
		return pack_or_error(err)
	end
	return table.concat({ path_data, row_data, col_data }), nil
end

function M.decode(data)
	if type(data) ~= "string" then
		return nil, "payload must be string"
	end
	local path, row, col, err
	local off = 1
	path, off, err = encode.unpack_str_u16(data, off)
	if not path then
		return nil, err
	end
	row, off, err = encode.unpack_u32(data, off)
	if not row then
		return nil, err
	end
	col, off, err = encode.unpack_u32(data, off)
	if not col then
		return nil, err
	end
	return {
		path = path,
		row = row,
		col = col,
	}, nil
end

local function log_open_attempt(payload)
	logger.info(string.format("Open file %s:%d:%d", payload.path, payload.row, payload.col))
end

function M.task_request(task_id, payload, context)
	logger.debug(string.format("Task[%d] openfile request from %s", task_id, context and context.source or "unknown"))
	if payload then
		log_open_attempt(payload)
	end
end

function M.task_dispatch(task_id, payload)
	uv.fstat(payload.path, function(err, stat)
		if not err and stat.type == "file" then
			log_open_attempt(payload)
		else
			logger.warn("Unable to open path " .. payload.path .. (err and (": " .. err) or ""))
		end
	end)
end

function M.task_capable(task_id, payload)
	logger.debug(string.format("Task[%d] capable", task_id))
	if payload then
		log_open_attempt(payload)
	end
end

function M.task_granted(task_id, payload)
	logger.info(string.format("Task[%d] granted", task_id))
	log_open_attempt(payload)
end

function M.task_denied(task_id)
	logger.warn("Task denied: " .. task_id)
end

return M
