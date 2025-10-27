-- 通过lua lua/server/rpc/entry.lua直接启动rpc进程
-- 关于rpc的说明详见README

-- 在加载freekill.lua之前，必须先做好所有准备，模拟出类似swig的环境

package.path = package.path .. "./?.lua;./?/init.lua;./lua/lib/?.lua;./lua/?.lua;./lua/?/init.lua"

local os = os
fk = require "server.rpc.fk"
local RPC_MODE = os.getenv("FK_RPC_MODE") == "cbor" and "cbor" or "json"
local jsonrpc = require "server.rpc.jsonrpc"
local stdio = require "server.rpc.stdio"
local dispatchers = require "server.rpc.dispatchers"
local cbor = require 'server.rpc.cbor'

-- 加载新月杀相关内容并ban掉两个吃stdin的
dofile "lua/freekill.lua"
dofile "lua/server/scheduler.lua"

---@diagnostic disable-next-line lowercase-global
dbg = Util.DummyFunc
debug.debug = Util.DummyFunc

---[[
local deadline_tab = setmetatable({}, { __mode = "k" })

local TIMEOUT = 15
local infinity = 1 / 0
local function deadLoopCheck()
  local co = coroutine.running()
  local ddl = deadline_tab[co] or infinity
  if os.time() > ddl then
    error("Execution time exceed.")
  end
end

-- 唉，全局穿透
-- 先改写他俩实现超时检测，等版本上来点之后把原生coroutine调用全杀了

local cocreate = coroutine.create
---@diagnostic disable-next-line
coroutine.create = function(f, ...)
  return cocreate(function(...)
    debug.sethook(coroutine.running(), deadLoopCheck, "", 50000)
    return f(...)
  end, ...)
end
local coresume = coroutine.resume
---@diagnostic disable-next-line
coroutine.resume = function(co, ...)
  local deadline = os.time() + TIMEOUT
  deadline_tab[co] = deadline
  return coresume(co, ...)
end
--]]

local mainLoop
if RPC_MODE == "json" then
  mainLoop = function()
    InitScheduler(fk.RoomThread())
    stdio.send(jsonrpc.encode_rpc(jsonrpc.notification, "hello", { "world" }))

    while true do
      local msg = stdio.receive()
      if msg == nil then break end

      local res = jsonrpc.server_response(dispatchers, msg)
      if res then
        stdio.send(json.encode(res))
      end
    end
  end
elseif RPC_MODE == "cbor" then
  mainLoop = function()
    InitScheduler(fk.RoomThread())
    stdio.stdout:write(jsonrpc.encode_rpc(jsonrpc.notification, "hello", { "world" }))
    stdio.stdout:flush()

    while true do
      if fk._rpc_finished then break end
      local msg = cbor.decode_file(stdio.stdin)
      if msg == nil then break end

      local res = jsonrpc.server_response(dispatchers, msg)
      if res then
        stdio.stdout:write(cbor.encode(res))
        stdio.stdout:flush()
      end
    end
  end
end

-- 参考文献：http://lua-users.org/lists/lua-l/2021-12/msg00023.html
-- if __name__ == '__main__':
if not ... then
  mainLoop()
end
