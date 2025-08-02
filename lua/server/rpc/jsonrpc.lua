-- 手抄jsonrpc协议并殴打开源代码
--
-- 参考文献：https://github.com/r3l0c/lua-json-rpc

---@class JsonRpcPacket
---@field jsonrpc "2.0"
---@field method? string
---@field params? table<string, any> | any[]
---@field id? integer
---@field result? any
---@field error? JsonRpcError

---@class JsonRpcError
---@field code integer
---@field message string
---@field data? any

local os = os
local json = require 'json'
local cbor = require 'server.rpc.cbor'
local RPC_MODE = os.getenv("FK_RPC_MODE") == "cbor" and "cbor" or "json"

local key_jsonrpc, key_method, key_params, key_error, key_id, key_result,
key_error_code, key_error_message, key_error_data
if RPC_MODE == 'json' then
  key_jsonrpc = "jsonrpc"
  key_method = "method"
  key_params = "params"
  key_error = "error"
  key_id = "id"
  key_result = "result"

  key_error_code = "code"
  key_error_message = "message"
  key_error_data = "data"
elseif RPC_MODE == 'cbor' then
  key_jsonrpc = 100
  key_method = 101
  key_params = 102
  key_error = 103
  key_id = 104
  key_result = 105

  key_error_code = 200
  key_error_message = 201
  key_error_data = 202
end

-- Standard error objects which can be extended with user defined error objects
-- having error codes from -32000 to -32099. Helper functions add_error_object
-- and get_error_object can be used to add and retrieve error objects.
---@type { [string]: JsonRpcError }
local error_objects = {
  parse_error      = { code = -32700, message = "Parse error" },
  invalid_request  = { code = -32600, message = "Invalid request" },
  method_not_found = { code = -32601, message = "Method not found" },
  invalid_params   = { code = -32602, message = "Invalid params" },
  internal_error   = { code = -32603, message = "Internal error" },
  server_error     = { code = -32000, message = "Server error" },
}

---@param error_name string
local function is_std_error(error_name)
  return ((error_name == 'parse_error') or
    (error_name == 'invalid_request') or
    (error_name == 'method_not_found') or
    (error_name == 'internal_error') or
    (error_name == 'server_error'))
end

-- Get an error object based on its' name.
---@param error_name string The name of the error.
---@return JsonRpcError? # The error object if it exits or nil if it doesn't exist.
local function get_error_object(error_name)
  return error_objects[error_name]
end

--- Add an error object. If and error code outside of the standard allowed is
--- given a new object is not created.
--- If an object with the same name exists it is overwritten.
--- If an object with the same error code exists a new object is not created.
--- @param error_name string The name of the error to be added.
--- @param error_object JsonRpcError The object of the error containing an error code
--- (err_code) and an error message (err_message)
--- @return JsonRpcError # An error object on successful creation or overwrite. Nil otherwise.
local function add_error_object(error_name, error_object)
  -- If the error object is not complete
  assert(error_object.code and error_object.message,
    "error_code and error_message are required in an error_object")

  assert(not is_std_error(error_name), "Errors defined in the standard cannot be changed")

  assert(error_object.code <= -32000 and error_object.code >= -32099,
    "User defined error codes should be between -32000 and -32099.")

  -- If an object with than name already exists, overwrite it.
  if error_objects[error_name] then
    -- logger:warn("Error object with name " .. error_name .. " already exists." ..
    --   "Overwritting...")
    error_objects[error_name] = error_object
    return error_objects[error_name]
  end

  -- If an object with the specified error code exists fail and return nil.
  for k, v in pairs(error_objects) do
    if v.code == error_object.code then
      error("Error code " .. tostring(error_object.code) ..
        " is already assigned to " .. k)
    end
  end

  error_objects[error_name] = error_object
  return error_objects[error_name]
end

local function remove_error_object(error_name)
  if is_std_error(error_name) then
    return false
  end
  error_objects[error_name] = nil
  return true
end

local _reqId = 1

local function encode_rpc(func, method, params, id)
  if nil == func then
    error("Function cannot be found")
  end
  local obj = func(method, params, id)
  if RPC_MODE == "json" then
    return json.encode(obj)
  else
    return cbor.encode(obj)
  end
end

---@return JsonRpcPacket
local function notification(method, params)
  if nil == method then
    error("A method in an RPC cannot be empty")
  end
  local req = {
    [key_jsonrpc] = "2.0",
    [key_method] = method,
    [key_params] = params,
  }
  return req
end

---@return JsonRpcPacket
local function request(method, params, id)
  local req = notification(method, params)
  req[key_id] = id or _reqId
  if req[key_id] == _reqId then
    _reqId = req[key_id] + 1
    if _reqId > 10000000 then _reqId = 1 end
  end
  return req
end

---@param req JsonRpcPacket
---@return JsonRpcPacket
local function response(req, results)
  return {
    [key_jsonrpc] = "2.0",
    [key_id] = req[key_id],
    [key_result] = results,
  }
end

---@param req any
---@param error_name string
---@return JsonRpcPacket
local function response_error(req, error_name, data)
  local res = {}
  local error_object = get_error_object(error_name) or
      get_error_object('internal_error')
  ---@cast error_object -nil

  res[key_jsonrpc] = "2.0"
  res[key_error] = {
    [key_error_code] = error_object.code,
    [key_error_message] = error_object.message,
  }

  res[key_error][key_error_data] = data

  if (error_object.code == -32700) or (error_object.code == -32600) then
    res[key_id] = nil --json.util.null()
  else
    res[key_id] = req[key_id]
  end
  return res
end

---@param methods table<string, fun(...): boolean, ...>
---@param req JsonRpcPacket
local function handle_request(methods, req)
  if type(req) ~= 'table' then
    return response_error(req, 'invalid_request', req)
  end
  if type(req[key_method]) ~= 'string' then
    return response_error(req, 'invalid_request', req)
  end
  if type(req[key_id]) ~= 'number' or req[key_id] <= 0 then
    return response_error(req, 'invalid_request', req)
  end

  local fnc = methods[req[key_method]]
  -- Method not found
  if type(fnc) ~= 'function' then
    return response_error(req, 'method_not_found')
  end

  local params = req[key_params]
  if params == nil then
    params = {}
  end

  -- According to the Lua reference, if the first return value of `pcall` is
  -- true (success), then all the following return values are those of the
  -- invoked function.
  -- According to our (??) specs, any remote procedure must also return a
  -- success flag, and then the actual return values (or error data).
  -- Therefore:
  --   `ret[1]` tells whether `pcall` was successful
  --   `ret[2]` tells whether the executed function was successful

  local ret = { pcall(fnc, params) }

  if ret[1] == false then
    -- logger:error("In pcall(): " .. ret[2])
    -- 算了不整stack trace
    return response_error(req, 'internal_error', ret[2])
  end

  if ret[2] == false then
    -- the method was invoked correctly, but itself returned non-success
    local error_name = ret[3]
    if nil == error_name then
      return response_error(req, 'invalid_params', ret[4])
    else
      return response_error(req, error_name, ret[4])
    end
  end

  -- Notification only
  if not req[key_id] then
    return nil
  end


  local results = nil
  if #ret == 3 then
    -- the method had a single, actual return value
    results = ret[3]
  else
    results = {}
    for i = 3, #ret do
      results[i - 2] = ret[i]
    end
  end
  return response(req, results)
end

---@param methods table<string, fun(...): boolean, ...>
---@param request string | JsonRpcPacket
---@return JsonRpcPacket?
---@diagnostic disable-next-line
local function server_response(methods, request)
  local req = request
  local status
  if type(request) == 'string' then
    status, req = pcall(json.decode, request)
    if status == false then
      return response_error(req, 'parse_error', req)
    end
  end
  ---@cast req -string

  if (#req == 0) and (req[key_jsonrpc] == "2.0") then
    return handle_request(methods, req)
  elseif #req == 0 then
    return response_error(req, 'invalid_request', req)
  else
    ---@cast req JsonRpcPacket[]
    local res = {}
    for _, r in pairs(req) do
      local lres = handle_request(methods, r)
      if type(lres) == 'table' then
        table.insert(res, lres)
      end
    end
    return res
  end
end

local function get_next_free_id()
  return _reqId
end

---@class jsonrpc
local M = {}

M.get_error_object = get_error_object
M.add_error_object = add_error_object
M.remove_error_object = remove_error_object
M.encode_rpc = encode_rpc
M.notification = notification
M.request = request
M.response_error = response_error
M.get_next_free_id = get_next_free_id

M.server_response = server_response

M.key_jsonrpc = key_jsonrpc
M.key_method = key_method
M.key_params = key_params
M.key_error = key_error
M.key_id = key_id
M.key_result = key_result
M.key_error_code = key_error_code
M.key_error_message = key_error_message
M.key_error_data = key_error_data

return M
