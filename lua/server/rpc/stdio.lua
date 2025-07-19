-- 在用上socket之前，我们先用stdio来实现消息收发
-- 实现类似socket的receive和send两个方法即可

local io = io

---@return string?
local function receive()
  if fk._rpc_finished then
    return nil
  end
  return io.read()
end

local _print = print

---@param data string
local function send(data)
  _print(data)
end


local M = {}
M.receive = receive
M.send = send

return M
