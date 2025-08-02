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
-- 提供给cbor的接口，它需要xxx:read()
M.stdin = {
  read = function(_, n)
    if fk._rpc_finished then return "" end
    -- 没想到io.input():read(0)的情况下依然会等stdin有数据可读才返回
    -- 我们用的cbor并不希望这种情况发生
    if n == 0 then return "" end
    return io.read(n)
  end,
}
M.stdout = io.output()

return M
