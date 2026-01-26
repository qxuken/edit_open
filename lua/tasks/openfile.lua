--- Open file task module - opens a file at a specific location.
--- Implements the TaskModule interface for file opening operations.
--- @class OpenFileTaskModule : TaskModule

local encode = require("lua.message.encode")
local logger = require("lua.logger")
local uv = require("lua.uv_wrapper")

--- @class OpenFilePayload
--- @field path string The file path to open
--- @field row integer The row/line number (1-based)
--- @field col integer The column number (1-based)

--- @class OpenFileTaskModule
local M = {}

--- Task type identifier
--- @type integer
M.id = 1

--- Validate that a payload has all required fields with correct types
--- @param payload OpenFilePayload The payload to validate
local function validate_payload(payload)
	assert(type(payload) == "table", "payload must be a table")
	assert(type(payload.path) == "string", "payload.path must be a string")
	assert(type(payload.row) == "number", "payload.row must be a number")
	assert(type(payload.col) == "number", "payload.col must be a number")
end

--- Helper to return error tuple
--- @param errmsg string? The error message
--- @return nil, string
local function pack_or_error(errmsg)
	return nil, errmsg or "encoding error"
end

--- Encode an OpenFilePayload to binary data
--- @param payload OpenFilePayload The payload to encode
--- @return string? data The encoded binary data, or nil on error
--- @return string? err Error message if encoding failed
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

--- Decode binary data to an OpenFilePayload
--- @param data string The binary data to decode
--- @return OpenFilePayload? payload The decoded payload, or nil on error
--- @return string? err Error message if decoding failed
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

--- Checks if this instance can execute the task (file exists and is accessible)
--- @param payload OpenFilePayload The task payload with file path
--- @param callback fun(capable: boolean) Callback with capability result
function M.can_execute(payload, callback)
	uv.fstat(payload.path, function(err, stat)
		local capable = not err and stat and stat.type == "file"
		callback(capable)
	end)
end

--- Execute the task - open the file at specified location
--- @param payload OpenFilePayload The task payload with file path and position
function M.execute(payload)
	logger.info(string.format("Executing: Open file %s:%d:%d", payload.path, payload.row, payload.col))
	-- TODO: integrate with editor (vim.cmd, etc.)
end

-- TODO: add a fallback function in case cluster failed to execute, example: start wezterm with nvim <file>

return M
